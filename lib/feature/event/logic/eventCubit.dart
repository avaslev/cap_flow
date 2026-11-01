import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:capflow/core/utils/calculateNextOccurrence.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/repository/currencyRepository.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/feature/event/data/event.dart';
import 'package:capflow/feature/event/logic/eventState.dart';
import 'package:uuid/uuid.dart';

class FinancialEventCubit extends Cubit<FinancialEventEditState> {
  final ScheduledTransactionRepository _repo = ScheduledTransactionRepository();
  final ToolRepository _toolRepo = ToolRepository();
  final CurrencyRepository _currencyRepo = CurrencyRepository();

  FinancialEventCubit({required String accountId, FinancialEvent? event})
    : super(FinancialEventEditState.initial(accountId, event));

  // -----------------------------------------------------------------------
  // UI field updaters
  // -----------------------------------------------------------------------
  void nameChanged(String v) => emit(
    state.copyWith(
      event: state.event.copyWith(name: v),
      formStatus: FormStatus.initial,
    ),
  );

  void amountChanged(String v) => emit(
    state.copyWith(
      event: state.event.copyWith(amount: double.parse(v)),
      formStatus: FormStatus.initial,
    ),
  );

  void typeChanged(FinancialEventType v) => emit(
    state.copyWith(
      event: state.event.copyWith(type: v),
      formStatus: FormStatus.initial,
    ),
  );

  void categoryChanged(String v) => emit(
    state.copyWith(
      event: state.event.copyWith(category: v),
      formStatus: FormStatus.initial,
    ),
  );

  void dateChanged(DateTime v) => emit(
    state.copyWith(
      event: state.event.copyWith(date: v),
      formStatus: FormStatus.initial,
    ),
  );

  void walletChanged(String v) => emit(
    state.copyWith(
      event: state.event.copyWith(walletId: v),
      formStatus: FormStatus.initial,
    ),
  );

  void destinationWalletChanged(String? v) => emit(
    state.copyWith(
      event: state.event.copyWith(
        destinationWalletId: v,
        clearDestinationWalletId: v == null,
      ),
      formStatus: FormStatus.initial,
    ),
  );

  void commentChanged(String? v) => emit(
    state.copyWith(
      event: state.event.copyWith(comment: v),
      formStatus: FormStatus.initial,
    ),
  );

  void recurrenceTypeChanged(RecurrenceType v) => emit(
    state.copyWith(
      event: state.event.copyWith(recurrenceType: v),
      formStatus: FormStatus.initial,
    ),
  );

  void recurrenceEndDateChanged(DateTime? v) => emit(
    state.copyWith(
      event: state.event.copyWith(recurrenceEndDate: v),
      formStatus: FormStatus.initial,
    ),
  );

  void recurrenceDayOfMonthChanged(int? v) => emit(
    state.copyWith(
      event: state.event.copyWith(recurrenceDayOfMonth: v),
      formStatus: FormStatus.initial,
    ),
  );

  // -----------------------------------------------------------------------
  // Validation
  // -----------------------------------------------------------------------
  String _ticker(Tool tool, String defaultCurrency) =>
      tool.ticker ?? defaultCurrency;

  Future<bool> _validate() async {
    final double? parsed = state.event.amount;
    if (parsed == null || parsed <= 0) return false;
    if (state.event.name.trim().isEmpty) return false;
    // if (state.event.category.trim().isEmpty) return false;
    if (state.event.walletId.trim().isEmpty) return false;

    final bool isTransfer = state.event.type.isTransfer;
    if (isTransfer) {
      if (state.event.destinationWalletId == null ||
          state.event.destinationWalletId!.trim().isEmpty) {
        return false;
      }
      if (state.event.destinationWalletId == state.event.walletId) {
        return false;
      }
    }

    if (state.event.type == FinancialEventType.interAccountTransfer) {
      try {
        final Tool source = await _toolRepo.get(state.event.walletId);
        final Tool destination = await _toolRepo.get(
          state.event.destinationWalletId!,
        );
        final String defaultCurrency = await _currencyRepo.getDefaultCurrency();

        if (source.isClosed ||
            destination.isClosed ||
            source.type != ToolType.money.name ||
            destination.type != ToolType.money.name) {
          return false;
        }
        if (source.accountId != state.accountId) return false;
        if (source.accountId == destination.accountId) return false;
        if (_ticker(source, defaultCurrency) !=
            _ticker(destination, defaultCurrency)) {
          return false;
        }
      } catch (_) {
        return false;
      }
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
    if (!await _validate()) {
      emit(
        state.copyWith(
          formStatus: FormStatus.validationError,
          errorMessage: 'Заполните все обязательные поля корректно.',
        ),
      );
      return;
    }

    emit(state.copyWith(formStatus: FormStatus.loading));

    try {
      if (state.event.id.isEmpty) {
        final event = state.event.copyWith(id: Uuid().v7());
        int totalExecutions = 1;
        if (event.recurrenceEndDate != null) {
          DateTime? nextDate = event.date;
          while (null != nextDate &&
              nextDate.isBefore(event.recurrenceEndDate!)) {
            nextDate = calculateNextOccurrence(
              initialDate: event.date,
              recurrenceType: event.recurrenceType.name,
              recurrenceEndDate: event.recurrenceEndDate,
              recurrenceDayOfMonth: event.recurrenceDayOfMonth,
              now: nextDate,
            );
            totalExecutions++;
          }
        }
        await _repo.add(
          event.toScheduledTransaction(state.accountId, totalExecutions, 0),
        );
      } else {
        final st = await _repo.getById(state.event.id);
        // The form date represents the next execution; keep the original
        // first-occurrence date as the recurrence anchor.
        await _repo.update(
          state.event
              .toScheduledTransaction(
                state.accountId,
                st.totalExecutions,
                st.executedCount,
              )
              .copyWith(date: st.date),
        );
      }

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
