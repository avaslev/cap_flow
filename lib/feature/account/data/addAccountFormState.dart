// DATA_MODEL for AddAccountForm's internal state
import 'package:bookstore/feature/account/data/accountDataState.dart';

class AddAccountFormState {
  final String name;
  final String balanceText; // Keep as string for input
  final int selectedColorValue;
  final AccountType selectedAccountType;
  final bool hideEvents;
  final bool excludeFromTotal;

  const AddAccountFormState({
    this.name = '',
    this.balanceText = '',
    this.selectedColorValue = 0xff007BFF, // Default color: Vibrant blue
    this.selectedAccountType = AccountType.general, // Default account type
    this.hideEvents = false,
    this.excludeFromTotal = false,
  });

  AddAccountFormState copyWith({
    String? name,
    String? balanceText,
    int? selectedColorValue,
    AccountType? selectedAccountType,
    bool? hideEvents,
    bool? excludeFromTotal,
  }) {
    return AddAccountFormState(
      name: name ?? this.name,
      balanceText: balanceText ?? this.balanceText,
      selectedColorValue: selectedColorValue ?? this.selectedColorValue,
      selectedAccountType: selectedAccountType ?? this.selectedAccountType,
      hideEvents: hideEvents ?? this.hideEvents,
      excludeFromTotal: excludeFromTotal ?? this.excludeFromTotal,
    );

  }
}