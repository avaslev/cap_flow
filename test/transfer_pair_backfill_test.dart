import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/core/utils/transferPairBackfill.dart';
import 'package:investflow/data/models/activity.dart';

Activity _act({
  required String id,
  required String toolId,
  required ActivityType type,
  required String name,
  double quantity = 1,
  double price = 1,
  bool isTransmit = true,
  String? pairId,
  DateTime? at,
}) {
  return Activity(
    id: id,
    toolId: toolId,
    type: type,
    createAt: at ?? DateTime(2026, 10, 22, 12),
    quantity: quantity,
    price: price,
    currency: Currency.RUB,
    isTransmit: isTransmit,
    name: name,
    transferPairId: pairId,
  );
}

const Map<String, String> _toolTypes = <String, String>{
  'money-1': 'money',
  'money-2': 'money',
  'deposit-1': 'deposit',
  'credit-1': 'credit',
  'other-1': 'other',
  'stock-1': 'stocks',
  'bond-1': 'bonds',
  'crypto-1': 'cryptocurrency',
};

void main() {
  group('computeTransferPairBackfill', () {
    test('связывает money-тул, созданный с переводом', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Открытие «Доллар США»',
            quantity: 90000,
            price: 1,
          ),
          _act(
            id: 'to',
            toolId: 'money-2',
            type: ActivityType.add,
            name: 'Открытие «Доллар США»',
            quantity: 1000,
            price: 90,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{'from': 'from', 'to': 'from'});
    });

    test('связывает депозит', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Открытие депозита «Вклад»',
            quantity: 50000,
            price: 1,
          ),
          _act(
            id: 'to',
            toolId: 'deposit-1',
            type: ActivityType.add,
            name: 'Открытие депозита',
            quantity: 1,
            price: 50000,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{'from': 'from', 'to': 'from'});
    });

    test('связывает кредит', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'from',
            toolId: 'credit-1',
            type: ActivityType.substract,
            name: 'Получение кредита «Кредит»',
            quantity: 50000,
            price: 1,
          ),
          _act(
            id: 'to',
            toolId: 'money-1',
            type: ActivityType.add,
            name: 'Получение кредита «Кредит»',
            quantity: 50000,
            price: 1,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{'from': 'from', 'to': 'from'});
    });

    test('связывает прочий актив', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Покупка актива «Машина»',
            quantity: 20000,
            price: 1,
          ),
          _act(
            id: 'to',
            toolId: 'other-1',
            type: ActivityType.add,
            name: 'Актив «Машина»',
            quantity: 1,
            price: 20000,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{'from': 'from', 'to': 'from'});
    });

    test('два депозита с разными суммами в одну миллисекунду связываются по сумме',
        () {
      final DateTime at = DateTime(2026, 10, 22);
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'f1',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Открытие депозита «A»',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 't1',
            toolId: 'deposit-1',
            type: ActivityType.add,
            name: 'Открытие депозита',
            quantity: 1,
            price: 10000,
            at: at,
          ),
          _act(
            id: 'f2',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Открытие депозита «B»',
            quantity: 20000,
            at: at,
          ),
          _act(
            id: 't2',
            toolId: 'deposit-1',
            type: ActivityType.add,
            name: 'Открытие депозита',
            quantity: 1,
            price: 20000,
            at: at,
          ),
        ],
        <String, String>{
          'money-1': 'money',
          'deposit-1': 'deposit',
        },
      );
      expect(result, <String, String>{
        'f1': 'f1',
        't1': 'f1',
        'f2': 'f2',
        't2': 'f2',
      });
    });

    test('неоднозначные пары не связываются', () {
      final DateTime at = DateTime(2026, 10, 22);
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'f1',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Открытие депозита «A»',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 'f2',
            toolId: 'money-2',
            type: ActivityType.substract,
            name: 'Открытие депозита «B»',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 't1',
            toolId: 'deposit-1',
            type: ActivityType.add,
            name: 'Открытие депозита',
            quantity: 1,
            price: 10000,
            at: at,
          ),
          _act(
            id: 't2',
            toolId: 'deposit-1',
            type: ActivityType.add,
            name: 'Открытие депозита',
            quantity: 1,
            price: 10000,
            at: at,
          ),
        ],
        <String, String>{
          'money-1': 'money',
          'money-2': 'money',
          'deposit-1': 'deposit',
        },
      );
      expect(result, isEmpty);
    });

    test('связывает покупку акции', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy Apple (money out)',
            quantity: 10000,
          ),
          _act(
            id: 'to',
            toolId: 'stock-1',
            type: ActivityType.add,
            name: 'Buy Apple',
            quantity: 10,
            price: 1000,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{'from': 'from', 'to': 'from'});
    });

    test('связывает покупку облигации и крипты', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'bond-from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy ОФЗ (money out)',
            quantity: 1000,
          ),
          _act(
            id: 'bond-to',
            toolId: 'bond-1',
            type: ActivityType.add,
            name: 'Buy ОФЗ',
            quantity: 1,
            price: 1000,
          ),
          _act(
            id: 'crypto-from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy BTC (money out)',
            quantity: 500000,
          ),
          _act(
            id: 'crypto-to',
            toolId: 'crypto-1',
            type: ActivityType.add,
            name: 'Buy BTC',
            quantity: 0.01,
            price: 50000000,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{
        'bond-from': 'bond-from',
        'bond-to': 'bond-from',
        'crypto-from': 'crypto-from',
        'crypto-to': 'crypto-from',
      });
    });

    test('две покупки одного инструмента в одну миллисекунду — по сумме', () {
      final DateTime at = DateTime(2026, 10, 22);
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'f1',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy Apple (money out)',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 't1',
            toolId: 'stock-1',
            type: ActivityType.add,
            name: 'Buy Apple',
            quantity: 10,
            price: 1000,
            at: at,
          ),
          _act(
            id: 'f2',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy Apple (money out)',
            quantity: 20000,
            at: at,
          ),
          _act(
            id: 't2',
            toolId: 'stock-1',
            type: ActivityType.add,
            name: 'Buy Apple',
            quantity: 20,
            price: 1000,
            at: at,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{
        'f1': 'f1',
        't1': 'f1',
        'f2': 'f2',
        't2': 'f2',
      });
    });

    test('связывает продажу инструмента', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'from',
            toolId: 'stock-1',
            type: ActivityType.substract,
            name: 'Sell Apple',
            quantity: 10,
            price: 1000,
          ),
          _act(
            id: 'to',
            toolId: 'money-1',
            type: ActivityType.add,
            name: 'Sell Apple (money in)',
            quantity: 12000,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{'from': 'from', 'to': 'from'});
    });

    test('покупка и продажа одного инструмента в одну миллисекунду', () {
      final DateTime at = DateTime(2026, 10, 22);
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'buy-from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy Apple (money out)',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 'buy-to',
            toolId: 'stock-1',
            type: ActivityType.add,
            name: 'Buy Apple',
            quantity: 10,
            price: 1000,
            at: at,
          ),
          _act(
            id: 'sell-from',
            toolId: 'stock-1',
            type: ActivityType.substract,
            name: 'Sell Apple',
            quantity: 10,
            price: 1000,
            at: at,
          ),
          _act(
            id: 'sell-to',
            toolId: 'money-1',
            type: ActivityType.add,
            name: 'Sell Apple (money in)',
            quantity: 12000,
            at: at,
          ),
        ],
        _toolTypes,
      );
      expect(result, <String, String>{
        'buy-from': 'buy-from',
        'buy-to': 'buy-from',
        'sell-from': 'sell-from',
        'sell-to': 'sell-from',
      });
    });

    test('неоднозначные покупки не связываются', () {
      final DateTime at = DateTime(2026, 10, 22);
      final Map<String, String> ambiguous = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'f1',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Buy Apple (money out)',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 'f2',
            toolId: 'money-2',
            type: ActivityType.substract,
            name: 'Buy Apple (money out)',
            quantity: 10000,
            at: at,
          ),
          _act(
            id: 't1',
            toolId: 'stock-1',
            type: ActivityType.add,
            name: 'Buy Apple',
            quantity: 10,
            price: 1000,
            at: at,
          ),
          _act(
            id: 't2',
            toolId: 'stock-1',
            type: ActivityType.add,
            name: 'Buy Apple',
            quantity: 10,
            price: 1000,
            at: at,
          ),
        ],
        _toolTypes,
      );
      expect(ambiguous, isEmpty);
    });

    test('одиночная transmit-запись и уже связанная пара не трогаются', () {
      final Map<String, String> result = computeTransferPairBackfill(
        <Activity>[
          _act(
            id: 'single',
            toolId: 'money-1',
            type: ActivityType.add,
            name: 'Открытие «Рубль»',
          ),
          _act(
            id: 'tagged-from',
            toolId: 'money-1',
            type: ActivityType.substract,
            name: 'Перевод на X',
            pairId: 'p',
          ),
          _act(
            id: 'tagged-to',
            toolId: 'money-2',
            type: ActivityType.add,
            name: 'Перевод с X',
            pairId: 'p',
          ),
        ],
        _toolTypes,
      );
      expect(result, isEmpty);
    });
  });
}
