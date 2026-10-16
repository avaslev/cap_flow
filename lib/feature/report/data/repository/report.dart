import 'package:investflow/core/db.dart';
import 'package:investflow/core/utils/calculateNextOccurrence.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class ReportRepository {
  late Database _database;

  Future<ReportData> getReportData(String accountId) async {
    _database = await DatabaseHelper.instance.db;
    final now = DateTime.now();
    final startOfYear =
        DateTime(now.year, now.month - 11, 1).millisecondsSinceEpoch;
    final endOfYear = now.millisecondsSinceEpoch;

    final summary = await _getAssetSummary(accountId, endOfYear);
    final totalLineData = await _getTotalPortfolioValue(
      accountId,
      startOfYear,
      endOfYear,
      summary['total'] ?? 0,
    );
    final percentage = _calculateTotalLinePercentage(totalLineData);

    return ReportData(
      summary: summary,
      totalLineData: totalLineData,
      totalLineDataPercentage: percentage, // ✅ Заполнено!
      incomeExpenseData: await _getIncomeExpenseData(
        accountId,
        startOfYear,
        endOfYear,
      ),
      plannedData: await _getPlannedData(
        accountId,
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch,
        DateTime(now.year, now.month + 12, 1).millisecondsSinceEpoch,
      ),
    );
  }

  Future<Map<String, double>> _getAssetSummary(
    String accountId,
    int endTime,
  ) async {
    final accountCondition =
        accountId == 'total' ? "acc.excludeFromTotal = 'false'" : "acc.id = ?";

    final params = accountId == 'total' ? [endTime] : [endTime, accountId];

    final result = await _database.rawQuery('''
    SELECT 
      t.type as asset_type,
      acc.excludeFromTotal,
      SUM(
        CASE 
          WHEN a.type = 'add'
          THEN a.quantity * a.price 
          ELSE -a.quantity * a.price 
        END
      ) as total_value
    FROM accounts acc
    LEFT JOIN tools t ON t.accountId = acc.id
    LEFT JOIN activities a ON t.id = a.tool_id 
      AND a.create_at < ?
    WHERE $accountCondition
    GROUP BY t.type
    ''', params);

    final Map<String, double> summary = {};
    for (final row in result) {
      final type = (row['asset_type'] as String?) ?? 'Other';
      final value = (row['total_value'] as num?)?.toDouble() ?? 0.0;
      summary[type] = value;
    }

    summary['total'] = summary.values.fold(0.0, (sum, val) => sum + val);

    return summary;
  }

  Future<List<ChartPoint>> _getTotalPortfolioValue(
    String accountId,
    int startTime,
    int endTime,
    double currentTotal,
  ) async {
    final accountCondition =
        accountId == 'total' ? "acc.excludeFromTotal = 'false'" : "acc.id = ?";

    final params =
        accountId == 'total'
            ? [startTime, endTime]
            : [startTime, endTime, accountId];

    final monthlyData = await _database.rawQuery('''
    SELECT 
      strftime('%Y', datetime(a.create_at/1000, 'unixepoch')) as year_index,
      strftime('%m', datetime(a.create_at/1000, 'unixepoch')) as month_index,
      SUM(
        CASE 
          WHEN a.type = 'add'
          THEN a.quantity * a.price 
          WHEN a.type = 'substract'
          THEN -a.quantity * a.price 
          ELSE 0 
        END
      ) as total_value
    FROM accounts acc
    LEFT JOIN tools t ON t.accountId = acc.id
    LEFT JOIN activities a ON t.id = a.tool_id 
      AND a.create_at BETWEEN ? AND ?
    WHERE $accountCondition
    GROUP BY year_index, month_index
    ORDER BY year_index, month_index
    ''', params);

    double totalChanges = 0.0;
    for (final row in monthlyData) {
      totalChanges += (row['total_value'] as num?)?.toDouble() ?? 0.0;
    }

    double initialTotal = currentTotal - totalChanges;
    double runningTotal = initialTotal;

    final startMonth = DateTime.fromMillisecondsSinceEpoch(startTime).month;
    final startYear = DateTime.fromMillisecondsSinceEpoch(startTime).year;

    return List.generate(12, (i) {
      final targetMonth = ((startMonth - 1 + i) % 12) + 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');
      final targetYear = (targetMonth >= startMonth ? startYear : startYear + 1).toString();
      final row = monthlyData.firstWhere(
         (r) =>
            (r['month_index'] as String?) == targetMonthStr 
            && (r['year_index'] as String?) == targetYear,
        orElse: () => {
          'year_index': targetYear,
          'month_index': targetMonthStr,
          'total_value': 0.0
        },
      );
      final monthlyChange = (row['total_value'] as num?)?.toDouble() ?? 0.0;
      runningTotal += monthlyChange;
      return ChartPoint(
        year: targetYear,
        month: targetMonthStr,
        value: runningTotal,
      );
    });
  }

  Future<List<MonthIncomeExpense>> _getIncomeExpenseData(
    String accountId,
    int startTime,
    int endTime,
  ) async {
    final accountCondition =
        accountId == 'total' ? "acc.excludeFromTotal = 'false'" : "acc.id = ?";

    final params =
        accountId == 'total'
            ? [startTime, endTime]
            : [startTime, endTime, accountId];

    final result = await _database.rawQuery('''
    SELECT 
      strftime('%Y', datetime(a.create_at/1000, 'unixepoch')) as year_index,
      strftime('%m', datetime(a.create_at/1000, 'unixepoch')) as month_index,
      SUM(
        CASE 
          WHEN a.type = 'add'
          -- Маркер прибыли/убытка (quantity = 0) несёт сумму в price.
          THEN ABS(CASE WHEN a.quantity = 0 THEN a.price ELSE a.quantity * a.price END)
          ELSE 0 
        END
      ) as income,
      SUM(
        CASE 
          WHEN a.type = 'substract'
          THEN ABS(CASE WHEN a.quantity = 0 THEN a.price ELSE a.quantity * a.price END)
          ELSE 0 
        END
      ) as expense
  FROM accounts acc
    LEFT JOIN tools t ON t.accountId = acc.id
    LEFT JOIN activities a ON t.id = a.tool_id 
      AND a.create_at BETWEEN ? AND ?
    WHERE $accountCondition
      AND a.is_transmit = 0
    GROUP BY year_index, month_index
    ORDER BY year_index, month_index
    ''', params);

    final startMonth = DateTime.fromMillisecondsSinceEpoch(startTime).month;
    final startYear = DateTime.fromMillisecondsSinceEpoch(startTime).year;

    return List.generate(12, (index) {
      final targetMonth = ((startMonth - 1 + index) % 12) + 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');
      final targetYear = (targetMonth > startMonth ? startYear : startYear + 1).toString();

      final row = result.firstWhere(
        (r) =>
            (r['month_index'] as String?) == targetMonthStr 
            && (r['year_index'] as String?) == targetYear,
        orElse:
            () => {
              'income': 0.0,
              'expense': 0.0,
              'budget': 0.0,
              'year_index': targetYear,
              'month_index': targetMonthStr,
            },
      );
      return MonthIncomeExpense(
        year: (row['year_index'] as String).substring(2),
        month:
            (row['month_index'] as String?)?.padLeft(2, '0') ?? targetMonthStr,
        income: (row['income'] as num?)?.toDouble() ?? 0.0,
        expense: (row['expense'] as num?)?.toDouble() ?? 0.0,
        budget: (row['planned_budget'] as num?)?.toDouble() ?? 0.0,
      );
    });
  }

  /// Проекция плановых транзакций на 12 месяцев вперёд:
  /// [income, expense, budget] по каждому месяцу окна.
  ///
  /// - повторяющиеся серии шагают calculateNextOccurrence от
  ///   next_execution_date до конца окна;
  /// - плановые записи закрытых тулов (is_closed) не проецируются;
  /// - бюджет = плановые переводы между счетами.
  Future<List<MonthIncomeExpense>> _getPlannedData(
    String accountId,
    int startTime,
    int endTime,
  ) async {
    final DateTime windowStart = DateTime.fromMillisecondsSinceEpoch(startTime);
    final DateTime windowEnd = DateTime.fromMillisecondsSinceEpoch(endTime);

    // Закрытые тула: их плановые записи не проецируем.
    final Set<String> closedToolIds = <String>{
      for (final row in await _database.query('tools', where: 'isClosed = 1'))
        row['id'] as String,
    };

    final String where = accountId == 'total'
        ? "account_id IN (SELECT id FROM accounts WHERE excludeFromTotal = 'false')"
        : 'account_id = ?';
    final List<Object?> args = accountId == 'total' ? [] : [accountId];
    final List<Map<String, dynamic>> rows = await _database.query(
      'scheduled_transactions',
      where: where,
      whereArgs: args,
    );

    // Бакеты по месяцам окна: [доход, расход, бюджет].
    final DateTime monthStart = DateTime(windowStart.year, windowStart.month, 1);
    final List<List<double>> buckets = List.generate(12, (_) => <double>[0, 0, 0]);

    for (final Map<String, dynamic> row in rows) {
      final ScheduledTransaction st = ScheduledTransaction.fromMap(row);
      if (st.depositToolId != null &&
          closedToolIds.contains(st.depositToolId)) {
        continue; // тул закрыт — серию не проецируем
      }

      // Бессрочные повторения (без даты окончания) — без лимита;
      // срочные — остатком total - executed.
      final bool perpetual =
          st.recurrenceType != 'none' && st.recurrenceEndDate == null;
      final int maxLeft = perpetual
          ? 400
          : (st.totalExecutions > 0
              ? st.totalExecutions - st.executedCount
              : 1);

      DateTime cursor = st.nextExecutionDate;
      int made = 0;
      while (!cursor.isAfter(windowEnd) && made < maxLeft) {
        if (st.recurrenceEndDate != null &&
            cursor.isAfter(st.recurrenceEndDate!)) {
          break;
        }
        final DateTime day = DateTime(cursor.year, cursor.month, cursor.day);
        final int monthIndex =
            (day.year - monthStart.year) * 12 + day.month - monthStart.month;
        if (monthIndex >= 0 && monthIndex < 12) {
          final int idx = st.type == 'income' ? 0 : (st.type == 'transfer' ? 2 : 1);
          buckets[monthIndex][idx] += st.amount;
        }
        made += 1;

        final DateTime? next = calculateNextOccurrence(
          initialDate: st.date,
          recurrenceType: st.recurrenceType,
          recurrenceEndDate: st.recurrenceEndDate,
          recurrenceDayOfMonth: st.recurrenceDayOfMonth,
          now: cursor,
        );
        if (next == null || !next.isAfter(cursor)) {
          break;
        }
        cursor = next;
      }
    }

    final List<MonthIncomeExpense> planned = <MonthIncomeExpense>[];
    for (int i = 0; i < 12; i++) {
      final DateTime month = DateTime(monthStart.year, monthStart.month + i, 1);
      final List<double> bucket = buckets[i];
      planned.add(
        MonthIncomeExpense(
          year: '${month.year}'.substring(2),
          month: month.month.toString().padLeft(2, '0'),
          income: bucket[0],
          expense: bucket[1],
          budget: bucket[2],
        ),
      );
    }
    return planned;
  }

  String _formatMonthForQuery(int monthIndex) {
    final now = DateTime.now();
    final monthDate = DateTime(now.year, now.month - 11 + monthIndex);
    return '${monthDate.year}${monthDate.month.toString().padLeft(2, '0')}';
  }

  double _calculateTotalLinePercentage(List<ChartPoint> totalLineData) {
    if (totalLineData.length < 2) return 0.0;

    double totalMonthlyReturn = 0.0;
    int validMonths = 0;

    for (int i = 1; i < totalLineData.length; i++) {
      final prevValue = totalLineData[i - 1].value;
      final currentValue = totalLineData[i].value;

      if (prevValue != 0) {
        final monthlyReturn = ((currentValue - prevValue) / prevValue) * 100;
        totalMonthlyReturn += monthlyReturn;
      }
      validMonths++;
    }

    // Guard: нет истории (первая точка 0) → процент не считаем (иначе NaN).
    if (totalLineData[0].value.abs() < 0.001) return 0.0;
    return ((totalLineData[11].value / totalLineData[0].value) - 1) * 100;
  }



}
