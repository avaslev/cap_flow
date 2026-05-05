import 'package:bloc/bloc.dart';
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
        ));

  List<String> getSuggestions() {
    List<String> suggestions;
    if (operationType == InvestmentOperationType.sell) {
      suggestions = accountData
          .getToolsForAccount(accountId)
          .where((tool) =>
              tool.type == investmentType && tool.ticker != null)
          .map<String>((tool) => tool.ticker!)
          .toList();
    } else {
      suggestions = accountData.allInvestmentOptions.keys
          .where((String ticker) {
        if (investmentType == ToolType.stocks) {
          return [
            'AAPL',
            'TSLA',
            'NVDA',
            'GOOG',
            'MSFT',
            'AMZN',
            'FB',
            'JPM',
            'XOM',
            'V',
            'PG',
            'KO',
            'NFLX',
            'DIS',
            'BA',
            'GS',
            'SBER',
            'GAZP',
            'LKOH',
            'YNDX'
          ].contains(ticker);
        } else if (investmentType == ToolType.bonds) {
          return ['GOV', 'CORP'].contains(ticker);
        } else if (investmentType == ToolType.cryptocurrency) {
          return ['BTC', 'ETH', 'XRP', 'LTC'].contains(ticker);
        }
        return false;
      })
          .toList();
    }
    suggestions.sort();
    return suggestions;
  }

  void tickerChanged(String ticker) {
    final upper = ticker.toUpperCase();
    final name = accountData.allInvestmentOptions[upper] ?? '';
    emit(state.copyWith(selectedTicker: upper, selectedName: name.isNotEmpty ? name : null));
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

  double _getMoneyToolUnitPrice(ToolSummary moneyTool) {
    if (moneyTool.quantity > 0) {
      return moneyTool.currentValue / moneyTool.quantity;
    }
    return moneyTool.ticker == 'USD' ? 90.0 : 1.0;
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
      final String targetToolId;
      if (operationType == InvestmentOperationType.buy) {
        targetToolId = await _handleBuy(ticker, name, quantity, price, commission, faceValue, accruedCouponIncome, date);
      } else {
        targetToolId = await _handleSell(ticker, name, quantity, price, commission, accruedCouponIncome, date);
      }

      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: targetToolId,
          type: operationType == InvestmentOperationType.buy ? ActivityType.add : ActivityType.substract,
          createAt: date,
          quantity: quantity * price + commission,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: '${operationType == InvestmentOperationType.buy ? "Buy" : "Sell"} $name',
        ),
      );

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

    final totalCost = investmentType == ToolType.bonds
        ? (quantity * price) + (accruedCouponIncome ?? 0.0) + commission
        : (quantity * price) + commission;

    final moneyToolUnitPrice = _getMoneyToolUnitPrice(moneyTool);
    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    }

    // Add Activity record for money tool change (money out)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: moneyTool.id,
        type: ActivityType.substract,
        createAt: date,
        quantity: totalCost,
        price: 1,
        currency: Currency.RUB,
        isTransmit: false,
        name: 'Buy $name (money out)',
      ),
    );

    ToolSummary? existingTool = accountData.tools.values.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == investmentType,
      orElse: () => null,
    );

    if (existingTool != null) {
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * price);
      return existingTool.id;
    } else {
      final String newToolId = Uuid().v7();
      final newTool = ToolSummary(
        id: newToolId,
        name: name,
        quantity: quantity,
        percentageChange: 0.0,
        accountId: accountId,
        type: investmentType,
        currentValue: quantity * price,
        ticker: ticker,
        faceValue: investmentType == ToolType.bonds ? faceValue : null,
      );
      accountData.addTool(newTool);
      await ToolRepository().insert(Tool(
        id: newToolId,
        name: name,
        accountId: accountId,
        type: investmentType.name,
        ticker: ticker,
      ));
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

    ToolSummary? existingTool = accountData.tools.values.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == investmentType,
      orElse: () => null,
    );

    if (existingTool == null || existingTool.quantity < quantity) {
      throw Exception('Insufficient quantity of $ticker to sell');
    }

    final totalProceeds = investmentType == ToolType.bonds
        ? (quantity * price) + (accruedCouponIncome ?? 0.0) - commission
        : (quantity * price) - commission;

    final moneyToolUnitPrice = _getMoneyToolUnitPrice(moneyTool);
    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    }

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

    if (existingTool.quantity <= 0) {
      accountData.tools.remove(existingTool.id);
      await ToolRepository().delete(existingTool.id);
    }

    return existingTool.id;
  }
}
