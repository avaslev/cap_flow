import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/core/utils/calculateNextOccurrence.dart';

/// Тесты квартального и полугодового повторений (купоны облигаций),
/// добавленных для дивидендно-купонного планировщика.

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

void main() {
  group('calculateNextOccurrence: quarterly', () {
    test('первая дата в будущем — возвращается как есть', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 12, 1),
        recurrenceType: 'quarterly',
        now: _d(2026, 10, 15),
      );
      expect(next, _d(2026, 12, 1));
    });

    test('просроченная дата сдвигается на 3 месяца', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 1, 10),
        recurrenceType: 'quarterly',
        now: _d(2026, 10, 15),
      );
      expect(next, _d(2027, 1, 10));
    });

    test('середина цикла: ближайший будущий квартальный срок', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 1, 10),
        recurrenceType: 'quarterly',
        now: _d(2026, 2, 15),
      );
      expect(next, _d(2026, 4, 10));
    });

    test('31-е число в коротком месяце — 30 апреля/28 февраля', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 1, 31),
        recurrenceType: 'quarterly',
        now: _d(2026, 2, 15),
      );
      expect(next, _d(2026, 4, 30));
    });
  });

  group('calculateNextOccurrence: semiannual', () {
    test('просроченная дата сдвигается на 6 месяцев', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 3, 20),
        recurrenceType: 'semiannual',
        now: _d(2026, 10, 15),
      );
      expect(next, _d(2027, 3, 20));
    });

    test('середина цикла: ближайшее будущее полугодие', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 1, 10),
        recurrenceType: 'semiannual',
        now: _d(2026, 4, 1),
      );
      expect(next, _d(2026, 7, 10));
    });
  });

  group('calculateNextOccurrence: ограничители', () {
    test('recurrenceEndDate раньше следующего срока — null', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 1, 10),
        recurrenceType: 'quarterly',
        recurrenceEndDate: _d(2026, 3, 1),
        now: _d(2026, 2, 15),
      );
      expect(next, isNull);
    });

    test('none — всегда null', () {
      final DateTime? next = calculateNextOccurrence(
        initialDate: _d(2026, 1, 10),
        recurrenceType: 'none',
        now: _d(2026, 2, 15),
      );
      expect(next, isNull);
    });
  });
}
