import 'package:investflow/core/db.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';
import 'package:sqflite/sqflite.dart';

class ReportRepository {
  late Database _database;

  Future<ReportData> getReportData(String accountId) async {
    // ✅ Ждем инициализации БД
    _database = await DatabaseHelper.instance.db;
    final now = DateTime.now();
    final startOfYear =
        DateTime(now.year, now.month - 11, 1).millisecondsSinceEpoch;
    final endOfYear = now.millisecondsSinceEpoch;

    // 1. Summary по активам (tools + activities)
    final summary = await _getAssetSummary(accountId, endOfYear);

    // 2. Total line data (общая стоимость портфеля по месяцам)
    final totalLineData = await _getTotalPortfolioValue(
      accountId,
      startOfYear,
      endOfYear,
      summary['total'] ?? 0,
    );

    // 4. Planned из scheduled_transactions
    // final plannedData = await _getPlannedData(
    //   accountId,
    //   now.millisecondsSinceEpoch,
    //   DateTime(now.year, now.month + 12, 1).millisecondsSinceEpoch,
    // );

    return ReportData.demo().copyWith(
      summary: summary,
      totalLineData: totalLineData,
      incomeExpenseData: await _getIncomeExpenseData(
        accountId,
        startOfYear,
        endOfYear,
      ),
      plannedData: await _getPlannedData(
        accountId,
        now.millisecondsSinceEpoch,
        DateTime(now.year, now.month + 12, 1).millisecondsSinceEpoch,
      ),
    );

    // return ReportData(
    //   summary: summary,
    //   totalLineData: totalLineData,
    //   totalLineDataPercentage: 0,
    //   incomeExpenseData: incomeExpenseData,
    //   plannedData: plannedData,
    // );
  }

  // ✅ 1. Summary по активам (Money/Stocks/Bonds/Funds/Crypto/Other)
  Future<Map<String, double>> _getAssetSummary(
    String accountId,
    int endTime,
  ) async {
    // ✅ total = все аккаунты без excludeFromTotal
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

    // Добавляем Total и заполняем отсутствующие категории
    summary['total'] = summary.values.fold(0.0, (sum, val) => sum + val);

    return summary;
  }

  // ✅ 2. Total стоимость портфеля по месяцам
  Future<List<ChartPoint>> _getTotalPortfolioValue(
    String accountId,
    int startTime,
    int endTime,
    double currentTotal,
  ) async {
    // ✅ total = все аккаунты без excludeFromTotal
    final accountCondition =
        accountId == 'total' ? "acc.excludeFromTotal = 'false'" : "acc.id = ?";

    final params =
        accountId == 'total'
            ? [startTime, endTime]
            : [startTime, endTime, accountId];

    final monthlyData = await _database.rawQuery('''
    SELECT 
      strftime('%m', datetime(a.create_at/1000, 'unixepoch')) as month,
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
    GROUP BY month
    ''', params);

    // ✅ 1. Считаем сумму ИЗМЕНЕНИЙ за весь период
    double totalChanges = 0.0;
    for (final row in monthlyData) {
      totalChanges += (row['total_value'] as num?)?.toDouble() ?? 0.0;
    }

    // ✅ 2. Начальная сумма = текущая - изменения за период
    double initialTotal = currentTotal - totalChanges;
    double runningTotal = initialTotal;

    final startMonth = DateTime.fromMillisecondsSinceEpoch(startTime).month;
    final startYear = DateTime.fromMillisecondsSinceEpoch(startTime).year;

    return List.generate(12, (i) {
      final targetMonth = ((startMonth - 1 + i) % 12) + 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');
      final row = monthlyData.firstWhere(
        (r) => (r['month'] as String?) == targetMonthStr,
        orElse: () => {'total_value': 0.0},
      );
      final monthlyChange = (row['total_value'] as num?)?.toDouble() ?? 0.0;
      runningTotal += monthlyChange;
      return ChartPoint(
        ((startYear + ((startMonth - 1 + i) > 11 ? 1 : 0)) * 100 + targetMonth).toDouble(), 
        runningTotal);
    });
  }

  // ✅ 3. Доход/Расход по месяцам из activities
  Future<List<MonthIncomeExpense>> _getIncomeExpenseData(
    String accountId,
    int startTime,
    int endTime,
  ) async {
    // ✅ total = все аккаунты без excludeFromTotal
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
          THEN ABS(a.quantity * a.price) 
          ELSE 0 
        END
      ) as income,
      SUM(
        CASE 
          WHEN a.type = 'substract'
          THEN ABS(a.quantity * a.price) 
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
      // ✅ Индекс относительно startTime (декабрь=12 → index 0)
      final targetMonth = ((startMonth - 1 + index) % 12) + 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');

      final row = result.firstWhere(
        (r) =>
            (r['month_index'] as String?) ==
            '${(index + 1).toString().padLeft(2, '0')}',
        orElse: () => {
          'income': 0.0, 
          'expense': 0.0,
          'year_index': (startYear + ((startMonth - 1 + index) > 11 ? 1 : 0)).toString(),
          'month_index': targetMonthStr, // ✅ НЕ null!
          },
      );
      return MonthIncomeExpense(
        year: (row['year_index'] as String).substring(2),
        month: (row['month_index'] as String?)?.padLeft(2, '0') ?? targetMonthStr,
        income: (row['income'] as num?)?.toDouble() ?? 0.0,
        expense: (row['expense'] as num?)?.toDouble() ?? 0.0,
      );
    });
  }

  // ✅ 4. План из scheduled_transactions
  Future<List<MonthIncomeExpense>> _getPlannedData(
    String accountId,
    int startTime,
    int endTime,
  ) async {
    // ✅ total = все аккаунты без excludeFromTotal
    final accountCondition =
        accountId == 'total' ? "acc.excludeFromTotal = 'false'" : "acc.id = ?";

    final params =
        accountId == 'total'
            ? [startTime, endTime]
            : [startTime, endTime, accountId];

    final result = await _database.rawQuery('''
      SELECT
        strftime('%Y', datetime(st.next_execution_date/1000, 'unixepoch')) as year_index,
        strftime('%m', datetime(st.next_execution_date/1000, 'unixepoch')) as month_index,
        SUM(CASE WHEN st.type = 'income' THEN amount ELSE 0 END) as planned_income,
        SUM(CASE WHEN st.type = 'expense' THEN amount ELSE 0 END) as planned_expense
      FROM scheduled_transactions st
      LEFT JOIN accounts acc ON acc.id = st.account_id
      WHERE next_execution_date BETWEEN ? AND ?
        AND $accountCondition
        AND executed_count < total_executions
      GROUP BY year_index, month_index
      ORDER BY year_index, month_index
    ''', params);

    // ✅ Правильный расчет индекса месяца от startTime
    final startMonth = DateTime.fromMillisecondsSinceEpoch(startTime).month;
    final startYear = DateTime.fromMillisecondsSinceEpoch(startTime).year;

    return List.generate(12, (index) {
      // ✅ Индекс относительно startTime (декабрь=12 → index 0)
      final targetMonth = ((startMonth - 1 + index) % 12) + 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');

      final row = result.firstWhere(
        (r) => (r['month_index'] as String?) == targetMonthStr,
        orElse: () => {
          'planned_income': 0.0, 
          'planned_expense': 0.0,
          'year_index': (startYear + ((startMonth - 1 + index) > 11 ? 1 : 0)).toString(),
          'month_index': targetMonthStr, // ✅ НЕ null!
        },
      );
      return MonthIncomeExpense(
        year: (row['year_index'] as String).substring(2),
        month: (row['month_index'] as String?)?.padLeft(2, '0') ?? targetMonthStr,
        income: (row['planned_income'] as num?)?.toDouble() ?? 0.0,
        expense: (row['planned_expense'] as num?)?.toDouble() ?? 0.0,
      );
    });
  }

  // ✅ _formatMonthForQuery для сопоставления с strftime('%Y-%m')
  String _formatMonthForQuery(int monthIndex) {
    final now = DateTime.now();
    final monthDate = DateTime(now.year, now.month - 11 + monthIndex);
    return '${monthDate.year}${monthDate.month.toString().padLeft(2, '0')}';
  }
}
