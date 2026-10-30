import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/feature/account/data/addAccountFormState.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddAccountFormState.fromAccount', () {
    test('prefills name, color, type and flags', () {
      final AccountSummary account = AccountSummary(
        id: 'a',
        name: 'Брокерский',
        balance: 10,
        dailyChangeAmount: 0,
        dailyChangePercentage: 0,
        colorValue: 0xff28A745,
        type: AccountType.brokerage,
        hideEvents: true,
        excludeFromTotal: true,
      );

      final AddAccountFormState state = AddAccountFormState.fromAccount(
        account,
      );

      expect(state.name, 'Брокерский');
      expect(state.selectedColorValue, 0xff28A745);
      expect(state.selectedAccountType, AccountType.brokerage);
      expect(state.hideEvents, isTrue);
      expect(state.excludeFromTotal, isTrue);
      expect(state.balanceText, isEmpty);
    });
  });
}
