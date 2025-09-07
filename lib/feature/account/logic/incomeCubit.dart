import 'package:bookstore/data/models/activity.dart';
import 'package:bookstore/data/models/tool.dart';
import 'package:bookstore/data/repository/activityRepository.dart';
import 'package:bookstore/data/repository/toolRepository.dart';
import 'package:bookstore/feature/account/data/accountDataState.dart';
import 'package:bookstore/feature/account/data/incomeState.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Cubit responsible for managing the state and logic of the Add Income form.
class IncomeCubit extends Cubit<IncomeState> {

  IncomeCubit({
    required List<ToolSummary> initialMoneyTools,
  })  : super(IncomeState.initial(initialMoneyTools));

  /// Updates the amount in the state.
  void amountChanged(String value) {
    emit(state.copyWith(
        amount: value, formStatus: FormStatus.initial, errorMessage: null));
  }

  /// Updates the category in the state.
  void categoryChanged(String value) {
    emit(state.copyWith(
        category: value, formStatus: FormStatus.initial, errorMessage: null));
  }

  /// Updates the comment in the state.
  void commentChanged(String value) {
    emit(state.copyWith(
        comment: value, formStatus: FormStatus.initial, errorMessage: null));
  }

  /// Updates the selected date in the state.
  void dateSelected(DateTime date) {
    emit(state.copyWith(
        selectedDate: date, formStatus: FormStatus.initial, errorMessage: null));
  }

  /// Updates the selected money tool name in the state.
  void moneyToolSelected(String? toolName) {
    emit(state.copyWith(
        selectedMoneyToolId: toolName,
        formStatus: FormStatus.initial,
        errorMessage: null));
  }

  /// Performs client-side validation for the form.
  bool _validateForm() {
    final double? amount = double.tryParse(state.amount);
    return amount != null &&
        amount > 0 &&
        state.category.trim().isNotEmpty &&
        state.selectedDate != null &&
        state.selectedMoneyToolId != null &&
        state.availableMoneyTools
            .map<String>((ToolSummary t) => t.id!)
            .contains(state.selectedMoneyToolId);
  }
    /// Submits the income data.
  Future<void> submitIncome() async {
    if (!_validateForm()) {
      emit(state.copyWith(
          formStatus: FormStatus.validationError,
          errorMessage: 'Please fill all required fields correctly.'));
      return;
    }

    emit(state.copyWith(formStatus: FormStatus.loading, errorMessage: null));

    try {
      final double amount = double.parse(state.amount);
      final String category = state.category.trim();
      final String? comment =
          state.comment.trim().isEmpty ? null : state.comment.trim();

      debugPrint("submitIncome ${state.selectedMoneyToolId}");

      // add activity ti tool
      await ActivityRepository().insert(
          Activity(
            id: Uuid().v7(),
            toolId: state.selectedMoneyToolId!,
            type: ActivityType.add,
            createAt: state.selectedDate,
            quantity: amount,
            price: 1,
            currency: Currency.RUB,
            isTransmit: false,
            name: category,
            comment: comment,
          ),
        );

      emit(state.copyWith(formStatus: FormStatus.success));
    } catch (e) {
      emit(state.copyWith(
          formStatus: FormStatus.failure, errorMessage: e.toString()));
    }
  }
}