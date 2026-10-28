import 'package:flutter_test/flutter_test.dart';
import 'package:capflow/core/utils/transferRates.dart';

void main() {
  group('computeTransferRate', () {
    test('источник — дефолтная валюта', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'RUB',
        toTicker: 'USD',
        defaultCurrency: 'RUB',
        amountFrom: 90000,
        amountTo: 1000,
        baseFromRate: 1,
        baseToRate: 90,
      );
      expect(r.fromRate, 1);
      expect(r.toRate, 90);
      expect(
        r.fromRate * 90000,
        closeTo(r.toRate * 1000, 1e-6),
      );
    });

    test('получатель — дефолтная валюта', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'USD',
        toTicker: 'RUB',
        defaultCurrency: 'RUB',
        amountFrom: 1000,
        amountTo: 90000,
        baseFromRate: 90,
        baseToRate: 1,
      );
      expect(r.fromRate, 90);
      expect(r.toRate, 1);
      expect(
        r.fromRate * 1000,
        closeTo(r.toRate * 90000, 1e-6),
      );
    });

    test('обе валюты не дефолтные: сохраняется курс источника', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'USD',
        toTicker: 'EUR',
        defaultCurrency: 'RUB',
        amountFrom: 1000,
        amountTo: 900,
        baseFromRate: 90,
        baseToRate: 100,
      );
      expect(r.fromRate, 90);
      expect(r.toRate, closeTo(100, 1e-6));
      expect(
        r.fromRate * 1000,
        closeTo(r.toRate * 900, 1e-6),
      );
    });

    test('обе валюты не дефолтные: используется курс получателя', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'USD',
        toTicker: 'EUR',
        defaultCurrency: 'RUB',
        amountFrom: 1000,
        amountTo: 900,
        baseFromRate: 0,
        baseToRate: 100,
      );
      expect(r.toRate, 100);
      expect(r.fromRate, closeTo(100 / (1000 / 900), 1e-6));
    });

    test('одинаковая валюта: один курс на обе стороны', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'USD',
        toTicker: 'USD',
        defaultCurrency: 'RUB',
        amountFrom: 1000,
        amountTo: 1000,
        baseFromRate: 90,
        baseToRate: 90,
      );
      expect(r.fromRate, 90);
      expect(r.toRate, 90);
    });

    test('курсы неизвестны: рублёвый эквивалент задаёт сумма списания', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'USD',
        toTicker: 'EUR',
        defaultCurrency: 'RUB',
        amountFrom: 1000,
        amountTo: 900,
        baseFromRate: 0,
        baseToRate: 0,
      );
      expect(r.fromRate, 1);
      expect(r.toRate, closeTo(1000 / 900, 1e-6));
      expect(
        r.fromRate * 1000,
        closeTo(r.toRate * 900, 1e-6),
      );
    });

    test('нулевые суммы не ломают расчёт', () {
      final TransferRate r = computeTransferRate(
        fromTicker: 'RUB',
        toTicker: 'USD',
        defaultCurrency: 'RUB',
        amountFrom: 0,
        amountTo: 0,
        baseFromRate: 1,
        baseToRate: 90,
      );
      expect(r.fromRate.isFinite, isTrue);
      expect(r.toRate, 90);
    });
  });
}
