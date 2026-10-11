import 'package:investflow/core/utils/calculateNextOccurrence.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/activityState.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Cubit responsible for managing the state and logic of the Add Activity form.
class ActivityCubit extends Cubit<ActivityState> {
  ScheduledTransactionRepository _eventRepo = ScheduledTransactionRepository();
  final ToolRepository _toolRepo = ToolRepository();

  ActivityCubit({
    required List<ToolSummary> initialMoneyTools,
    required ActivityStateType activityType,
    Event? event,
    String? initialComment,
  })  : super(
          ActivityState.initial(
            initialMoneyTools,
            activityType,
            event,
            commentOverride: initialComment,
          ),
        );

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

      // K4: если событие привязано к credit-тулу — платёж по кредиту.
      // Считаем сплит проценты/тело от текущего остатка долга.
      double? interestAmount;
      double? principalAmount;
      String? linkedCreditToolId;
      if (state.eventId != null) {
        try {
          final ScheduledTransaction st =
              await _eventRepo.getById(state.eventId!);
          if (st.depositToolId != null && st.type == 'transfer') {
            final Tool linkedTool = await _toolRepo.get(st.depositToolId!);
            if (linkedTool.type == ToolType.credit.name) {
              linkedCreditToolId = linkedTool.id;
              final List<Activity> creditActivities =
                  await ActivityRepository()
                      .getActivityListByTool(linkedTool.id);
              double outstanding = 0;
              for (final Activity a in creditActivities) {
                outstanding += (a.type == ActivityType.add ? 1 : -1) *
                    a.price *
                    a.quantity;
              }
              outstanding = outstanding.abs();
              final double monthlyRate =
                  (linkedTool.interestRate ?? 0) / 100 / 12;
              interestAmount = outstanding * monthlyRate;
              principalAmount =
                  (amount - interestAmount).clamp(0.0, outstanding);
            }
          }
        } catch (_) {
          // Связка не кредитная — обычная операция без сплита.
        }
      }

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
            interestAmount: interestAmount,
            principalAmount: principalAmount,
          ),
        );

      // K4: тело кредита гасится — долг (кредит-тул) уменьшается.
      if (linkedCreditToolId != null && principalAmount != null && principalAmount > 0) {
        await ActivityRepository().insert(
          Activity(
            id: Uuid().v7(),
            toolId: linkedCreditToolId,
            type: ActivityType.add,
            createAt: state.selectedDate,
            quantity: principalAmount,
            price: 1,
            currency: Currency.RUB,
            isTransmit: true,
            name: 'Погашение тела кредита',
          ),
        );
      }

      if (state.eventId != null) {
        ScheduledTransaction st = await _eventRepo.getById(state.eventId!);
        await _eventRepo.update(st.copyWith(
          executedCount: st.executedCount + 1, 
          nextExecutionDate: calculateNextOccurrence(
            initialDate: st.date, 
            recurrenceType: st.recurrenceType, 
            recurrenceEndDate: st.recurrenceEndDate,
            recurrenceDayOfMonth: st.recurrenceDayOfMonth,
            now: st.nextExecutionDate)
        ));
      }

      emit(state.copyWith(formStatus: FormStatus.success));
    } catch (e) {
      emit(state.copyWith(
          formStatus: FormStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> submitSkipEvent() async {
    emit(state.copyWith(formStatus: FormStatus.loading, errorMessage: null));
    try {
      if (state.eventId != null) {
        ScheduledTransaction st = await _eventRepo.getById(state.eventId!);
        await _eventRepo.update(st.copyWith(
          executedCount: st.executedCount + 1, 
          nextExecutionDate: calculateNextOccurrence(
            initialDate: st.date, 
            recurrenceType: st.recurrenceType, 
            recurrenceEndDate: st.recurrenceEndDate,
            recurrenceDayOfMonth: st.recurrenceDayOfMonth,
            now: st.nextExecutionDate)
        ));
      }
      emit(state.copyWith(formStatus: FormStatus.success));
    } catch (e) {
      emit(state.copyWith(
          formStatus: FormStatus.failure, errorMessage: e.toString()));
    }
  }
}