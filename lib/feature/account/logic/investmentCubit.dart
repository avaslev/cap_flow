import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
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
    // Handle "TICKER - Name" format from suggestions
    String upper;
    String? name;
    if (ticker.contains(' - ')) {
      final parts = ticker.split(' - ');
      upper = parts[0].toUpperCase();
      name = parts.length > 1 ? parts[1] : null;
    } else {
      upper = ticker.toUpperCase();
      name = accountData.allInvestmentOptions[upper];
    }
    // Refresh suggestions when ticker is cleared
    final suggestions = ticker.isEmpty ? getSuggestions() : state.suggestions;
    emit(state.copyWith(
      selectedTicker: upper,
      selectedName: name ?? (name?.isNotEmpty == true ? name : null),
      suggestions: suggestions,
    ));
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
        quantity: instrumentCost + commission,
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

    final totalProceeds = investmentType == ToolType.bonds
        ? (quantity * price) + (accruedCouponIncome ?? 0.0) - commission
        : (quantity * price) - commission;

    // Add Activity record for money tool change (money in)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: moneyTool.id,
        type: ActivityType.add,
        createAt: date,
        quantity: totalProceeds,
        price: 1,
        currency: Currency.RUB,
        isTransmit: false,
        name: 'Sell $name (money in)',
      ),
    );

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
