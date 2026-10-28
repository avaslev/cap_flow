import 'package:flutter_test/flutter_test.dart';
import 'package:capflow/data/models/activity.dart';
import 'package:capflow/feature/activity/logic/activity_rows.dart';

Activity _act({
  required String id,
  required String toolId,
  required ActivityType type,
  required bool isTransmit,
  String? pairId,
  double quantity = 100,
  double price = 1,
  String? name,
  String? comment,
  DateTime? at,
}) {
  return Activity(
    id: id,
    toolId: toolId,
    type: type,
    createAt: at ?? DateTime(2026, 10, 22),
    quantity: quantity,
    price: price,
    currency: Currency.RUB,
    isTransmit: isTransmit,
    name: name,
    comment: comment,
    transferPairId: pairId,
  );
}

void main() {
  group('buildActivityRows', () {
    test('объединяет половины перевода в одну строку', () {
      final DateTime at = DateTime(2026, 10, 22, 12);
      final Activity from = _act(
        id: 'f',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
        pairId: 'pair',
        at: at,
      );
      final Activity to = _act(
        id: 't',
        toolId: 'tool-b',
        type: ActivityType.add,
        isTransmit: true,
        pairId: 'pair',
        at: at,
      );

      final List<ActivityRow> rows = buildActivityRows(<Activity>[from, to]);

      expect(rows, hasLength(1));
      expect(rows.single, isA<TransferActivityRow>());
      final TransferActivityRow row = rows.single as TransferActivityRow;
      expect(row.from.id, 'f');
      expect(row.to.id, 't');
      expect(row.commission, isNull);
      expect(row.transferPairId, 'pair');
    });

    test('прикрепляет комиссию и не выводит её отдельной строкой', () {
      final Activity from = _act(
        id: 'f',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
        pairId: 'pair',
      );
      final Activity commission = _act(
        id: 'c',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: false,
        pairId: 'pair',
        quantity: 5,
        name: 'Commission',
      );
      final Activity to = _act(
        id: 't',
        toolId: 'tool-b',
        type: ActivityType.add,
        isTransmit: true,
        pairId: 'pair',
      );

      final List<ActivityRow> rows = buildActivityRows(<Activity>[
        from,
        commission,
        to,
      ]);

      expect(rows, hasLength(1));
      final TransferActivityRow row = rows.single as TransferActivityRow;
      expect(row.commission?.id, 'c');
      expect(row.activities, hasLength(3));
    });

    test('перевод без transfer_pair_id остаётся двумя строками', () {
      final Activity from = _act(
        id: 'f',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
      );
      final Activity to = _act(
        id: 't',
        toolId: 'tool-b',
        type: ActivityType.add,
        isTransmit: true,
      );

      final List<ActivityRow> rows = buildActivityRows(<Activity>[from, to]);

      expect(rows, hasLength(2));
      expect(rows.every((ActivityRow r) => r is SingleActivityRow), isTrue);
    });

    test('неполная пара не объединяется и не теряется', () {
      final Activity from = _act(
        id: 'f',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
        pairId: 'pair',
      );
      final Activity other = _act(
        id: 'o',
        toolId: 'tool-a',
        type: ActivityType.add,
        isTransmit: false,
        name: 'Зарплата',
      );

      final List<ActivityRow> rows = buildActivityRows(<Activity>[from, other]);

      expect(rows, hasLength(2));
      expect(rows[0], isA<SingleActivityRow>());
      expect(rows[1], isA<SingleActivityRow>());
    });

    test('две разные пары дают две строки, порядок сохраняется', () {
      final Activity first = _act(
        id: 'f1',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
        pairId: 'p1',
        at: DateTime(2026, 10, 22, 10),
      );
      final Activity second = _act(
        id: 'f2',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
        pairId: 'p2',
        at: DateTime(2026, 10, 22, 9),
      );
      final Activity secondTo = _act(
        id: 't2',
        toolId: 'tool-b',
        type: ActivityType.add,
        isTransmit: true,
        pairId: 'p2',
        at: DateTime(2026, 10, 22, 9),
      );
      final Activity firstTo = _act(
        id: 't1',
        toolId: 'tool-b',
        type: ActivityType.add,
        isTransmit: true,
        pairId: 'p1',
        at: DateTime(2026, 10, 22, 10),
      );

      final List<ActivityRow> rows = buildActivityRows(<Activity>[
        first,
        second,
        secondTo,
        firstTo,
      ]);

      expect(rows, hasLength(2));
      expect((rows[0] as TransferActivityRow).from.id, 'f1');
      expect((rows[1] as TransferActivityRow).from.id, 'f2');
    });

    test('лишняя запись пары выводится отдельной строкой', () {
      final Activity from = _act(
        id: 'f',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: true,
        pairId: 'pair',
      );
      final Activity to = _act(
        id: 't',
        toolId: 'tool-b',
        type: ActivityType.add,
        isTransmit: true,
        pairId: 'pair',
      );
      final Activity commission = _act(
        id: 'c',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: false,
        pairId: 'pair',
        name: 'Commission',
      );
      final Activity extra = _act(
        id: 'extra',
        toolId: 'tool-a',
        type: ActivityType.substract,
        isTransmit: false,
        pairId: 'pair',
        name: 'Доп. комиссия',
      );

      final List<ActivityRow> rows = buildActivityRows(<Activity>[
        from,
        to,
        commission,
        extra,
      ]);

      expect(rows, hasLength(2));
      expect(rows[0], isA<TransferActivityRow>());
      expect((rows[0] as TransferActivityRow).commission?.id, 'c');
      expect((rows[1] as SingleActivityRow).activity.id, 'extra');
    });
  });

  group('TransferKind и сумма строки', () {
    TransferActivityRow _row(Activity from, Activity to) {
      final List<ActivityRow> rows = buildActivityRows(<Activity>[from, to]);
      return rows.single as TransferActivityRow;
    }

    test('покупка: название Buy, сумма — списание', () {
      final TransferActivityRow row = _row(
        _act(
          id: 'f',
          toolId: 'money',
          type: ActivityType.substract,
          isTransmit: true,
          pairId: 'p',
          quantity: 10000,
          name: 'Buy Apple (money out)',
        ),
        _act(
          id: 't',
          toolId: 'stock',
          type: ActivityType.add,
          isTransmit: true,
          pairId: 'p',
          quantity: 10,
          price: 1000,
          name: 'Buy Apple',
        ),
      );
      expect(row.kind, TransferKind.purchase);
      expect(row.rubAmount, 10000);
    });

    test('покупка прочего актива (Актив «…»)', () {
      final TransferActivityRow row = _row(
        _act(
          id: 'f',
          toolId: 'money',
          type: ActivityType.substract,
          isTransmit: true,
          pairId: 'p',
          quantity: 20000,
          name: 'Покупка актива «Машина»',
        ),
        _act(
          id: 't',
          toolId: 'other',
          type: ActivityType.add,
          isTransmit: true,
          pairId: 'p',
          quantity: 1,
          price: 20000,
          name: 'Актив «Машина»',
        ),
      );
      expect(row.kind, TransferKind.purchase);
      expect(row.rubAmount, 20000);
    });

    test('продажа: название Sell, сумма — выручка (зачисление)', () {
      final TransferActivityRow row = _row(
        _act(
          id: 'f',
          toolId: 'stock',
          type: ActivityType.substract,
          isTransmit: true,
          pairId: 'p',
          quantity: 10,
          price: 1000,
          name: 'Sell Apple',
        ),
        _act(
          id: 't',
          toolId: 'money',
          type: ActivityType.add,
          isTransmit: true,
          pairId: 'p',
          quantity: 12000,
          name: 'Sell Apple (money in)',
        ),
      );
      expect(row.kind, TransferKind.sale);
      expect(row.rubAmount, 12000);
    });

    test('обычный перевод', () {
      final TransferActivityRow row = _row(
        _act(
          id: 'f',
          toolId: 'a',
          type: ActivityType.substract,
          isTransmit: true,
          pairId: 'p',
          quantity: 500,
          name: 'Перевод на B',
        ),
        _act(
          id: 't',
          toolId: 'b',
          type: ActivityType.add,
          isTransmit: true,
          pairId: 'p',
          quantity: 500,
          name: 'Перевод с A',
        ),
      );
      expect(row.kind, TransferKind.transfer);
      expect(row.rubAmount, 500);
    });
  });
}
