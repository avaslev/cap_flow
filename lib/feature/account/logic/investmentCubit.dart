import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/data/repository/settingsRepository.dart';
import 'package:investflow/data/source/cryptoSuggestSource.dart';
import 'package:uuid/uuid.dart';

enum InvestmentFormStatus { initial, loading, success, failure }

class InvestmentState {
  final InvestmentFormStatus formStatus;
  final String? errorMessage;
  final String? selectedTicker;
  final String? selectedName;
  final double? quantity;
  final double? price;
  final double? commission;
  final double? faceValue;
  final double? accruedCouponIncome;
  final DateTime selectedDate;
  final List<String> suggestions;
  /// Курс к дефолтной валюте по тикеру из внешнего источника.
  final Map<String, double> onlineRates;
  final InvestmentOperationType operationType;
  final ToolType investmentType;
  final String? accountId;

  InvestmentState({
    this.formStatus = InvestmentFormStatus.initial,
    this.errorMessage,
    this.selectedTicker,
    this.selectedName,
    this.quantity,
    this.price,
    this.commission,
    this.faceValue,
    this.accruedCouponIncome,
    DateTime? selectedDate,
    this.suggestions = const [],
    this.onlineRates = const <String, double>{},
    required this.operationType,
    required this.investmentType,
    required this.accountId,
  }) : selectedDate = selectedDate ?? DateTime.now();

  InvestmentState copyWith({
    InvestmentFormStatus? formStatus,
    String? errorMessage,
    String? selectedTicker,
    String? selectedName,
    double? quantity,
    double? price,
    double? commission,
    double? faceValue,
    double? accruedCouponIncome,
    DateTime? selectedDate,
    List<String>? suggestions,
    Map<String, double>? onlineRates,
    InvestmentOperationType? operationType,
    ToolType? investmentType,
    String? accountId,
  }) {
    return InvestmentState(
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedTicker: selectedTicker ?? this.selectedTicker,
      selectedName: selectedName ?? this.selectedName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      commission: commission ?? this.commission,
      faceValue: faceValue ?? this.faceValue,
      accruedCouponIncome: accruedCouponIncome ?? this.accruedCouponIncome,
      selectedDate: selectedDate ?? this.selectedDate,
      suggestions: suggestions ?? this.suggestions,
      onlineRates: onlineRates ?? this.onlineRates,
      operationType: operationType ?? this.operationType,
      investmentType: investmentType ?? this.investmentType,
      accountId: accountId ?? this.accountId,
    );
  }
}

class InvestmentCubit extends Cubit<InvestmentState> {
  final AccountData accountData;
  final String accountId;
  final InvestmentOperationType operationType;
  final ToolType investmentType;
  final AccountsBloc accountsBloc;
  final CryptoSuggestSource _cryptoSource = CryptoSuggestSource();
  final Map<String, List<OnlineInstrument>> _onlineCache =
      <String, List<OnlineInstrument>>{};
  String? _vsCurrencyCache;
  Timer? _searchDebounce;
  String? _searchQuery;

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    _cryptoSource.dispose();
    return super.close();
  }

  InvestmentCubit({
    required this.accountData,
    required this.accountId,
    required this.operationType,
    required this.investmentType,
    required this.accountsBloc,
  }) : super(InvestmentState(
          selectedDate: DateTime.now(),
          operationType: operationType,
          investmentType: investmentType,
          accountId: accountId,
        )) {
    emit(state.copyWith(suggestions: getSuggestions()));
  }

  List<String> getSuggestions() {
    List<String> suggestions;
    if (operationType == InvestmentOperationType.sell) {
      suggestions = accountData
          .getToolsForAccount(accountId)
          .where((tool) =>
              tool.type == investmentType && tool.ticker != null)
          .map<String>((tool) => '${tool.ticker} - ${tool.name}')
          .toList();
    } else {
      // For buy operations, return all available options for the investment type
      final List<String> validTickers;
      if (investmentType == ToolType.stocks) {
        validTickers = [
          'AAPL', 'TSLA', 'NVDA', 'GOOG', 'MSFT', 'AMZN', 'FB',
          'JPM', 'XOM', 'V', 'PG', 'KO', 'NFLX', 'DIS', 'BA',
          'GS', 'SBER', 'GAZP', 'LKOH', 'YNDX'
        ];
      } else if (investmentType == ToolType.bonds) {
        validTickers = ['GOV', 'CORP'];
      } else if (investmentType == ToolType.cryptocurrency) {
        validTickers = ['BTC', 'ETH', 'XRP', 'LTC'];
      } else {
        validTickers = [];
      }

      suggestions = accountData.allInvestmentOptions.entries
          .where((entry) => validTickers.contains(entry.key))
          .map((entry) => '${entry.key} - ${entry.value}')
          .toList();
    }
    suggestions.sort();
    return suggestions;
  }

  void tickerChanged(String ticker) {
    // Handle "TICKER - Name · курс VAL" format from suggestions
    String upper;
    String? name;
    if (ticker.contains(' - ')) {
      final List<String> parts = ticker.split(' - ');
      upper = parts[0].toUpperCase();
      name = parts.length > 1 ? parts[1].split(' · ').first.trim() : null;
    } else {
      upper = ticker.toUpperCase();
      name = accountData.allInvestmentOptions[upper];
    }
    // Refresh suggestions when ticker is cleared
    final suggestions = ticker.isEmpty ? getSuggestions() : state.suggestions;
    emit(state.copyWith(
      selectedTicker: upper,
      selectedName: name != null && name.isNotEmpty ? name : null,
      suggestions: suggestions,
    ));
    // Курс из внешнего источника подставляется в цену.
    final double? rate = state.onlineRates[upper];
    if (rate != null && rate > 0) {
      priceChanged(rate.toStringAsFixed(2));
    }
    // При продаже подставляем полное количество тула.
    if (operationType == InvestmentOperationType.sell) {
      final Iterable<ToolSummary> matches = accountData
          .getToolsForAccount(accountId)
          .where(
            (ToolSummary t) =>
                t.type == investmentType &&
                (t.ticker ?? '').toUpperCase() == upper,
          );
      if (matches.isNotEmpty) {
        quantityChanged(_trimQuantity(matches.first.quantity));
      }
    }
    if (ticker.contains(' - ')) {
      // Выбрана подсказка: курс мог ещё не успеть загрузиться —
      // запрашиваем сразу и дозаполняем цену по приходу.
      unawaited(_loadOnlineSuggestions(upper));
    } else {
      _scheduleOnlineSearch(upper);
    }
  }

  /// Поиск подсказок во внешнем источнике с дебаунсом (только крипта).
  void _scheduleOnlineSearch(String query) {
    if (investmentType != ToolType.cryptocurrency ||
        operationType != InvestmentOperationType.buy ||
        query.length < 2) {
      return;
    }
    _searchDebounce?.cancel();
    _searchQuery = query;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadOnlineSuggestions(_searchQuery ?? query);
    });
  }

  /// Внешний источник + тула из БД; дубли убираются, побеждает внешний.
  /// Имена показываются сразу после поиска, цены догружаются следом.
  Future<void> _loadOnlineSuggestions(String query) async {
    final String vs = await _defaultCurrency();
    final String key = query.toLowerCase();
    List<OnlineInstrument> online =
        _onlineCache[key] ?? await _cryptoSource.search(query);
    _onlineCache[key] = online;
    if (online.isEmpty) {
      emit(state.copyWith(suggestions: getSuggestions()));
      return;
    }

    // 1) Быстрый показ имён без курсов.
    _emitMerged(online, <String, double>{}, vs);

    // 2) Догрузка цен (для закэшированных не повторяется).
    if (online.any((OnlineInstrument i) => i.rate == null)) {
      final Map<String, double> rates = await _cryptoSource.fetchRates(
        online,
        vs,
      );
      for (final OnlineInstrument i in online) {
        final double? r = rates[i.id];
        if (r != null) {
          i.rate = r;
        }
      }
      _emitMerged(online, rates, vs);
    } else {
      _emitMerged(
        online,
        <String, double>{
          for (final OnlineInstrument i in online)
            if (i.rate != null) i.id: i.rate!,
        },
        vs,
      );
    }
  }

  Future<String> _defaultCurrency() async {
    _vsCurrencyCache ??= await SettingsRepository().getDefaultCurrency();
    return _vsCurrencyCache!;
  }

  /// Слияние внешних подсказок с тулами из БД и обновление состояния.
  void _emitMerged(
    List<OnlineInstrument> online,
    Map<String, double> freshRates,
    String vs,
  ) {
    final Map<String, double> rates = <String, double>{
      for (final OnlineInstrument i in online)
        if (i.rate != null && i.rate! > 0) i.ticker.toUpperCase(): i.rate!,
    };
    final Set<String> onlineTickers = online
        .map((OnlineInstrument i) => i.ticker.toUpperCase())
        .toSet();
    // Единый формат «ТИКЕР - Название · курс»: тулам из БД курс —
    // текущая цена инструмента (стоимость / количество).
    final List<String> dbEntries = getSuggestions()
        .where((String entry) {
          final String entryTicker = entry.split(' - ').first.toUpperCase();
          return !onlineTickers.contains(entryTicker);
        })
        .map<String>((String entry) {
          final int sep = entry.indexOf(' - ');
          if (sep < 0) return entry;
          final String ticker = entry.substring(0, sep).toUpperCase();
          final String name = entry.substring(sep + 3);
          final double? rate = _impliedRate(ticker);
          final String rateSuffix =
              (rate != null && rate > 0) ? ' · ${_fmtRate(rate)} $vs' : '';
          return '$ticker - $name$rateSuffix';
        })
        .toList();
    final List<String> merged = <String>[
      ...online.map((OnlineInstrument i) {
        final double r = i.rate ?? freshRates[i.id] ?? 0;
        final String rateSuffix = r > 0 ? ' · ${_fmtRate(r)} $vs' : '';
        return '${i.ticker} - ${i.name}$rateSuffix';
      }),
      ...dbEntries,
    ];
    emit(state.copyWith(suggestions: merged, onlineRates: rates));
    // Дозаполнение цены выбранным курсом, если она ещё пуста.
    final String? selected = state.selectedTicker;
    final double? selectedRate = selected != null ? rates[selected] : null;
    if (selectedRate != null && selectedRate > 0 && state.price == null) {
      priceChanged(_fmtRate(selectedRate));
    }
  }

  /// Количество без хвостовых нулей (до 10 знаков).
  String _trimQuantity(double v) {
    String s = v.toStringAsFixed(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  /// Текущая цена единицы инструмента из БД (стоимость / количество).
  double? _impliedRate(String ticker) {
    for (final ToolSummary t in accountData.getToolsForAccount(accountId)) {
      if (t.type == investmentType &&
          (t.ticker ?? '').toUpperCase() == ticker &&
          t.quantity > 0) {
        return t.currentValue / t.quantity;
      }
    }
    return null;
  }

  String _fmtRate(double v) {
    String s = v.toStringAsFixed(2);
    if (v >= 1000) {
      s = v.round().toString();
    }
    return s;
  }

  void nameChanged(String name) {
    emit(state.copyWith(selectedName: name));
  }

  void quantityChanged(String value) {
    final q = double.tryParse(value);
    emit(state.copyWith(quantity: q));
  }

  void priceChanged(String value) {
    final p = double.tryParse(value);
    emit(state.copyWith(price: p));
  }

  void commissionChanged(String value) {
    final c = value.trim().isEmpty ? 0.0 : double.tryParse(value);
    emit(state.copyWith(commission: c));
  }

  void faceValueChanged(String value) {
    final f = double.tryParse(value);
    emit(state.copyWith(faceValue: f));
  }

  void accruedCouponIncomeChanged(String value) {
    final a = double.tryParse(value);
    emit(state.copyWith(accruedCouponIncome: a));
  }

  void dateSelected(DateTime date) {
    emit(state.copyWith(selectedDate: date));
  }

  ToolSummary? _getDefaultMoneyToolForAccount() {
    final List<ToolSummary> moneyTools = accountData.getMoneyToolsForAccount(accountId);
    final ToolSummary? rurTool = moneyTools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) => tool != null && tool.ticker == 'RUB',
      orElse: () => null,
    );
    if (rurTool != null) {
      return rurTool;
    }
    return moneyTools.isNotEmpty ? moneyTools.first : null;
  }

  Future<void> submit() async {
    emit(state.copyWith(formStatus: InvestmentFormStatus.loading));

    final ticker = state.selectedTicker ?? '';
    final name = state.selectedName ?? '';
    final quantity = state.quantity;
    final price = state.price;
    final commission = state.commission ?? 0.0;
    final faceValue = state.faceValue;
    final accruedCouponIncome = state.accruedCouponIncome;
    final date = state.selectedDate;

    if (ticker.isEmpty || name.isEmpty || quantity == null || price == null || quantity <= 0 || price <= 0) {
      emit(state.copyWith(
        formStatus: InvestmentFormStatus.failure,
        errorMessage: 'Пожалуйста, заполните все обязательные поля корректно',
      ));
      return;
    }

    try {
      if (operationType == InvestmentOperationType.buy) {
        await _handleBuy(ticker, name, quantity, price, commission, faceValue, accruedCouponIncome, date);
      } else {
        await _handleSell(ticker, name, quantity, price, commission, accruedCouponIncome, date);
      }

      emit(state.copyWith(formStatus: InvestmentFormStatus.success));
    } catch (e) {
      emit(state.copyWith(
        formStatus: InvestmentFormStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<String> _handleBuy(
    String ticker,
    String name,
    double quantity,
    double price,
    double commission,
    double? faceValue,
    double? accruedCouponIncome,
    DateTime date,
  ) async {
    final moneyTool = _getDefaultMoneyToolForAccount();
    if (moneyTool == null) {
      throw Exception('No money tool found for account $accountId');
    }

    final instrumentCost = quantity * price;

    // Add Activity record for money tool change (money out)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: moneyTool.id,
        type: ActivityType.substract,
        createAt: date,
        quantity: instrumentCost,
        price: 1,
        currency: Currency.RUB,
        isTransmit: false,
        name: 'Buy $name (money out)',
      ),
    );

    // Add separate Activity record for commission
    if (commission > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: date,
          quantity: commission,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'Commission for $name',
        ),
      );
    }

    // Add Activity record for НКД (accrued coupon) when buying bonds
    if (investmentType == ToolType.bonds && accruedCouponIncome != null && accruedCouponIncome > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: date,
          quantity: accruedCouponIncome,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'НКД for $name (buy)',
        ),
      );
    }

    ToolSummary? existingTool = accountData.getToolByTickerAndAccountId(ticker, accountId);
    // Verify type matches (getToolByTickerAndAccountId doesn't check type)
    if (existingTool != null && existingTool.type != investmentType) {
      existingTool = null;
    }
    debugPrint('[InvestmentCubit] _handleBuy: looking for ticker=$ticker, accountId=$accountId, type=$investmentType, found=${existingTool?.id}');

    if (existingTool != null) {
      // Create activity to increase the instrument position
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: existingTool.id,
          type: ActivityType.add,
          createAt: date,
          quantity: quantity,
          price: price,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'Buy $name',
        ),
      );
      return existingTool.id;
    } else {
      final String newToolId = Uuid().v7();
      await ToolRepository().insert(Tool(
        id: newToolId,
        name: name,
        accountId: accountId,
        type: investmentType.name,
        ticker: ticker,
      ));
      // Create activity to set the initial position
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: newToolId,
          type: ActivityType.add,
          createAt: date,
          quantity: quantity,
          price: price,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'Buy $name',
        ),
      );
      return newToolId;
    }
  }

  Future<String> _handleSell(
    String ticker,
    String name,
    double quantity,
    double price,
    double commission,
    double? accruedCouponIncome,
    DateTime date,
  ) async {
    final moneyTool = _getDefaultMoneyToolForAccount();
    if (moneyTool == null) {
      throw Exception('No money tool found for account $accountId');
    }

    ToolSummary? existingTool = accountData.getToolByTickerAndAccountId(ticker, accountId);
    // Verify type matches
    if (existingTool != null && existingTool.type != investmentType) {
      existingTool = null;
    }
    debugPrint('[InvestmentCubit] _handleSell: looking for ticker=$ticker, accountId=$accountId, type=$investmentType, found=${existingTool?.id}');

    if (existingTool == null || existingTool.quantity < quantity) {
      throw Exception('Insufficient quantity of $ticker to sell');
    }

    // Add Activity record for money tool change (money in from sale)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: moneyTool.id,
        type: ActivityType.add,
        createAt: date,
        quantity: quantity * price,
        price: 1,
        currency: Currency.RUB,
        isTransmit: false,
        name: 'Sell $name (money in)',
      ),
    );

    // Add Activity record for НКД (accrued coupon) when selling bonds
    if (investmentType == ToolType.bonds && accruedCouponIncome != null && accruedCouponIncome > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.add,
          createAt: date,
          quantity: accruedCouponIncome,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'НКД for $name (sell)',
        ),
      );
    }

    // Add separate Activity record for commission
    if (commission > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: date,
          quantity: commission,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'Commission for $name',
        ),
      );
    }

    // Create activity to reduce the instrument position
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: existingTool.id,
        type: ActivityType.substract,
        createAt: date,
        quantity: quantity,
        price: price,
        currency: Currency.RUB,
        isTransmit: false,
        name: 'Sell $name',
      ),
    );

    // If selling all, mark tool for deletion after activity replay
    if (existingTool.quantity - quantity <= 0) {
      await ToolRepository().delete(existingTool.id);
    }

    return existingTool.id;
  }
}
