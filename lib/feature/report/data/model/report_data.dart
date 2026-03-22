// report_data.dart - ЧИСТЫЕ ДАННЫЕ БЕЗ ФРЕЙМВОРКА
class ReportData {
  final Map<String, double> summary;
  final List<ChartPoint> totalLineData;
  final double totalLineDataPercentage;
  final List<MonthIncomeExpense> incomeExpenseData;
  final List<MonthIncomeExpense> plannedData;

  const ReportData({
    required this.summary,
    required this.totalLineData,
    required this.totalLineDataPercentage,
    required this.incomeExpenseData,
    required this.plannedData,
  });

  // ✅ Фабрика для демо-данных
  factory ReportData.demo() => ReportData(
    summary: {
      'Total': 1250000.0,
      'Money': 450000.0,
      'Stocks': 320000.0,
      'Bonds': 180000.0,
      'Funds': 150000.0,
      'Crypto': 80000.0,
      'Other': 50000.0,
    },
    totalLineData: [
      // ChartPoint(2501, 100000),
      // ChartPoint(2502, 120000),
      // ChartPoint(2503, 150000),
      // ChartPoint(2504, 180000),
      // ChartPoint(2505, 200000),
      // ChartPoint(2506, 220000),
      // ChartPoint(2507, 250000),
      // ChartPoint(2508, 280000),
      // ChartPoint(2509, 300000),
      // ChartPoint(2510, 320000),
      // ChartPoint(2511, 350000),
      // ChartPoint(2512, 380000),
    ],
    totalLineDataPercentage: 28,
    incomeExpenseData: List.generate(
      12,
      (index) => MonthIncomeExpense(
        year: '25',
        month: (index + 1).toString().padLeft(2, '0'),
        income: 100000 + index * 15000,
        expense: 80000 + index * 10000,
      ),
    ),
    plannedData: List.generate(
      12,
      (index) => MonthIncomeExpense(
        year: '25',
        month: (index + 1).toString().padLeft(2, '0'),
        income: 120000 + index * 12000,
        expense: 90000 + index * 8000,
      ),
    ),
  );

  // ✅ copyWith для иммутабельности
  ReportData copyWith({
    Map<String, double>? summary,
    List<ChartPoint>? totalLineData,
    double? totalLineDataPercentage,
    List<MonthIncomeExpense>? incomeExpenseData,
    List<MonthIncomeExpense>? plannedData,
  }) {
    return ReportData(
      summary: summary ?? this.summary,
      totalLineData: totalLineData ?? this.totalLineData,
      totalLineDataPercentage:
          totalLineDataPercentage ?? this.totalLineDataPercentage,
      incomeExpenseData: incomeExpenseData ?? this.incomeExpenseData,
      plannedData: plannedData ?? this.plannedData,
    );
  }
}

class ChartPoint {
  final String year;
  final String month;
  final double value;

  const ChartPoint({
    required this.year,
    required this.month,
    required this.value,
  });
}

class MonthIncomeExpense {
  final String year;
  final String month;
  final double income;
  final double expense;

  const MonthIncomeExpense({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });
}
