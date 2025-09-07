import 'package:bookstore/data/models/activity.dart';
import 'package:bookstore/data/models/tool.dart';
import 'package:bookstore/data/repository/activityRepository.dart';
import 'package:bookstore/data/repository/toolRepository.dart';
import 'package:bookstore/feature/account/data/accountDataState.dart';
import 'package:bookstore/feature/account/data/transferState.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Cubit responsible for managing the state and logic of the Add Income form.
class TransferCubit extends Cubit<TransferState> {
  TransferCubit({
    required ToolSummary currentTool,
    required List<ToolSummary> initialMoneyTools,
    required List<AccountSummary> accounts,
  }) : super(TransferState.initial(currentTool, initialMoneyTools, accounts));

  /// Updates the amount in the state.
  void amountChanged(String value) {
    emit(
      state.copyWith(
        amount: value,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// Updates the comment in the state.
  void commentChanged(String value) {
    emit(
      state.copyWith(
        comment: value,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// Updates the selected date in the state.
  void dateSelected(DateTime date) {
    emit(
      state.copyWith(
        selectedDate: date,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// Updates the selected money tool name in the state.
  void moneyFromToolSelected(String? toolId) {
    emit(
      state.copyWith(
        selectedFromToolId: toolId,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// Updates the selected money tool name in the state.
  void moneyToToolSelected(String? toolId) {
    emit(
      state.copyWith(
        selectedToToolId: toolId,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  void commissionChanged(String value) {
    emit(
      state.copyWith(
        commission: value,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// Performs client-side validation for the form.
  bool _validateForm() {
    final double? amount = double.tryParse(state.amount);
    return amount != null &&
        amount > 0 &&
        state.selectedDate != null &&
        state.selectedFromToolId != null &&
        state.selectedToToolId != null &&
        state.selectedToToolId != state.selectedFromToolId &&
        state.availableMoneyTools
            .map<String>((ToolSummary t) => t.id!)
            .contains(state.selectedFromToolId) &&
        state.availableMoneyTools
            .map<String>((ToolSummary t) => t.id!)
            .contains(state.selectedToToolId);
  }

  String _getAccountName(String toolId) {
    return state.accounts
        .where(
          (AccountSummary account) =>
              account.id ==
              state.availableMoneyTools
                  .where((ToolSummary tool) => tool.id == toolId)
                  .first
                  .accountId,
        )
        .first
        .name;
  }

  /// Submits the income data.
  Future<void> submitIncome() async {
    if (!_validateForm()) {
      emit(
        state.copyWith(
          formStatus: FormStatus.validationError,
          errorMessage: 'Please fill all required fields correctly.',
        ),
      );
      return;
    }

    emit(state.copyWith(formStatus: FormStatus.loading, errorMessage: null));

    try {
      final double amount = double.parse(state.amount);
      final String? comment =
          state.comment.trim().isEmpty ? null : state.comment.trim();
      final double commission = double.parse(state.commission ?? '0');
      final String name =
          'transfer from ${_getAccountName(state.selectedFromToolId!)} to ${_getAccountName(state.selectedToToolId!)}';

      debugPrint(
        "submitTransfer ${state.selectedFromToolId} to ${state.selectedToToolId}",
      );

      // add activity ti tool
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: state.selectedFromToolId!,
          type: ActivityType.substract,
          createAt: state.selectedDate,
          quantity: amount,
          price: 1,
          currency: Currency.RUB,
          isTransmit: true,
          name: name,
        ),
      );
      if (commission > 0)
        await ActivityRepository().insert(
          Activity(
            id: Uuid().v7(),
            toolId: state.selectedFromToolId!,
            type: ActivityType.substract,
            createAt: state.selectedDate,
            quantity: commission,
            price: 1,
            currency: Currency.RUB,
            isTransmit: false,
            name: 'commission ${name}',
          ),
        );
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: state.selectedToToolId!,
          type: ActivityType.add,
          createAt: state.selectedDate,
          quantity: amount,
          price: 1,
          currency: Currency.RUB,
          isTransmit: true,
          name: name,
        ),
      );

      emit(state.copyWith(formStatus: FormStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          formStatus: FormStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
