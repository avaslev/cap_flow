import 'package:investflow/data/models/activity.dart';

/// Результат расчёта средней цены позиции по истории активити.
class AverageCostResult {
  /// Средняя цена одной единицы; 0, если покупок не было.
  final double avgCost;

  /// Итоговое количество по истории.
  final double quantity;

  /// Были ли покупки в истории (иначе прибыль считать нельзя).
  final bool hasBuyHistory;

  const AverageCostResult({
    required this.avgCost,
    required this.quantity,
    required this.hasBuyHistory,
  });
}

/// Средняя цена позиции (average cost) по истории активити тула.
/// Покупки увеличивают себестоимость, продажи списывают по средней
/// на тот момент. Маркер-активити (quantity = 0) не влияют.
AverageCostResult computeAverageCost(List<Activity> activities) {
  final List<Activity> sorted = [...activities]
    ..sort(
      (Activity a, Activity b) => a.createAt.compareTo(b.createAt),
    );
  double qty = 0;
  double cost = 0;
  for (final Activity a in sorted) {
    final double q = a.quantity.abs();
    if (a.type == ActivityType.add) {
      qty += q;
      cost += q * a.price;
    } else if (a.type == ActivityType.substract && qty > 0) {
      final double sell = q > qty ? qty : q;
      final double avg = cost / qty;
      cost -= sell * avg;
      qty -= sell;
    }
  }
  final bool hasBuys = qty > 0 && cost > 0;
  return AverageCostResult(
    avgCost: qty > 0 ? cost / qty : 0,
    quantity: qty,
    hasBuyHistory: hasBuys,
  );
}
