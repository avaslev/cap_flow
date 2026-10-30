import 'package:flutter/material.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/models/tools/typed_tool.dart';
import 'package:capflow/feature/tools/domain/tool_valuation.dart';

export 'package:capflow/data/models/tools/tool_kind.dart';

/// Enum for different types of financial accounts.
enum AccountType {
  general, // Represents checking, savings, general bank accounts
  brokerage, // Represents investment accounts (stocks, bonds)
  cryptocurrency, // Represents crypto wallets/exchanges
}

/// Data model for an account summary.
class AccountSummary {
  final String id;
  String name; // Made mutable to allow renaming the account
  double balance; // Made mutable to allow updates
  double dailyChangeAmount;
  double dailyChangePercentage;
  int colorValue; // Made mutable to allow changing the card color
  final AccountType type;
  bool hideEvents; // New attribute to hide events for this account
  bool
  excludeFromTotal; // New attribute to exclude from total balance calculation

  /// Turnover for the last 30 days (real money operations, internal moves
  /// excluded).
  double periodIncome; // >= 0
  double periodExpense; // <= 0

  /// Порядок сортировки (total всегда первым, sortOrder 0 у total).
  int sortOrder;

  /// Скрытый (архивный) счёт: не в списке и не в Total.
  bool isArchived;

  AccountSummary({
    this.id = '',
    required this.name,
    required this.balance,
    required this.dailyChangeAmount,
    required this.dailyChangePercentage,
    required this.colorValue,
    required this.type,
    this.hideEvents = false, // Default to not hiding events
    this.excludeFromTotal =
        false, // Default to including in total balance calculation
    this.periodIncome = 0.0,
    this.periodExpense = 0.0,
    this.sortOrder = 0,
    this.isArchived = false,
  });
}

/// Data model for a financial event/transaction.
class Event {
  final String eventId;
  final String eventType;
  final String name;
  final String description;
  final String category;
  final double amount;
  final String accountId; // To link events to specific accounts
  final String toolId; // To link events to specific accounts
  final String? depositToolId; // Credit tool for credit payment events
  final DateTime date; // Date of the event

  Event({
    required this.eventId,
    required this.eventType,
    required this.name,
    required this.description,
    required this.category,
    required this.amount,
    required this.accountId,
    required this.toolId,
    this.depositToolId,
    required this.date,
  });
}

/// Enum for investment operation type (buy or sell).
enum InvestmentOperationType { buy, sell }

/// Manages the state of account summaries, events, and tools.
class ToolSummary {
  String id;
  final String name;
  double quantity; // Made mutable for transfers/updates
  double percentageChange; // Daily change for most, annual yield for deposits
  final String accountId;
  final ToolType type;
  double currentValue; // Made mutable for transfers/updates
  final String? ticker; // Ticker symbol for some tools

  // Deposit specific fields, nullable for other tool types
  final DateTime? startDate;
  final DateTime? endDate;
  final PayoutType? payoutType;
  final String?
  withdrawalToolId; // ID of the money tool from which funds were taken

  // New Credit specific fields, nullable for other tool types
  final double? interestRate; // Annual interest rate for credit/loan
  final DateTime? loanStartDate; // Start date of the loan
  final int? loanTermMonths; // Term of the loan in months
  final int? paymentDayOfMonth; // Day of the month for credit payments
  final CreditPaymentType?
  creditPaymentType; // Type of payment for credit (annuity, differentiated)

  // New Bond specific fields
  final double? faceValue; // Nominal value of the bond

  // Lifecycle: closed tools keep history in the DB but are hidden from lists.
  final bool isClosed;

  ToolSummary({
    required this.id,
    required this.name,
    required this.quantity,
    required this.percentageChange,
    required this.accountId,
    required this.type,
    required this.currentValue,
    this.ticker,
    this.startDate,
    this.endDate,
    this.payoutType,
    this.withdrawalToolId,
    this.interestRate,
    this.loanStartDate,
    this.loanTermMonths,
    this.paymentDayOfMonth,
    this.creditPaymentType,
    this.faceValue, // Initialize faceValue
    this.isClosed = false,
  });

  /// Copies the mutable replayed fields. Metadata (dates, rates, payout
  /// types) is immutable here — edits go through the typed domain model.
  ToolSummary copyWith({
    double? quantity,
    double? currentValue,
    double? percentageChange,
  }) {
    return ToolSummary(
      id: id,
      name: name,
      quantity: quantity ?? this.quantity,
      percentageChange: percentageChange ?? this.percentageChange,
      accountId: accountId,
      type: type,
      currentValue: currentValue ?? this.currentValue,
      ticker: ticker,
      startDate: startDate,
      endDate: endDate,
      payoutType: payoutType,
      withdrawalToolId: withdrawalToolId,
      interestRate: interestRate,
      loanStartDate: loanStartDate,
      loanTermMonths: loanTermMonths,
      paymentDayOfMonth: paymentDayOfMonth,
      creditPaymentType: creditPaymentType,
      faceValue: faceValue,
      isClosed: isClosed,
    );
  }

  /// Builds a view-model summary from a typed domain tool. Replayed values
  /// (quantity/currentValue) are passed separately — they come from the
  /// activity replay, not from the DB row.
  factory ToolSummary.fromTyped(
    TypedTool tool, {
    double quantity = 0,
    double currentValue = 0,
    double percentageChange = 0,
  }) {
    return switch (tool) {
      DepositTool t => ToolSummary(
          id: t.id,
          name: t.name,
          quantity: quantity,
          percentageChange: percentageChange,
          accountId: t.accountId,
          type: t.kind,
          currentValue: currentValue,
          ticker: t.ticker,
          startDate: t.startDate,
          endDate: t.endDate,
          payoutType: t.payoutType,
          withdrawalToolId: t.withdrawalToolId,
          interestRate: t.interestRate,
          isClosed: t.isClosed,
        ),
      CreditTool t => ToolSummary(
          id: t.id,
          name: t.name,
          quantity: quantity,
          percentageChange: percentageChange,
          accountId: t.accountId,
          type: t.kind,
          currentValue: currentValue,
          ticker: t.ticker,
          interestRate: t.interestRate,
          loanStartDate: t.loanStartDate,
          loanTermMonths: t.termMonths,
          paymentDayOfMonth: t.paymentDayOfMonth,
          creditPaymentType: t.paymentType,
          isClosed: t.isClosed,
        ),
      SecurityTool t => ToolSummary(
          id: t.id,
          name: t.name,
          quantity: quantity,
          percentageChange: percentageChange,
          accountId: t.accountId,
          type: t.kind,
          currentValue: currentValue,
          ticker: t.ticker,
          faceValue: t.faceValue,
          isClosed: t.isClosed,
        ),
      OtherTool t => ToolSummary(
          id: t.id,
          name: t.name,
          quantity: quantity,
          percentageChange: percentageChange,
          accountId: t.accountId,
          type: t.kind,
          currentValue: currentValue,
          ticker: t.ticker,
          isClosed: t.isClosed,
        ),
      TypedTool t => ToolSummary(
          id: t.id,
          name: t.name,
          quantity: quantity,
          percentageChange: percentageChange,
          accountId: t.accountId,
          type: t.kind,
          currentValue: currentValue,
          ticker: t.ticker,
          isClosed: t.isClosed,
        ),
    };
  }
}

/// Manages the state of account summaries, events, and tools.
class AccountData {
  final List<AccountSummary> _accounts;
  final Map<String, Event> _events;
  final List<ToolSummary> _tools;
  String _activeAccountId;
  String? _deletableAccountId; // New state for delete mode
  String? _targetDisplayAccount;

  /// Dummy data for stock suggestions and names
  AccountData()
    : _accounts = <AccountSummary>[],
      _events = new Map<String, Event>(),
      _tools = <ToolSummary>[],
      _activeAccountId = 'total' {
    _accounts.insert(
      0,
      AccountSummary(
        id: 'total',
        name: 'Total Balance',
        balance: 0.0, // Will be updated immediately
        dailyChangeAmount: 0.0, // Will be updated
        dailyChangePercentage: 0.0, // Will be updated
        colorValue: 0xff6A0DAD, // Deep purple
        type: AccountType.general, // Default for total
        hideEvents: false, // Total account events are never hidden
        excludeFromTotal: false, // Total account is always included in itself
      ),
    );
    _updateTotalBalance(); // Initial calculation for 'total'
  }

  /// Returns an unmodifiable list of all account summaries, including 'total'.
  List<AccountSummary> get accounts =>
      List<AccountSummary>.unmodifiable(_accounts);

  /// Сортировка счетов: Total первым, остальные по sortOrder.
  /// После сортировки нормализует sortOrder (1..N по текущему порядку) —
  /// иначе перестановка 0↔0 у старых счетов ничего не меняет.
  void sortAccounts() {
    _accounts.sort((AccountSummary a, AccountSummary b) {
      if (a.id == 'total') return -1;
      if (b.id == 'total') return 1;
      final int cmp = a.sortOrder.compareTo(b.sortOrder);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    int next = 1;
    for (final AccountSummary acc in _accounts) {
      if (acc.id == 'total') continue;
      acc.sortOrder = next;
      next += 1;
    }
  }

  /// Returns an unmodifiable list of all account summaries, including 'total'.
  Map<String,ToolSummary> get tools =>
      {for (var item in _tools) item.id : item};

  /// Signed value of a tool for account/total aggregation, per kind.
  ///
  /// - money/securities/other: replayed value as-is;
  /// - deposit: replayed principal plus interest accrued by day (only when
  ///   the start date is known, otherwise the replayed value);
  /// - credit: stored as a negative liability, subtracted from the balance
  ///   naturally by the sum.
  double _toolAccountValue(ToolSummary tool) {
    if (tool.type == ToolType.deposit && tool.startDate != null) {
      return depositValue(
        principal: tool.currentValue,
        annualRate: tool.interestRate ?? 0,
        startDate: tool.startDate!,
        endDate: tool.endDate,
        asOf: DateTime.now(),
      );
    }
    return tool.currentValue;
  }

  /// Calculates and updates the balance, daily change amount, and daily change percentage for the 'total' account.
  void _updateTotalBalance() {
    double totalBalance = 0.0;
    double totalDailyChangeAmount = 0.0;
    double totalTodayIncome = 0.0;
    double totalTodayExpense = 0.0;

    for (final AccountSummary acc in _accounts) {
      if (acc.id == 'total') continue;
      // Баланс пересчитывается для всех счетов; excludeFromTotal исключает
      // его только из Total — на карточке счёта сумма остаётся видна.
      final double accountToolsBalance = _tools
          .where((ToolSummary tool) => tool.accountId == acc.id)
          .fold(
            0.0,
            (double sum, ToolSummary tool) => sum + _toolAccountValue(tool),
          );

      // Update account's balance to reflect sum of its tools
      if (acc.balance != accountToolsBalance) {
        acc.balance = accountToolsBalance;
      }

      if (!acc.excludeFromTotal) {
        totalBalance += acc.balance;
        totalDailyChangeAmount += acc.dailyChangeAmount;
        totalTodayIncome += acc.periodIncome;
        totalTodayExpense += acc.periodExpense;
      }
    }

    final AccountSummary totalAccount2 = _accounts.firstWhere(
      (AccountSummary acc) => acc.id == 'total',
    );
    totalAccount2.periodIncome = totalTodayIncome;
    totalAccount2.periodExpense = totalTodayExpense;

    final AccountSummary totalAccount = _accounts.firstWhere(
      (AccountSummary acc) => acc.id == 'total',
    );

    if (totalAccount.balance != totalBalance) {
      totalAccount.balance = totalBalance;
    }

    if (totalAccount.dailyChangeAmount != totalDailyChangeAmount) {
      totalAccount.dailyChangeAmount = totalDailyChangeAmount;
    }

    double totalDailyChangePercentage = 0.0;
    final double previousTotalBalance = totalBalance - totalDailyChangeAmount;

    if (previousTotalBalance != 0 && previousTotalBalance.abs() > 0.001) {
      // Avoid division by very small numbers close to zero
      totalDailyChangePercentage =
          (totalDailyChangeAmount / previousTotalBalance) * 100;
    } else if (totalDailyChangeAmount != 0) {
      // If previous balance is zero but change exists, represent as a large percentage
      totalDailyChangePercentage =
          totalDailyChangeAmount > 0
              ? double.infinity
              : double.negativeInfinity;
    }

    if (totalAccount.dailyChangePercentage != totalDailyChangePercentage) {
      totalAccount.dailyChangePercentage = totalDailyChangePercentage;
    }
  }

  /// Returns all events across all accounts, sorted by date (oldest first).
  /// Events from accounts with hideEvents flag set to true are excluded.
  List<Event> get allEvents {
    final List<Event> filteredEvents =
      _events.values.where((Event event) {
        final AccountSummary? account = getAccountById(event.accountId);
        return account != null && !account.hideEvents;
      }).toList();
    final List<Event> sortedEvents = List<Event>.from(filteredEvents)..sort(
      (Event a, Event b) => a.date.compareTo(b.date),
    ); // Changed to oldest first

    return List<Event>.unmodifiable(sortedEvents);
  }

  /// Returns tools associated with a specific account, sorted by type and then name.
List<ToolSummary> getToolsForAccount(String accountId) {
  final List<ToolSummary> filtered = _tools
      .where((ToolSummary tool) => tool.accountId == accountId)
      // Инвестиционные тула с нулевым количеством (полностью проданные)
      // скрываются из списков, но остаются в базе.
      .where(
        (ToolSummary tool) =>
            tool.type == ToolType.money ||
            tool.type == ToolType.deposit ||
            tool.type == ToolType.credit ||
            tool.quantity > 0,
      )
      .toList();
  filtered.sort((ToolSummary a, ToolSummary b) {
    final int typeComparison = a.type.index.compareTo(b.type.index);
    if (typeComparison != 0) return typeComparison;
    return a.name.compareTo(b.name);
  });
  
  return filtered;
}

  /// Returns only OPEN money tools associated with a specific account
  /// (closed tools are hidden from all pickers and lists).
  List<ToolSummary> getMoneyToolsForAccount(String accountId) {
    return _tools
        .where(
          (ToolSummary tool) =>
              tool.accountId == accountId &&
              tool.type == ToolType.money &&
              !tool.isClosed,
        )
        .toList();
  }

  /// Returns all money tools from all accounts.
  List<ToolSummary> get allMoneyTools {
    return _tools
        .where((ToolSummary tool) => tool.type == ToolType.money)
        .toList();
  }

  /// Returns a [Tool] by its name and accountId, or null if not found.
  ToolSummary? getToolByNameAndAccountId(String toolName, String accountId) {
    try {
      return _tools.firstWhere(
        (ToolSummary tool) =>
            tool.name == toolName && tool.accountId == accountId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Returns a [Tool] by its ticker and accountId, or null if not found.
  ToolSummary? getToolByTickerAndAccountId(String ticker, String accountId) {
    try {
      return _tools.firstWhere(
        (ToolSummary tool) =>
            tool.ticker == ticker && tool.accountId == accountId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Returns an [AccountSummary] by its ID, or null if not found.
  AccountSummary? getAccountById(String id) {
    for (final AccountSummary account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  String? get targetDisplayAccount => _targetDisplayAccount;
  void setTargetDisplayAccount(String? id) {
    _targetDisplayAccount = id;
  }

  /// Counts of open tools per kind for an account ('total' → all accounts).
  Map<ToolType, int> toolCountsFor(String accountId) {
    final Map<ToolType, int> counts = <ToolType, int>{};
    for (final ToolSummary tool in _tools) {
      if (tool.isClosed) continue;
      if (accountId != 'total' && tool.accountId != accountId) continue;
      counts[tool.type] = (counts[tool.type] ?? 0) + 1;
    }
    return counts;
  }

  /// Nearest upcoming event for an account ('total' → across all accounts).
  Event? nearestEventFor(String accountId) {
    Event? nearest;
    final DateTime now = DateTime.now();
    for (final Event event in _events.values) {
      if (accountId != 'total' && event.accountId != accountId) continue;
      if (event.date.isBefore(DateTime(now.year, now.month, now.day))) continue;
      if (nearest == null || event.date.isBefore(nearest.date)) {
        nearest = event;
      }
    }
    return nearest;
  }

  /// Returns the ID of the currently active account.
  String get activeAccountId => _activeAccountId;

  /// Sets the active account by its ID.
  void setActiveAccount(String id) {
    if (_activeAccountId != id) {
      _activeAccountId = id;
      _deletableAccountId =
          null; // Clear deletable mode when changing active account
    }
  }

  /// Returns the ID of the account currently in deletable mode.
  String? get deletableAccountId => _deletableAccountId;

  /// Sets the account ID to be marked for deletion.
  void setDeletableAccount(String? id) {
    if (_deletableAccountId != id) {
      _deletableAccountId = id;
    }
  }

  /// Clears the deletable account mode.
  void clearDeletableAccount() {
    if (_deletableAccountId != null) {
      _deletableAccountId = null;
    }
  }

  /// Checks if a given account is currently marked for deletion.
  bool isAccountDeletable(String id) {
    return _deletableAccountId == id;
  }

  /// Adds a new financial event (income or expense) and updates the account balance.
  void addEvent(
    String eventId,
    String eventType,
    String name,
    String description,
    String category,
    String accountId,
    String toolId,
    double amount,
    DateTime date, {
    String? depositToolId,
  }) {

    final event = Event(
          eventId: eventId,
          eventType: eventType,
          name: name,
          description: description,
          category: category,
          amount: amount,
          accountId: accountId,
          toolId: toolId,
          depositToolId: depositToolId,
          date: date,
        );

    _events.update(eventId, (oldEvent) => event, ifAbsent: () => event);
  }

  void clearEvents() {
    _events.removeWhere((key, value) => true);
  }


  /// Performs a transfer between two money tools, potentially across different accounts, and updates their balances.
  void makeToolTransfer({
    required String fromToolName,
    required String fromAccountId,
    required String toToolName,
    required String toAccountId,
    required double amount, // This is the amount in RUB equivalent
    required DateTime date,
    double commission = 0.0, // Optional commission
  }) {
    final ToolSummary? fromTool = getToolByNameAndAccountId(
      fromToolName,
      fromAccountId,
    );
    final ToolSummary? toTool = getToolByNameAndAccountId(
      toToolName,
      toAccountId,
    );

    if (fromTool == null) {
      debugPrint(
        'Source money tool "$fromToolName" not found in account "$fromAccountId".',
      );
      return;
    }
    if (toTool == null) {
      debugPrint(
        'Destination money tool "$toToolName" not found in account "$toAccountId".',
      );
      return;
    }
    if (fromTool.type != ToolType.money || toTool.type != ToolType.money) {
      debugPrint('Only money tools can be used for direct transfers.');
      return;
    }

    final AccountSummary? fromAccount = getAccountById(fromAccountId);
    final AccountSummary? toAccount = getAccountById(toAccountId);

    if (fromAccount == null) {
      debugPrint('Source account "$fromAccountId" not found.');
      return;
    }
    if (toAccount == null) {
      debugPrint('Destination account "$toAccountId" not found.');
      return;
    }
    if (fromAccount.id == 'total' || toAccount.id == 'total') {
      debugPrint('Cannot transfer from/to "Total Balance" account directly.');
      return;
    }

    // Calculate effective unit price for source and destination tools
    double fromToolUnitPrice =
        fromTool.quantity > 0
            ? fromTool.currentValue / fromTool.quantity
            : (fromTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    double toToolUnitPrice =
        toTool.quantity > 0
            ? toTool.currentValue / toTool.quantity
            : (toTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    // Check for sufficient funds in the source tool (in RUB equivalent)
    if (fromTool.currentValue < (amount + commission)) {
      debugPrint(
        'Insufficient funds in ${fromTool.name} (${fromAccount.name}) for this transfer.',
      );
      // Allowing to go negative for demonstration, in a real app this would trigger an an error message
    }

    // Immutable update: replace summaries instead of mutating fields.
    final int fromIndex = _tools.indexOf(fromTool);
    _tools[fromIndex] = fromTool.copyWith(
      currentValue: fromTool.currentValue - (amount + commission),
      quantity: fromToolUnitPrice > 0
          ? fromTool.quantity - (amount + commission) / fromToolUnitPrice
          : fromTool.quantity,
    );

    final int toIndex = _tools.indexOf(toTool);
    _tools[toIndex] = toTool.copyWith(
      currentValue: toTool.currentValue + amount,
      quantity: toToolUnitPrice > 0
          ? toTool.quantity + amount / toToolUnitPrice
          : toTool.quantity,
    );

    // Account balances are updated by _updateTotalBalance.
    _updateTotalBalance();
  }

  /// Deletes an account and associated events/tools.
  void deleteAccount(String accountId) {
    if (accountId == 'total') {
      debugPrint('Cannot delete "Total Balance" account.');
      return;
    }

    final int accountPage = _accounts.indexWhere(
      (AccountSummary acc) => acc.id == accountId,
    );
    _accounts.removeWhere((AccountSummary acc) => acc.id == accountId);
    _events.removeWhere((String key,  event) => event.accountId == accountId);
    _tools.removeWhere((ToolSummary tool) => tool.accountId == accountId);

    if (_activeAccountId == accountId) {
      _activeAccountId =
          _accounts[accountPage - 1].id; // Reset active account if deleted
    }
    _deletableAccountId = null; // Exit delete mode
    _updateTotalBalance(); // Recalculate total balance
  }

  /// Помечает счёт архивным и убирает из активного списка (Total пересчитается).
  /// Данные счёта (тулы/операции) сохраняются — восстановимо.
  void archiveAccount(String accountId) {
    if (accountId == 'total') {
      debugPrint('Cannot archive "Total Balance" account.');
      return;
    }
    final int accountPage = _accounts.indexWhere(
      (AccountSummary acc) => acc.id == accountId,
    );
    if (accountPage < 0) return;
    _accounts.removeAt(accountPage);
    if (_activeAccountId == accountId && _accounts.isNotEmpty) {
      _activeAccountId = _accounts[accountPage - 1].id;
    }
    _deletableAccountId = null;
    _updateTotalBalance();
  }

  /// Adds a new account.
  void addAccount(AccountSummary newAccount) {
    _accounts.isNotEmpty
      ? _accounts.removeWhere((item) => item.id == newAccount.id)
      : null;
    _accounts.add(newAccount);

    _updateTotalBalance(); // Recalculates total and notifies listeners
    // Notify for accounts list change
  }

  /// Обновляет отображаемые настройки счёта и пересчитывает Total.
  void updateAccountDetails(
    String accountId, {
    required String name,
    required int colorValue,
    required bool hideEvents,
    required bool excludeFromTotal,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || accountId == 'total') return;
    account.name = name;
    account.colorValue = colorValue;
    account.hideEvents = hideEvents;
    account.excludeFromTotal = excludeFromTotal;
    _updateTotalBalance();
  }

  /// Removes a tool by id from the in-memory list.
  /// Returns true when the tool was found and removed.
  bool removeTool(String id) {
    final int initialLength = _tools.length;
    _tools.removeWhere((ToolSummary tool) => tool.id == id);
    return _tools.length != initialLength;
  }

  /// Adds a tool.
  void addTool(ToolSummary newTool) {
    _tools.isNotEmpty
        ? _tools.removeWhere((tool) => tool.id == newTool.id)
        : null;
    _tools.add(newTool);

    final AccountSummary account = _accounts.firstWhere(
      (AccountSummary acc) => acc.id == 'total',
    );

    account.balance = _tools
        .where((ToolSummary tool) => tool.accountId == newTool.accountId)
        .fold(0.0, (double sum, ToolSummary tool) => sum + tool.currentValue);
    _updateTotalBalance();
  }

  /// Adds a new account.
  void addAccounts(List<AccountSummary> newAccounts) {
    _accounts.addAll(newAccounts);

    _updateTotalBalance(); // Recalculates total and notifies listeners
  }

  /// Добавляет money-тул в выбранной валюте.
  ///
  /// - [quantity] — сумма в валюте тула;
  /// - [rate] — курс валюты к RUB (стоимость единицы в рублях);
  /// - RUB-эквивалент = quantity × rate — попадает в баланс и Total;
  /// - [withdrawalToolName] — если указан, RUB-эквивалент списывается
  ///   с этого money-тула (внутренний обмен, isTransmit).
  void addMoneyTool({
    required String accountId,
    required String name,
    required String toolId,
    required String currencyTicker,
    required double quantity,
    required double rate,
    String? withdrawalToolName,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add money tool to "Total Balance" or non-existent account.',
      );
      return;
    }

    ToolSummary? withdrawalTool;
    if (withdrawalToolName != null) {
      withdrawalTool = _tools.cast<ToolSummary?>().firstWhere(
        (ToolSummary? tool) =>
            tool != null &&
            tool.accountId == accountId &&
            tool.type == ToolType.money &&
            tool.name == withdrawalToolName,
        orElse: () => null,
      );
      if (withdrawalTool == null) {
        debugPrint(
          'Withdrawal money tool "$withdrawalToolName" not found in account "$accountId".',
        );
        return;
      }
    }

    final double rubEquivalent = quantity * rate;

    // Списание RUB-эквивалента с money-тула-источника (внутренний обмен).
    if (withdrawalTool != null) {
      if (withdrawalTool.currentValue < rubEquivalent) {
        debugPrint(
          'Insufficient funds in ${withdrawalTool.name} for this exchange.',
        );
      }
      final double sourceUnitPrice = withdrawalTool.quantity > 0
          ? (withdrawalTool.currentValue / withdrawalTool.quantity)
          : 1.0;
      withdrawalTool.currentValue -= rubEquivalent;
      if (sourceUnitPrice > 0) {
        withdrawalTool.quantity -= (rubEquivalent / sourceUnitPrice);
      }
    }

    // Новый money-тул: quantity в валюте, currentValue = RUB-эквивалент.
    _tools.add(
      ToolSummary(
        id: toolId,
        name: name,
        quantity: quantity,
        percentageChange: 0.0,
        accountId: accountId,
        type: ToolType.money,
        currentValue: rubEquivalent,
        ticker: currencyTicker,
      ),
    );

    _updateTotalBalance();
  }

  /// Adds a new deposit tool to a specified account.
  /// Deducts the principal from a specified money tool within the same account.
  void addDeposit({
    required String accountId,
    required String name,
    required String toolId, // must match the DB row id to survive refreshes
    required double quantity, // Principal amount
    required double annualYield, // Percentage
    required DateTime startDate,
    DateTime? endDate, // null → бессрочный депозит
    required PayoutType payoutType,
    required String withdrawalToolName, // Name of the money tool to deduct from
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add deposit to "Total Balance" or non-existent account.',
      );
      return;
    }

    final ToolSummary? withdrawalTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.accountId == accountId &&
          tool.type == ToolType.money &&
          tool.name == withdrawalToolName,
      orElse: () => null,
    );

    if (withdrawalTool == null) {
      debugPrint(
        'Withdrawal money tool "$withdrawalToolName" not found in account "$accountId".',
      );
      return;
    }

    if (withdrawalTool.quantity < quantity) {
      debugPrint(
        'Insufficient funds in ${withdrawalTool.name} to create deposit.',
      );
      return;
    }

    // Deduct quantity and value from the withdrawal money tool
    // Assuming quantity for money tools aligns with actual units
    final double withdrawalValue =
        quantity * (withdrawalTool.currentValue / withdrawalTool.quantity);
    withdrawalTool.quantity -= quantity;
    withdrawalTool.currentValue -= withdrawalValue;

    // Add the new deposit tool
    _tools.add(
      ToolSummary(
        id: toolId,
        name: name,
        quantity: quantity, // Principal amount of deposit
        percentageChange: annualYield, // Annual yield for the deposit
        accountId: accountId,
        type: ToolType.deposit,
        currentValue: quantity, // Initial value is the principal
        startDate: startDate,
        endDate: endDate,
        payoutType: payoutType,
        withdrawalToolId: withdrawalTool.name, // Use name as ID for simplicity
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Adds a new credit tool to a specified account.
  /// Transfers the credit amount to a specified money tool within the same account.
  void addCredit({
    required String accountId,
    required String name,
    required double amount, // Loan principal
    required double interestRate, // Annual interest rate
    required DateTime loanStartDate,
    required int loanTermMonths,
    required int paymentDayOfMonth,
    required CreditPaymentType creditPaymentType,
    required String
    transferToMoneyToolName, // Name of the money tool to transfer funds to
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add credit to "Total Balance" or non-existent account.',
      );
      return;
    }

    // Find the money tool to transfer funds to
    final ToolSummary? transferToTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.accountId == accountId &&
          tool.type == ToolType.money &&
          tool.name == transferToMoneyToolName,
      orElse: () => null,
    );

    if (transferToTool == null) {
      debugPrint(
        'Target money tool "$transferToMoneyToolName" not found in account "$accountId".',
      );
      return;
    }

    // Update the balance of the target money tool
    // Assuming amount is in RUB, update value and calculate quantity increase
    final double effectiveRatePerUnit =
        transferToTool.quantity > 0
            ? transferToTool.currentValue / transferToTool.quantity
            : (transferToTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    transferToTool.currentValue += amount; // Amount is in RUB
    if (effectiveRatePerUnit > 0) {
      transferToTool.quantity += (amount / effectiveRatePerUnit);
    }

    // Add the new credit tool (as a liability, hence negative current value)
    _tools.add(
      ToolSummary(
        id: name,
        name: name,
        quantity: 1.0, // Represents one credit agreement
        percentageChange:
            -interestRate, // Annual interest rate as negative change
        accountId: accountId,
        type: ToolType.credit,
        currentValue:
            -amount, // Principal amount as a negative liability (in RUB)
        interestRate: interestRate,
        loanStartDate: loanStartDate,
        loanTermMonths: loanTermMonths,
        paymentDayOfMonth: paymentDayOfMonth,
        creditPaymentType: creditPaymentType,
      ),
    );


    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Adds a new 'other' tool to a specified account.
  /// Deducts the specified amount from a selected money tool within the same account.
  /// Добавляет тул типа «прочее» — произвольный актив с ручной оценкой.
  ///
  /// - [toolId] — UUID строки в БД (обязателен, чтобы пережить refresh);
  /// - [quantity] — информационное количество (шт, м²...);
  /// - [amount] — общая стоимость актива (источник истины);
  /// - [withdrawalToolName] — если указан, стоимость списывается с этого
  ///   money-тула («покупка актива»); если null — актив «уже в собственности»,
  ///   движение денег не пишется.
  void addOtherTool({
    required String accountId,
    required String name,
    required String toolId,
    required double amount,
    double quantity = 1,
    String? withdrawalToolName,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add other tool to "Total Balance" or non-existent account.',
      );
      return;
    }

    ToolSummary? withdrawalTool;
    if (withdrawalToolName != null) {
      withdrawalTool = _tools.cast<ToolSummary?>().firstWhere(
        (ToolSummary? tool) =>
            tool != null &&
            tool.accountId == accountId &&
            tool.type == ToolType.money &&
            tool.name == withdrawalToolName,
        orElse: () => null,
      );
      if (withdrawalTool == null) {
        debugPrint(
          'Withdrawal money tool "$withdrawalToolName" not found in account "$accountId".',
        );
        return;
      }

      final double withdrawalToolUnitPrice =
          withdrawalTool.quantity > 0
              ? (withdrawalTool.currentValue / withdrawalTool.quantity)
              : 1.0;

      if (withdrawalTool.currentValue < amount) {
        debugPrint(
          'Insufficient funds in ${withdrawalTool.name} for this other tool.',
        );
      }

      withdrawalTool.currentValue -= amount;
      if (withdrawalToolUnitPrice > 0) {
        withdrawalTool.quantity -= (amount / withdrawalToolUnitPrice);
      }
    }

    // Add the new 'other' tool (value set via the creation activity on replay).
    _tools.add(
      ToolSummary(
        id: toolId,
        name: name,
        quantity: quantity,
        percentageChange: 0.0,
        accountId: accountId,
        type: ToolType.other,
        currentValue: amount,
      ),
    );

    _updateTotalBalance();
  }

  /// Toggles the hideEvents flag for a specific account.
  void toggleHideEvents(String accountId) {
    final AccountSummary? account = getAccountById(accountId);
    if (account != null && account.id != 'total') {
      account.hideEvents = !account.hideEvents;
      // Notify listeners to update UI
    } else if (account?.id == 'total') {
      debugPrint('Cannot hide events for "Total Balance" account.');
    } else {
      debugPrint('Account with ID "$accountId" not found.');
    }
  }

  /// Toggles the excludeFromTotal flag for a specific account.
  void toggleExcludeFromTotal(String accountId) {
    final AccountSummary? account = getAccountById(accountId);
    if (account != null && account.id != 'total') {
      account.excludeFromTotal = !account.excludeFromTotal;
      _updateTotalBalance(); // Recalculate total balance
      // Notify listeners to update UI
    } else if (account?.id == 'total') {
      debugPrint('Cannot exclude "Total Balance" account from itself.');
    } else {
      debugPrint('Account with ID "$accountId" not found.');
    }
  }

  /// Adds a new income event, updating a specific money tool and the account balance.
  /// The 'amount' is expected to be in the base currency (RUB).
  void addIncome({
    required String accountId,
    required String toolName,
    required double
    amount, // This amount is the increase in VALUE (RUB equivalent)
    required DateTime date,
    required String category,
    String? comment,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Adds a new expense event, updating a specific money tool and the account balance.
  /// The 'amount' is expected to be in the base currency (RUB).
  void addExpense({
    required String accountId,
    required String toolName,
    required double
    amount, // This amount is the decrease in VALUE (RUB equivalent)
    required DateTime date,
    required String category,
    String? comment,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }


  /// Buys a specified quantity of a stock for an account.
  /// Deducts total cost from the *money tool* of the active account.
  @deprecated
  void buyStock({
    required String accountId,
    required String ticker,
    required String stockName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Sells a specified quantity of a stock for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  @deprecated
  void sellStock({
    required String accountId,
    required String ticker,
    required String stockName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Buys a specified quantity of an ETF for an account.
  /// Deducts total cost from the *money tool* of the active account.
  @deprecated
  void buyEtf({
    required String accountId,
    required String ticker,
    required String etfName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }
  /// Adds total proceeds to the *money tool* of the active account.
  @deprecated
  void sellEtf({
    required String accountId,
    required String ticker,
    required String etfName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Buys a specified quantity of a bond for an account.
  /// Deducts total cost (market price + ACI + commission) from the money tool.
  @deprecated
  void buyBond({
    required String accountId,
    required String ticker,
    required String bondName,
    required double quantity, // Number of bonds
    required double pricePerUnit, // Market price per bond
    required double faceValue, // Nominal value of the bond
    required double accruedCouponIncome, // Accumulated coupon income to be paid
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Sells a specified quantity of a bond for an account.
  /// Adds total proceeds (market price + ACI - commission) to the money tool.
  @deprecated
  void sellBond({
    required String accountId,
    required String ticker,
    required String bondName,
    required double quantity, // Number of bonds
    required double pricePerUnit, // Market price per bond
    required double accruedCouponIncome, // Accumulated coupon income to be received
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Buys a specified quantity of a cryptocurrency for an account.
  /// Deducts total cost from the *money tool* of the active account.
  @deprecated
  void buyCrypto({
    required String accountId,
    required String ticker,
    required String cryptoName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }

  /// Sells a specified quantity of a cryptocurrency for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  @deprecated
  void sellCrypto({
    required String accountId,
    required String ticker,
    required String cryptoName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    throw Exception('Метод устарел, использование InvestmentCubit.submit()');
  }
}