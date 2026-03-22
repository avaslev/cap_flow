import 'package:investflow/core/db.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';
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
      );
    });
  }

  Future<List<MonthIncomeExpense>> _getPlannedData(
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

    final startMonth = DateTime.fromMillisecondsSinceEpoch(startTime).month;
    final startYear = DateTime.fromMillisecondsSinceEpoch(startTime).year;

    return List.generate(12, (index) {
      final targetMonth = ((startMonth - 1 + index) % 12) + 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');

      final row = result.firstWhere(
        (r) => (r['month_index'] as String?) == targetMonthStr,
        orElse:
            () => {
              'planned_income': 0.0,
              'planned_expense': 0.0,
              'year_index':
                  (startYear + ((startMonth - 1 + index) > 11 ? 1 : 0))
                      .toString(),
              'month_index': targetMonthStr, // ✅ НЕ null!
            },
      );
      return MonthIncomeExpense(
        year: (row['year_index'] as String).substring(2),
        month:
            (row['month_index'] as String?)?.padLeft(2, '0') ?? targetMonthStr,
        income: (row['planned_income'] as num?)?.toDouble() ?? 0.0,
        expense: (row['planned_expense'] as num?)?.toDouble() ?? 0.0,
      );
    });
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

    // for (int i = 1; i < totalLineData.length; i++) {
    //   final prevValue = totalLineData[i - 1].y;
    //   final currentValue = totalLineData[i].y;

    //   if (prevValue > 0) {
    //     final monthlyReturn = ((currentValue - prevValue) / prevValue) * 100;
    //     totalMonthlyReturn += monthlyReturn;
    //     validMonths++;
    //   }
    // }

    return validMonths > 0
        ? (totalMonthlyReturn / validMonths * 10).round() / 10
        : 0.0;
  }
}
