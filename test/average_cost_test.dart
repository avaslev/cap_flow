import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/core/utils/averageCost.dart';
import 'package:investflow/data/models/activity.dart';

/// Тесты расчёта средней цены позиции (average cost) из истории активити.
/// Формула используется для реализованной прибыли/убытка при продаже.

Activity _act(
  ActivityType type,
  double quantity,
  double price,
  int day,
) => Activity(
  id: 'a$day-$type-$quantity-$price',
  toolId: 'tool',
  type: type,
  createAt: DateTime(2026, 1, day),
  quantity: quantity,
  price: price,
  currency: Currency.RUB,
  isTransmit: false,
);

void main() {
  test('пустая история: покупок нет — прибыль не считаем', () {
    final AverageCostResult r = computeAverageCost(<Activity>[]);
    expect(r.hasBuyHistory, isFalse);
    expect(r.avgCost, 0);
  });

  test('одна покупка: средняя равна цене', () {
    final AverageCostResult r = computeAverageCost(<Activity>[
      _act(ActivityType.add, 2, 100, 1),
    ]);
    expect(r.hasBuyHistory, isTrue);
    expect(r.avgCost, 100);
    expect(r.quantity, 2);
  });

  test('докупка усредняет цену: 2×100 + 1×150 → 116.67', () {
    final AverageCostResult r = computeAverageCost(<Activity>[
      _act(ActivityType.add, 2, 100, 1),
      _act(ActivityType.add, 1, 150, 2),
    ]);
    expect(r.avgCost, closeTo(116.67, 0.01));
    expect(r.quantity, 3);
  });

  test('частичная продажа списывает по средней: доход 83.33', () {
    // Куплено 2×100 + 1×150 (avg 116.67), продано 1×200.
    final AverageCostResult r = computeAverageCost(<Activity>[
      _act(ActivityType.add, 2, 100, 1),
      _act(ActivityType.add, 1, 150, 2),
      _act(ActivityType.substract, 1, 200, 3),
    ]);
    expect(r.avgCost, closeTo(116.67, 0.01));
    expect(r.quantity, 2);
    final double profit = (200 - r.avgCost) * 1;
    expect(profit, closeTo(83.33, 0.01));
  });

  test('порядок активити не зависит от сортировки списка', () {
    final AverageCostResult r = computeAverageCost(<Activity>[
      _act(ActivityType.add, 1, 150, 2),
      _act(ActivityType.add, 2, 100, 1),
    ]);
    expect(r.avgCost, closeTo(116.67, 0.01));
  });

  test('маркер прибыль/убыток (quantity 0) не влияет на расчёт', () {
    final AverageCostResult base = computeAverageCost(<Activity>[
      _act(ActivityType.add, 2, 100, 1),
    ]);
    final AverageCostResult withMarker = computeAverageCost(<Activity>[
      _act(ActivityType.add, 2, 100, 1),
      _act(
        ActivityType.add,
        0,
        83.33,
        2,
      ), // маркер: quantity 0, сумма в price
    ]);
    expect(withMarker.avgCost, base.avgCost);
    expect(withMarker.quantity, base.quantity);
  });

  test('продажа до нуля: средняя сохраняется для прибыли этой продажи', () {
    final AverageCostResult r = computeAverageCost(<Activity>[
      _act(ActivityType.add, 2, 100, 1),
      _act(ActivityType.substract, 2, 150, 2),
    ]);
    expect(r.quantity, 0);
    // Покупки были — прибыль продажи должна считаться.
    expect(r.hasBuyHistory, isTrue);
    expect(r.avgCost, 100);
  });
}
