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
      ChartPoint(0, 100000),
      ChartPoint(1, 120000),
      ChartPoint(2, 150000),
      ChartPoint(3, 180000),
      ChartPoint(4, 200000),
      ChartPoint(5, 220000),
      ChartPoint(6, 250000),
      ChartPoint(7, 280000),
      ChartPoint(8, 300000),
      ChartPoint(9, 320000),
      ChartPoint(10, 350000),
      ChartPoint(11, 380000),
    ],
    totalLineDataPercentage: 28,
    incomeExpenseData: List.generate(12, (index) => MonthIncomeExpense(
      income: 100000 + index * 15000,
      expense: 80000 + index * 10000,
    )),
    plannedData: List.generate(12, (index) => MonthIncomeExpense(
      income: 120000 + index * 12000,
      expense: 90000 + index * 8000,
    )),
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
      totalLineDataPercentage: totalLineDataPercentage ?? this.totalLineDataPercentage,
      incomeExpenseData: incomeExpenseData ?? this.incomeExpenseData,
      plannedData: plannedData ?? this.plannedData,
    );
  }
}

// ✅ Простые классы данных без зависимостей
class ChartPoint {
  final double x;
  final double y;

  const ChartPoint(this.x, this.y);
}

class MonthIncomeExpense {
  final double income;
  final double expense;

  const MonthIncomeExpense({
    required this.income,
    required this.expense,
  });
}
