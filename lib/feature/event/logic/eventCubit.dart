import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/logic/eventState.dart';
import 'package:uuid/uuid.dart';

class FinancialEventCubit extends Cubit<FinancialEventEditState> {

  final ScheduledTransactionRepository _repo = ScheduledTransactionRepository();
  
  FinancialEventCubit({
    required String accountId,
    FinancialEvent? event,
  })  : super(FinancialEventEditState.initial(accountId, event));


  // -----------------------------------------------------------------------
  // UI field updaters
  // -----------------------------------------------------------------------
  void nameChanged(String v) =>
      emit(state.copyWith(event: state.event.copyWith(name: v), formStatus: FormStatus.initial));

  void amountChanged(String v) =>
      emit(state.copyWith(event: state.event.copyWith(amount: double.parse(v)), formStatus: FormStatus.initial));

  void typeChanged(FinancialEventType v) =>
      emit(state.copyWith(event: state.event.copyWith(type: v), formStatus: FormStatus.initial));

  void categoryChanged(String v) =>
      emit(state.copyWith(event: state.event.copyWith(category: v), formStatus: FormStatus.initial));

  void dateChanged(DateTime v) =>
      emit(state.copyWith(event: state.event.copyWith(date: v), formStatus: FormStatus.initial));

  void walletChanged(String v) =>
      emit(state.copyWith(event: state.event.copyWith(walletId: v), formStatus: FormStatus.initial));

  void destinationWalletChanged(String? v) =>
      emit(state.copyWith(event: state.event.copyWith(destinationWalletId: v), formStatus: FormStatus.initial));

  void commentChanged(String? v) =>
      emit(state.copyWith(event: state.event.copyWith(comment: v), formStatus: FormStatus.initial));

  void recurrenceTypeChanged(RecurrenceType v) =>
      emit(state.copyWith(event: state.event.copyWith(recurrenceType: v), formStatus: FormStatus.initial));

  void recurrenceEndDateChanged(DateTime? v) =>
      emit(state.copyWith(event: state.event.copyWith(recurrenceEndDate: v), formStatus: FormStatus.initial));

  void recurrenceDayOfMonthChanged(int? v) =>
      emit(state.copyWith(event: state.event.copyWith(recurrenceDayOfMonth: v), formStatus: FormStatus.initial));

  // -----------------------------------------------------------------------
  // Validation
  // -----------------------------------------------------------------------
  bool _validate() {
    final double? parsed = state.event.amount;
    if (parsed == null || parsed <= 0) return false;
    if (state.event.name.trim().isEmpty) return false;
    // if (state.event.category.trim().isEmpty) return false;
    if (state.event.walletId.trim().isEmpty) return false;

    // transfer‑specific checks
    if (state.event.type == FinancialEventType.transfer) {
      if (state.event.destinationWalletId == null ||
          state.event.destinationWalletId!.trim().isEmpty) return false;
      if (state.event.destinationWalletId == state.event.walletId) return false;
    }

    // recurrence checks
    if (state.event.recurrenceType == RecurrenceType.monthlyOnDay &&
        (state.event.recurrenceDayOfMonth == null ||
            state.event.recurrenceDayOfMonth! < 1 ||
            state.event.recurrenceDayOfMonth! > 31)) {
      return false;
    }

    return true;
  }

  // -----------------------------------------------------------------------
  // Submit (create / update)
  // -----------------------------------------------------------------------
  Future<void> submit() async {
    if (!_validate()) {
      emit(state.copyWith(
        formStatus: FormStatus.validationError,
        errorMessage: 'Заполните все обязательные поля корректно.',
      ));
      return;
    }

    emit(state.copyWith(formStatus: FormStatus.loading));

    try {
      if (state.event.id.isEmpty) {
        final event = state.event.copyWith(id: Uuid().v7());
        await _repo.add(event.toScheduledTransaction(state.accountId, 1, 0));
      } else {
        final st = await _repo.getById(state.event.id);
        await _repo.update(state.event.toScheduledTransaction(state.accountId, st.totalExecutions, st.executedCount));
      }

      emit(state.copyWith(formStatus: FormStatus.success));
    } catch (e) {
      emit(state.copyWith(
        formStatus: FormStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
