import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/data/models/account.dart';
import 'package:investflow/data/models/activity.dart';

/// Раунд-трип новых полей: архивация счёта и связка пар переводов.
void main() {
  group('Account.isArchived', () {
    test('default is false', () {
      final Account a = Account(
        id: 'a',
        name: 'A',
        colorValue: 0xff000000,
        type: 'general',
        hideEvents: 'false',
        excludeFromTotal: 'false',
      );
      expect(a.isArchived, isFalse);
      expect(a.toMap()['isArchived'], 0);
    });

    test('persists through toMap/fromMap', () {
      final Account a = Account(
        id: 'a',
        name: 'A',
        colorValue: 0xff000000,
        type: 'general',
        hideEvents: 'false',
        excludeFromTotal: 'false',
        isArchived: true,
      );
      final Account restored = Account.fromMap(a.toMap());
      expect(restored.isArchived, isTrue);
    });
  });

  group('Activity.transferPairId', () {
    test('persists through toMap/fromMap', () {
      final Activity a = Activity(
        id: 'x',
        toolId: 't',
        type: ActivityType.substract,
        createAt: DateTime.fromMillisecondsSinceEpoch(1000),
        quantity: 10,
        price: 1,
        currency: Currency.RUB,
        isTransmit: true,
        name: 'Перевод',
        transferPairId: 'pair-1',
      );
      final Activity restored = Activity.fromMap(a.toMap());
      expect(restored.transferPairId, 'pair-1');
      expect(restored.isTransmit, isTrue);
    });

    test('null by default', () {
      final Activity a = Activity(
        id: 'x',
        toolId: 't',
        type: ActivityType.add,
        createAt: DateTime.fromMillisecondsSinceEpoch(1000),
        quantity: 10,
        price: 1,
        currency: Currency.RUB,
        isTransmit: false,
      );
      expect(a.transferPairId, isNull);
      expect(a.toMap()['transfer_pair_id'], isNull);
    });
  });
}
