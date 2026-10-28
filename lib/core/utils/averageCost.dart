import 'package:capflow/data/models/activity.dart';

/// Результат расчёта средней цены позиции по истории активити.
class AverageCostResult {
  /// Средняя цена одной единицы (на последнем ненулевом состоянии
  /// позиции — валидна и после полной продажи); 0, если покупок не было.
  final double avgCost;

  /// Итоговое количество по истории (0 при полной продаже).
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
/// При полной продаже (quantity = 0) средняя сохраняется — она нужна
/// для расчёта реализованной прибыли этой продажи.
AverageCostResult computeAverageCost(List<Activity> activities) {
  final List<Activity> sorted = [...activities]
    ..sort(
      (Activity a, Activity b) => a.createAt.compareTo(b.createAt),
    );
  double qty = 0;
  double cost = 0;
  double lastAvg = 0;
  bool sawBuy = false;
  for (final Activity a in sorted) {
    final double q = a.quantity.abs();
    if (a.type == ActivityType.add) {
      sawBuy = true;
      qty += q;
      cost += q * a.price;
    } else if (a.type == ActivityType.substract && qty > 0) {
      final double sell = q > qty ? qty : q;
      final double avg = cost / qty;
      cost -= sell * avg;
      qty -= sell;
    }
    if (qty > 0) {
      lastAvg = cost / qty;
    }
  }
  return AverageCostResult(
    avgCost: lastAvg,
    quantity: qty,
    hasBuyHistory: sawBuy,
  );
}
