import 'package:flutter_test/flutter_test.dart';
import 'package:capflow/core/utils/calculateNextOccurrence.dart';

/// M-tests: projection of recurring occurrences (used by the report plan).

List<DateTime> projectOccurrences({
  required DateTime firstDate,
  required String recurrenceType,
  DateTime? recurrenceEndDate,
  int? recurrenceDayOfMonth,
  required DateTime windowEnd,
  int maxOccurrences = 400,
}) {
  final List<DateTime> out = <DateTime>[];
  // Нормализация к полуночи — как в отчёте (бакеты по дням).
  final DateTime start = DateTime(
    firstDate.year,
    firstDate.month,
    firstDate.day,
  );
  DateTime cursor = start;
  int made = 0;
  while (!cursor.isAfter(windowEnd) && made < maxOccurrences) {
    if (recurrenceEndDate != null && cursor.isAfter(recurrenceEndDate)) break;
    out.add(cursor);
    made += 1;
    final DateTime? next = calculateNextOccurrence(
      initialDate: firstDate,
      recurrenceType: recurrenceType,
      recurrenceEndDate: recurrenceEndDate,
      recurrenceDayOfMonth: recurrenceDayOfMonth,
      now: cursor,
    );
    if (next == null || !next.isAfter(cursor)) break;
    cursor = next;
  }
  return out;
}

void main() {
  test('таймзона: время initialDate не дублирует occurrence в месяце', () {
    // Реальный кейс: monthlyOnDay день=20; nextExecution — 20-е 00:00,
    // date создания — 16-е 08:53. Без нормализации утилита возвращала
    // 20-е 08:53 — второй occurrence в том же месяце (дубль октября).
    final DateTime? next = calculateNextOccurrence(
      initialDate: DateTime(2026, 10, 16, 8, 53),
      recurrenceType: 'monthlyOnDay',
      recurrenceDayOfMonth: 20,
      now: DateTime(2026, 10, 20),
    );
    expect(next, DateTime(2026, 11, 20));
  });

  test('monthlyOnDay(15): кредит 11.10.2026 → 12 платежей окт26..сен27', () {
    final List<DateTime> dates = projectOccurrences(
      // Курсор стартует с next_execution_date (не с даты создания).
      firstDate: DateTime(2026, 10, 15, 13, 24),
      recurrenceType: 'monthlyOnDay',
      recurrenceEndDate: DateTime(2027, 10, 15),
      recurrenceDayOfMonth: 15,
      windowEnd: DateTime(2027, 10, 1), // конец окна отчёта
    );
    for (final DateTime d in dates) {
      // ignore: avoid_print
      print('occ: ${d.toIso8601String()}');
    }
    expect(dates.length, 12, reason: '12 платежей');
    // Даты нормализованы к полуночи: время initialDate (13:24 из-за
    // таймзоны) не должно порождать дубль occurrence внутри месяца.
    expect(dates.first, DateTime(2026, 10, 15));
    expect(dates.last, DateTime(2027, 9, 15));
  });

  test('monthly (ЖКХ, бессрочный): все месяцы окна', () {
    final List<DateTime> dates = projectOccurrences(
      firstDate: DateTime(2026, 10, 10),
      recurrenceType: 'monthly',
      windowEnd: DateTime(2027, 10, 1),
    );
    expect(dates.length, 12);
    expect(dates.first, DateTime(2026, 10, 10));
    expect(dates.last, DateTime(2027, 9, 10));
  });
}
