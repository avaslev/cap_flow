import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/currencyRepository.dart';
import 'package:investflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/transferState.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Cubit responsible for managing the state and logic of the Add Income form.
class TransferCubit extends Cubit<TransferState> {
  final CurrencyRepository _currencyRepository = CurrencyRepository();
  final ToolRepository _toolRepository = ToolRepository();
  TransferCubit({
    required ToolSummary currentTool,
    required List<ToolSummary> initialMoneyTools,
    required List<AccountSummary> accounts,
  }) : super(TransferState.initial(currentTool, initialMoneyTools, accounts)) {
    _preferDefaultCurrencyTool();
  }

  /// «Откуда» по умолчанию — тул с дефолтной валютой из настроек.
  Future<void> _preferDefaultCurrencyTool() async {
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

  /// Курс валюты к дефолтной; дефолтная = 1.
  Future<double> _rateToDefault(String ticker) async {
    final String def = await _currencyRepository.getDefaultCurrency();
    if (ticker == def) return 1;
    return _currencyRepository.getRate(ticker);
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
    if (state.isCrossCurrency) {
      final double? amount = double.tryParse(state.amount);
      final double? amountTo = double.tryParse(state.amountTo);
      return amount != null &&
          amount > 0 &&
          amountTo != null &&
          amountTo > 0;
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
        .firstOrNull ?? toolId;
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
      final double commission = double.parse(state.commission ?? '0');
      // Имя от лица каждой стороны: на странице тула направление читается однозначно.
      final String namePrefix = state.isCrossCurrency ? 'Обмен' : 'Перевод';
      final String name = '$namePrefix на ${_getToolName(state.selectedToToolId!)}';
      final String targetName =
          '$namePrefix с ${_getToolName(state.selectedFromToolId!)}';

      // Валюты тула: цена активити = курс к дефолтной; эквивалент = quantity × price.
      final Tool fromTool = await _toolRepository.get(state.selectedFromToolId!);
      final Tool toTool = await _toolRepository.get(state.selectedToToolId!);
      final String defCurrency = await _currencyRepository.getDefaultCurrency();
      double fromRate = await _rateToDefault(fromTool.ticker ?? defCurrency);
      double toRate = await _rateToDefault(toTool.ticker ?? defCurrency);

      if (state.isCrossCurrency) {
        // Курс обмена из введённых сумм (FROM за 1 TO). Цены сторон
        // обязаны давать одинаковый рублёвый эквивалент:
        // quantity_from × fromRate = quantity_to × toRate.
        final double manualRate = amount / amountTo;
        final String ft = fromTool.ticker ?? defCurrency;
        final String tt = toTool.ticker ?? defCurrency;
        if (ft == defCurrency) {
          // FROM — дефолтная: эквивалент задаёт сумма списания.
          fromRate = 1;
          toRate = 1 / manualRate;
        } else if (tt == defCurrency) {
          // TO — дефолтная: эквивалент задаёт сумма зачисления.
          toRate = 1;
          fromRate = manualRate;
        } else if (fromRate > 0) {
          toRate = fromRate * manualRate;
        } else if (toRate > 0) {
          fromRate = toRate / manualRate;
        } else {
          fromRate = 1;
          toRate = manualRate;
        }
        if (fromRate > 0) {
          await _currencyRepository.setRate(ft, fromRate);
        }
        if (toRate > 0) {
          await _currencyRepository.setRate(tt, toRate);
        }
      }

      // add activity ti tool (source)
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
