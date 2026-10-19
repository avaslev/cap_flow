import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';

/// Строки SQL вида (category, year_index, month_index, expense).
Map<String, Object?> row(String name, String year, String month, num expense) =>
    <String, Object?>{
      'category': name,
      'year_index': year,
      'month_index': month,
      'expense': expense,
    };

void main() {
  group('buildCategorySummaries', () {
    // Окно отчёта: ноябрь 2025 … октябрь 2026.
    const int startYear = 2025;
    const int startMonth = 11;

    test('накапливает месяцы и сортирует по убыванию суммы', () {
      final List<CategorySummary> result = buildCategorySummaries(
        rows: <Map<String, Object?>>[
          row('Дача', '2025', '11', 100),
          row('Дача', '2025', '12', 300),
          row('Дача', '2026', '01', 600),
          row('Еда', '2026', '04', 500),
        ],
        startYear: startYear,
        startMonth: startMonth,
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'Дача');
      expect(result[0].total, 1000);
      // Ноябрь 2025 → индекс 0, декабрь → 1, январь 2026 → 2.
      expect(result[0].monthly[0], 100);
      expect(result[0].monthly[1], 300);
      expect(result[0].monthly[2], 600);
      expect(result[0].monthly.every((double v) => v >= 0), isTrue);

      expect(result[1].name, 'Еда');
      expect(result[1].total, 500);
      // Апрель 2026 → индекс 5.
      expect(result[1].monthly[5], 500);
    });

    test('считает доли от общего расхода', () {
      final List<CategorySummary> result = buildCategorySummaries(
        rows: <Map<String, Object?>>[
          row('Дача', '2025', '11', 750),
          row('Еда', '2026', '01', 250),
        ],
        startYear: startYear,
        startMonth: startMonth,
      );

      expect(result[0].share, closeTo(0.75, 1e-9));
      expect(result[1].share, closeTo(0.25, 1e-9));
    });

    test('отбрасывает строки вне окна, пустые имена и null', () {
      final List<CategorySummary> result = buildCategorySummaries(
        rows: <Map<String, Object?>>[
          row('Дача', '2025', '10', 999), // до окна
          row('Дача', '2026', '11', 999), // после окна
          row('   ', '2025', '11', 999), // пустое имя
          row('Дача', '2025', '11', 50),
        ],
        startYear: startYear,
        startMonth: startMonth,
      );

      expect(result, hasLength(1));
      expect(result[0].name, 'Дача');
      expect(result[0].total, 50);
      expect(result[0].monthly[0], 50);
    });

    test('одинаковые имена склеиваются, разные месяцы складываются', () {
      final List<CategorySummary> result = buildCategorySummaries(
        rows: <Map<String, Object?>>[
          row('Дача', '2026', '01', 100),
          row('Дача', '2026', '01', 200),
        ],
        startYear: startYear,
        startMonth: startMonth,
      );

      expect(result, hasLength(1));
      expect(result[0].total, 300);
      expect(result[0].monthly[2], 300);
    });

    test('пустой результат — пустой список', () {
      expect(
        buildCategorySummaries(
          rows: const <Map<String, Object?>>[],
          startYear: startYear,
          startMonth: startMonth,
        ),
        isEmpty,
      );
    });

    test('отсутствие расходов не даёт деления на ноль', () {
      final List<CategorySummary> result = buildCategorySummaries(
        rows: <Map<String, Object?>>[row('Дача', '2025', '11', 0)],
        startYear: startYear,
        startMonth: startMonth,
      );

      expect(result, hasLength(1));
      expect(result[0].total, 0);
      expect(result[0].share, 0);
    });
  });
}
