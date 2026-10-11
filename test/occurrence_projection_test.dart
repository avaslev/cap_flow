import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/core/utils/calculateNextOccurrence.dart';

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
  DateTime cursor = firstDate;
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
    // Время суток наследуется от initialDate.
    expect(dates.first, DateTime(2026, 10, 15, 13, 24));
    expect(dates.last, DateTime(2027, 9, 15, 13, 24));
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
