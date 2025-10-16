import 'package:investflow/core/utils/calculateNextOccurrence.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/activityState.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Cubit responsible for managing the state and logic of the Add Activity form.
class ActivityCubit extends Cubit<ActivityState> {
  ScheduledTransactionRepository _eventRepo = ScheduledTransactionRepository();

  ActivityCubit({
    required List<ToolSummary> initialMoneyTools,
    required ActivityStateType activityType,
    Event? event,
  })  : super(ActivityState.initial(initialMoneyTools, activityType, event));

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
        state.selectedMoneyToolId != null &&
        state.availableMoneyTools
            .map<String>((ToolSummary t) => t.id)
            .contains(state.selectedMoneyToolId);
  }
    /// Submits the income data.
  Future<void> submitActivity() async {
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

      // add activity ti tool
      await ActivityRepository().insert(
          Activity(
            id: Uuid().v7(),
            toolId: state.selectedMoneyToolId!,
            type: switch (state.activityType) {
              ActivityStateType.add => ActivityType.add,
              ActivityStateType.substract => ActivityType.substract,
            },
            createAt: state.selectedDate,
            quantity: amount,
            price: 1,
            currency: Currency.RUB,
            isTransmit: false,
            name: category,
            comment: comment,
          ),
        );

      if (state.eventId != null) {
        ScheduledTransaction st = await _eventRepo.getById(state.eventId!);
        await _eventRepo.update(st.copyWith(
          executedCount: st.executedCount + 1, 
          nextExecutionDate: calculateNextOccurrence(
            initialDate: st.date, 
            recurrenceType: st.recurrenceType, 
            recurrenceEndDate: st.recurrenceEndDate,
            recurrenceDayOfMonth: st.recurrenceDayOfMonth,
            now: state.selectedDate)
        ));
      }


      emit(state.copyWith(formStatus: FormStatus.success));
    } catch (e) {
      emit(state.copyWith(
          formStatus: FormStatus.failure, errorMessage: e.toString()));
    }
  }
}