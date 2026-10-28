import 'package:capflow/data/repository/currencyRepository.dart';

/// Курсы перевода к дефолтной валюте.
///
/// [fromRate] и [toRate] — сколько рублей стоит 1 единица валюты источника
/// и получателя соответственно. Инвариант: `amountFrom * fromRate` равен
/// `amountTo * toRate` (одинаковый рублёвый эквивалент обеих половин).
class TransferRate {
  final double fromRate;
  final double toRate;

  const TransferRate(this.fromRate, this.toRate);

  @override
  String toString() =>
      'TransferRate(from: $fromRate, to: $toRate)';
}

/// Чистый расчёт курсов (без обращений к БД — удобно тестировать).
///
/// [baseFromRate]/[baseToRate] — текущие курсы валют к дефолтной
/// (для дефолтной валюты = 1, неизвестная = 0).
/// [amountFrom] — списываемая сумма в валюте источника,
/// [amountTo] — зачисляемая сумма в валюте получателя.
TransferRate computeTransferRate({
  required String fromTicker,
  required String toTicker,
  required String defaultCurrency,
  required double amountFrom,
  required double amountTo,
  required double baseFromRate,
  required double baseToRate,
}) {
  double safeRate(double rate) => rate > 0 && rate.isFinite ? rate : 0;

  final double bFrom = safeRate(baseFromRate);
  final double bTo = safeRate(baseToRate);

  // Одинаковая валюта: обе стороны оцениваются по одному курсу.
  if (fromTicker == toTicker) {
    final double rate = bFrom > 0
        ? bFrom
        : bTo > 0
        ? bTo
        : 1;
    return TransferRate(rate, rate);
  }

  // r — сколько единиц источника за 1 единицу получателя.
  final double r = amountTo > 0 && amountFrom > 0
      ? amountFrom / amountTo
      : 0;

  if (fromTicker == defaultCurrency) {
    // Источник — дефолтная валюта: fromRate = 1, toRate = r.
    return TransferRate(1, r > 0 ? r : (bTo > 0 ? bTo : 1));
  }
  if (toTicker == defaultCurrency) {
    // Получатель — дефолтная валюта: toRate = 1, fromRate = 1 / r.
    return TransferRate(
      r > 0 ? 1 / r : (bFrom > 0 ? bFrom : 1),
      1,
    );
  }
  if (bFrom > 0 && r > 0) {
    // Обе валюты не дефолтные: сохраняем курс источника, подгоняем получателя.
    return TransferRate(bFrom, bFrom * r);
  }
  if (bTo > 0 && r > 0) {
    return TransferRate(bTo / r, bTo);
  }
  if (r > 0) {
    return TransferRate(1, r);
  }
  return TransferRate(bFrom > 0 ? bFrom : 1, bTo > 0 ? bTo : 1);
}

/// Расчёт курсов с чтением из БД и (опционально) сохранением последних курсов.
Future<TransferRate> resolveTransferRates({
  required String fromTicker,
  required String toTicker,
  required double amountFrom,
  required double amountTo,
  CurrencyRepository? currencyRepository,
  bool persist = true,
}) async {
  final CurrencyRepository repo = currencyRepository ?? CurrencyRepository();
  final String def = await repo.getDefaultCurrency();
  final double baseFrom = fromTicker == def
      ? 1
      : await repo.getRate(fromTicker);
  final double baseTo = toTicker == def ? 1 : await repo.getRate(toTicker);

  final TransferRate result = computeTransferRate(
    fromTicker: fromTicker,
    toTicker: toTicker,
    defaultCurrency: def,
    amountFrom: amountFrom,
    amountTo: amountTo,
    baseFromRate: baseFrom,
    baseToRate: baseTo,
  );

  if (persist && fromTicker != toTicker) {
    if (result.fromRate > 0 && result.fromRate.isFinite) {
      await repo.setRate(fromTicker, result.fromRate);
    }
    if (result.toRate > 0 && result.toRate.isFinite) {
      await repo.setRate(toTicker, result.toRate);
    }
  }

  return result;
}
