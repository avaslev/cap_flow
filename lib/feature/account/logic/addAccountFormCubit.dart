import 'package:capflow/feature/account/data/accountDataState.dart' show AccountType;
import 'package:capflow/feature/account/data/addAccountFormState.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddAccountFormCubit extends Cubit<AddAccountFormState> {
  AddAccountFormCubit([
    AddAccountFormState initialState = const AddAccountFormState(),
  ]) : super(initialState);

  void updateName(String name) => emit(state.copyWith(name: name));
  void updateBalanceText(String balanceText) => emit(state.copyWith(balanceText: balanceText));
  void updateSelectedColorValue(int colorValue) => emit(state.copyWith(selectedColorValue: colorValue));
  void updateSelectedAccountType(AccountType type) => emit(state.copyWith(selectedAccountType: type));
  void updateHideEvents(bool hideEvents) => emit(state.copyWith(hideEvents: hideEvents));
  void updateExcludeFromTotal(bool excludeFromTotal) => emit(state.copyWith(excludeFromTotal: excludeFromTotal));
}