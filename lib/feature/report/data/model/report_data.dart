// report_data.dart - ЧИСТЫЕ ДАННЫЕ БЕЗ ФРЕЙМВОРКА
class ReportData {
  final Map<String, double> summary;
  final List<ChartPoint> totalLineData;
  final double totalLineDataPercentage;
  final List<MonthIncomeExpense> incomeExpenseData;
  final List<MonthIncomeExpense> plannedData;

  /// Разбивка реальных расходов по категориям (activities.name) за 12 месяцев.
  final List<CategorySummary> categoryExpenses;

  /// Разбивка реальных доходов по категориям (activities.name) за 12 месяцев.
  final List<CategorySummary> categoryIncomes;

  const ReportData({
    required this.summary,
    required this.totalLineData,
    required this.totalLineDataPercentage,
    required this.incomeExpenseData,
    required this.plannedData,
    this.categoryExpenses = const <CategorySummary>[],
    this.categoryIncomes = const <CategorySummary>[],
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
    List<CategorySummary>? categoryExpenses,
    List<CategorySummary>? categoryIncomes,
  }) {
    return ReportData(
      summary: summary ?? this.summary,
      totalLineData: totalLineData ?? this.totalLineData,
      totalLineDataPercentage:
          totalLineDataPercentage ?? this.totalLineDataPercentage,
      incomeExpenseData: incomeExpenseData ?? this.incomeExpenseData,
      plannedData: plannedData ?? this.plannedData,
      categoryExpenses: categoryExpenses ?? this.categoryExpenses,
      categoryIncomes: categoryIncomes ?? this.categoryIncomes,
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

  /// Плановые переводы между счетами (сколько нужно денег в месяце).
  final double budget;

  const MonthIncomeExpense({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    this.budget = 0.0,
  });
}

/// Сумма одной категории (activities.name) за 12-месячное окно отчёта.
/// Используется и для доходов, и для расходов.
class CategorySummary {
  final String name;

  /// Сумма за окно.
  final double total;

  /// Доля категории в общей сумме за окно (0..1).
  final double share;

  /// Суммы по месяцам окна: индексы совпадают с [ReportData.incomeExpenseData].
  final List<double> monthly;

  const CategorySummary({
    required this.name,
    required this.total,
    required this.share,
    required this.monthly,
  });
}

/// Собирает разбивку по категориям из строк SQL вида
/// (category, year_index, month_index, total).
///
/// [startYear]/[startMonth] — первый месяц окна отчёта (12 месяцев подряд);
/// строки вне окна отбрасываются. Результат отсортирован по убыванию суммы.
List<CategorySummary> buildCategorySummaries({
  required List<Map<String, Object?>> rows,
  required int startYear,
  required int startMonth,
}) {
  final int windowStartIndex = startYear * 12 + startMonth;
  final Map<String, List<double>> monthlyByName = <String, List<double>>{};

  for (final Map<String, Object?> row in rows) {
    final String name = (row['category'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;

    final int year = int.tryParse((row['year_index'] as String?) ?? '') ?? 0;
    final int month = int.tryParse((row['month_index'] as String?) ?? '') ?? 0;
    final int index = year * 12 + month - windowStartIndex;
    if (index < 0 || index > 11) continue;

    final double value =
        ((row['total'] ?? row['expense']) as num?)?.toDouble() ?? 0.0;
    final List<double> monthly = monthlyByName.putIfAbsent(
      name,
      () => List<double>.filled(12, 0.0),
    );
    monthly[index] += value;
  }

  double grandTotal = 0.0;
  for (final List<double> monthly in monthlyByName.values) {
    for (final double value in monthly) {
      grandTotal += value;
    }
  }

  final List<CategorySummary> result = monthlyByName.entries
      .map<CategorySummary>((MapEntry<String, List<double>> entry) {
        double total = 0.0;
        for (final double value in entry.value) {
          total += value;
        }
        return CategorySummary(
          name: entry.key,
          total: total,
          share: grandTotal > 0 ? total / grandTotal : 0.0,
          monthly: entry.value,
        );
      })
      .toList()
    ..sort((CategorySummary a, CategorySummary b) => b.total.compareTo(a.total));

  return result;
}
