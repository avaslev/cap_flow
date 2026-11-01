import 'package:capflow/core/utils/calculateNextOccurrence.dart';
import 'package:capflow/data/models/activity.dart';
import 'package:capflow/data/models/scheduledTransaction.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'package:capflow/data/repository/activityRepository.dart';
import 'package:capflow/data/repository/currencyRepository.dart';
import 'package:capflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:capflow/core/utils/transferRates.dart';
import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/feature/account/data/transferState.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Cubit responsible for managing the state and logic of the Add Income form.
class TransferCubit extends Cubit<TransferState> {
  final CurrencyRepository _currencyRepository = CurrencyRepository();
  final ToolRepository _toolRepository = ToolRepository();
  final ScheduledTransactionRepository _eventRepository =
      ScheduledTransactionRepository();
  TransferCubit({
    required ToolSummary currentTool,
    required List<ToolSummary> initialMoneyTools,
    required List<AccountSummary> accounts,
    String? fromToolId,
    String? toToolId,
    DateTime? initialDate,
    String? amount,
    String? comment,
    String? scheduledEventId,
    bool sameCurrencyOnly = false,
  }) : super(
         TransferState.initial(
           currentTool,
           initialMoneyTools,
           accounts,
           fromToolId: fromToolId,
           toToolId: toToolId,
           initialDate: initialDate,
           amount: amount,
           comment: comment,
           scheduledEventId: scheduledEventId,
           sameCurrencyOnly: sameCurrencyOnly,
         ),
       ) {
    _preferDefaultCurrencyTool();
  }

  /// «Откуда» по умолчанию — тул с дефолтной валютой из настроек.
  Future<void> _preferDefaultCurrencyTool() async {
    if (state.isScheduled) return;
    final ToolSummary? preferred = await selectDefaultMoneyTool(
      state.availableMoneyTools,
    );
    if (preferred != null && state.selectedFromToolId != preferred.id) {
      moneyFromToolSelected(preferred.id);
    }
  }

  /// «Будет списано» (валюта источника) — ручной ввод.
  void amountChanged(String value) {
    emit(
      state.copyWith(
        amount: value,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// «Получено» (валюта получателя) — ручной ввод.
  void amountToChanged(String value) {
    emit(
      state.copyWith(
        amountTo: value,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  /// Редактирование курса перевода (ручной ввод не перетирается).
  void rateChanged(String value) {
    emit(
      state.copyWith(
        rate: value,
        formStatus: FormStatus.initial,
        errorMessage: null,
      ),
    );
  }

  String? _tickerFor(String? toolId) {
    if (toolId == null) return null;
    for (final ToolSummary t in state.availableMoneyTools) {
      if (t.id == toolId) return t.ticker ?? 'RUB';
    }
    return null;
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
        fromTicker: _tickerFor(toolId),
        toTicker: _tickerFor(state.selectedToToolId),
        rate: '',
        amount: '',
        amountTo: '',
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
        fromTicker: _tickerFor(state.selectedFromToolId),
        toTicker: _tickerFor(toolId),
        rate: '',
        amount: '',
        amountTo: '',
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
    if (state.sameCurrencyOnly &&
        (state.fromTicker == null ||
            state.toTicker == null ||
            state.fromTicker != state.toTicker)) {
      return false;
    }
    if (state.isCrossCurrency) {
      final double? amount = double.tryParse(state.amount);
      final double? amountTo = double.tryParse(state.amountTo);
      return amount != null && amount > 0 && amountTo != null && amountTo > 0;
    }
    final double? amount = double.tryParse(state.amount);
    return amount != null &&
        amount > 0 &&
        state.selectedFromToolId != null &&
        state.selectedToToolId != null &&
        state.selectedToToolId != state.selectedFromToolId &&
        state.availableMoneyTools
            .map<String>((ToolSummary t) => t.id)
            .contains(state.selectedFromToolId) &&
        state.availableMoneyTools
            .map<String>((ToolSummary t) => t.id)
            .contains(state.selectedToToolId);
  }

  String _getToolName(String toolId) {
    return state.availableMoneyTools
            .where((ToolSummary tool) => tool.id == toolId)
            .map((ToolSummary tool) => tool.name)
            .firstOrNull ??
        toolId;
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
      // Списание из источника (валюта FROM) и зачисление (валюта TO).
      final double amountTo;
      final double amount;
      if (state.isCrossCurrency) {
        amount = double.parse(state.amount);
        amountTo = double.parse(state.amountTo);
      } else {
        amount = double.parse(state.amount);
        amountTo = amount;
      }
      final String? comment =
          state.comment.trim().isEmpty ? null : state.comment.trim();
      final double commission =
          double.tryParse(state.commission?.trim() ?? '') ?? 0;
      // Имя от лица каждой стороны: на странице тула направление читается однозначно.
      final String namePrefix = state.isCrossCurrency ? 'Обмен' : 'Перевод';
      final String name =
          '$namePrefix на ${_getToolName(state.selectedToToolId!)}';
      final String targetName =
          '$namePrefix с ${_getToolName(state.selectedFromToolId!)}';

      // Валюты тула: цена активити = курс к дефолтной; эквивалент = quantity × price.
      final Tool fromTool = await _toolRepository.get(
        state.selectedFromToolId!,
      );
      final Tool toTool = await _toolRepository.get(state.selectedToToolId!);
      final String defCurrency = await _currencyRepository.getDefaultCurrency();
      final String ft = fromTool.ticker ?? defCurrency;
      final String tt = toTool.ticker ?? defCurrency;

      double fromRate;
      double toRate;
      if (state.isCrossCurrency) {
        // Цены сторон обязаны давать одинаковый рублёвый эквивалент:
        // quantity_from × fromRate = quantity_to × toRate.
        final TransferRate rates = await resolveTransferRates(
          fromTicker: ft,
          toTicker: tt,
          amountFrom: amount,
          amountTo: amountTo,
          currencyRepository: _currencyRepository,
        );
        fromRate = rates.fromRate;
        toRate = rates.toRate;
      } else {
        fromRate =
            ft == defCurrency ? 1 : await _currencyRepository.getRate(ft);
        if (fromRate <= 0 || !fromRate.isFinite) fromRate = 1;
        toRate = fromRate;
      }

      // add activity ti tool (source)
      // Общий id пары переводов: обе половины (списание/зачисление)
      // связываются им для каскадного удаления.
      final String transferPairId = Uuid().v7();
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: state.selectedFromToolId!,
          type: ActivityType.substract,
          createAt: state.selectedDate,
          quantity: amount,
          price: fromRate,
          currency: Currency.RUB,
          isTransmit: true,
          name: name,
          comment: comment,
          transferPairId: transferPairId,
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
            price: fromRate,
            currency: Currency.RUB,
            isTransmit: false,
            name: 'Commission',
            comment: '${name}',
            transferPairId: transferPairId,
          ),
        );
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: state.selectedToToolId!,
          type: ActivityType.add,
          createAt: state.selectedDate,
          quantity: amountTo,
          price: toRate,
          currency: Currency.RUB,
          isTransmit: true,
          name: targetName,
          comment: comment,
          transferPairId: transferPairId,
        ),
      );

      if (state.scheduledEventId != null) {
        final ScheduledTransaction st = await _eventRepository.getById(
          state.scheduledEventId!,
        );
        await _eventRepository.update(
          st.copyWith(
            executedCount: st.executedCount + 1,
            nextExecutionDate: calculateNextOccurrence(
              initialDate: st.date,
              recurrenceType: st.recurrenceType,
              recurrenceEndDate: st.recurrenceEndDate,
              recurrenceDayOfMonth: st.recurrenceDayOfMonth,
              now: st.nextExecutionDate,
            ),
          ),
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
