import 'package:capflow/core/utils/calculateNextOccurrence.dart';
import 'package:capflow/data/models/activity.dart';
import 'package:capflow/data/models/scheduledTransaction.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/repository/activityRepository.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/feature/account/data/activityState.dart';
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
        ) {
    _preferDefaultCurrencyTool();
  }

  /// По умолчанию выбирается тул с дефолтной валютой из настроек.
  Future<void> _preferDefaultCurrencyTool() async {
    if (state.eventId != null) return; // редактирование события — не трогаем
    final ToolSummary? preferred = await selectDefaultMoneyTool(
      state.availableMoneyTools,
    );
    if (preferred != null && state.selectedMoneyToolId != preferred.id) {
      moneyToolSelected(preferred.id);
    }
  }

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
      // K3-события (с destinationWalletId) уже разделены при создании
      // кредита: сумма события — чистое тело, проценты списываются
      // отдельным expense-событием. Сплит нужен только старым событиям,
      // где сумма была аннуитетом целиком (проценты + тело).
      //
      // Тело гасится парой записей (перевод money-тул → кредит-тул с
      // общим transferPairId, как в payCreditPayment): список показывает
      // её строкой «Перевод», отчёты не считают расходом. Проценты —
      // отдельный расход с маркером interestAmount.
      double? interestAmount;
      double? principalAmount;
      String? linkedCreditToolId;
      String? linkedCreditToolName;
      if (state.eventId != null) {
        try {
          final ScheduledTransaction st =
              await _eventRepo.getById(state.eventId!);
          if (st.depositToolId != null && st.type == 'transfer') {
            final Tool linkedTool = await _toolRepo.get(st.depositToolId!);
            if (linkedTool.type == ToolType.credit.name) {
              linkedCreditToolId = linkedTool.id;
              linkedCreditToolName = linkedTool.name;
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
              if (st.destinationWalletId != null) {
                principalAmount = amount.clamp(0.0, outstanding);
              } else {
                final double monthlyRate =
                    (linkedTool.interestRate ?? 0) / 100 / 12;
                final double fee =
                    (outstanding * monthlyRate).clamp(0.0, amount);
                interestAmount = fee > 0 ? fee : null;
                principalAmount = (amount - fee).clamp(0.0, outstanding);
              }
            }
          }
        } catch (_) {
          // Связка не кредитная — обычная операция без сплита.
        }
      }

      final bool isCreditPayment = linkedCreditToolId != null;
      final String? transferPairId = isCreditPayment ? Uuid().v7() : null;

      // add activity ti tool
      if (!isCreditPayment) {
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
      } else {
        // Тело кредита — перевод money-тул → кредит-тул.
        if (principalAmount != null && principalAmount > 0) {
          await ActivityRepository().insert(
            Activity(
              id: Uuid().v7(),
              toolId: state.selectedMoneyToolId!,
              type: ActivityType.substract,
              createAt: state.selectedDate,
              quantity: principalAmount,
              price: 1,
              currency: Currency.RUB,
              isTransmit: true,
              name: category,
              comment: comment,
              principalAmount: principalAmount,
              transferPairId: transferPairId,
            ),
          );
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
              name: 'Погашение тела кредита «$linkedCreditToolName»',
              principalAmount: principalAmount,
              transferPairId: transferPairId,
            ),
          );
        }
        // Проценты (только legacy-события) — отдельный расход.
        if (interestAmount != null && interestAmount > 0) {
          await ActivityRepository().insert(
            Activity(
              id: Uuid().v7(),
              toolId: state.selectedMoneyToolId!,
              type: ActivityType.substract,
              createAt: state.selectedDate,
              quantity: interestAmount,
              price: 1,
              currency: Currency.RUB,
              isTransmit: false,
              name: 'Проценты по кредиту «$linkedCreditToolName»',
              comment: comment,
              interestAmount: interestAmount,
            ),
          );
        }
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