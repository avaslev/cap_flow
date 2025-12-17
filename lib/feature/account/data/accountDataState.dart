import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/utils/formatCurrency.dart';

/// Enum for different types of financial accounts.
enum AccountType {
  general, // Represents checking, savings, general bank accounts
  brokerage, // Represents investment accounts (stocks, bonds, ETFs)
  cryptocurrency, // Represents crypto wallets/exchanges
}

/// Data model for an account summary.
class AccountSummary {
  final String id;
  final String name;
  double balance; // Made mutable to allow updates
  double dailyChangeAmount;
  double dailyChangePercentage;
  final int colorValue;
  final AccountType type;
  bool hideEvents; // New attribute to hide events for this account
  bool
  excludeFromTotal; // New attribute to exclude from total balance calculation

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
  });
}

/// Data model for a financial event/transaction.
class Event {
  final String eventId;
  final String eventType;
  final String name;
  final String description;
  final double amount;
  final String accountId; // To link events to specific accounts
  final String toolId; // To link events to specific accounts
  final DateTime date; // Date of the event

  Event({
    required this.eventId,
    required this.eventType,
    required this.name,
    required this.description,
    required this.amount,
    required this.accountId,
    required this.toolId,
    required this.date,
  });
}

/// Enum for different types of financial tools/assets.
enum ToolType {
  money,
  deposit,
  credit,
  stocks,
  bonds,
  etf,
  cryptocurrency,
  other,
}

/// Enum for different types of deposit payout.
enum PayoutType {
  atEndOfTerm, // в конце срока
  monthly, // ежемесячная выплата
  monthlyToWithdrawalAccount, // ежемесячная выплата на счет списания
}

/// Enum for different types of credit payment.
enum CreditPaymentType {
  annuity, // аннуитетный (fixed payment amount over time)
  differentiated, // дифференцированный (decreasing payment amount over time)
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
  });
}

/// Manages the state of account summaries, events, and tools.
class AccountData {
  final List<AccountSummary> _accounts;
  final Map<String, Event> _events;
  final List<ToolSummary> _tools;
  String _activeAccountId;
  String? _deletableAccountId; // New state for delete mode
  String? _targetDisplayAccount;

  /// Dummy data for stock/ETF suggestions and names
  static const Map<String, String> _allInvestmentOptions = <String, String>{
    'AAPL': 'Apple Inc. Stock',
    'TSLA': 'Tesla Inc. Stock',
    'NVDA': 'Nvidia Corp. Stock',
    'GOOG': 'Alphabet Inc. (Google) Stock',
    'MSFT': 'Microsoft Corp. Stock',
    'AMZN': 'Amazon.com Inc. Stock',
    'FB': 'Meta Platforms Inc. (Facebook) Stock',
    'JPM': 'JPMorgan Chase & Co. Stock',
    'XOM': 'Exxon Mobil Corp. Stock',
    'V': 'Visa Inc. Stock',
    'PG': 'Procter & Gamble Co. Stock',
    'KO': 'The Coca-Cola Company Stock',
    'NFLX': 'Netflix Inc. Stock',
    'DIS': 'The Walt Disney Company Stock',
    'BA': 'The Boeing Company Stock',
    'GS': 'Goldman Sachs Group Inc. Stock',
    'SBER': 'Sberbank Stock',
    'GAZP': 'Gazprom Stock',
    'LKOH': 'Lukoil Stock',
    'YNDX': 'Yandex N.V. Stock',
    'SPY': 'S&P 500 ETF',
    'QQQ': 'Invesco QQQ Trust',
    'DIA': 'SPDR Dow Jones Industrial Average ETF',
    'GLD': 'SPDR Gold Shares ETF',
    'ARKK': 'ARK Innovation ETF',
    'GOV': 'Russian Federal Bonds', // Example bond ticker
    'CORP': 'Corporate Bonds A', // Example corporate bond ticker
    'BTC': 'Bitcoin', // New: Cryptocurrency
    'ETH': 'Ethereum', // New: Cryptocurrency
    'XRP': 'Ripple', // New: Cryptocurrency
    'LTC': 'Litecoin', // New: Cryptocurrency
  };

  Map<String, String> get allInvestmentOptions => _allInvestmentOptions;

  AccountData()
    : _accounts = <AccountSummary>[
        // AccountSummary(
        //   id: 'checking',
        //   name: 'Checking',
        //   balance: 12500.00,
        //   dailyChangeAmount: -120.00,
        //   dailyChangePercentage: -0.96,
        //   colorValue: 0xff007BFF, // Vibrant blue
        //   type: AccountType.general,
        //   hideEvents: false, // Initial value
        //   excludeFromTotal: false, // Initial value
        // ),
        // AccountSummary(
        //   id: 'savings',
        //   name: 'Savings',
        //   balance: 5523.34,
        //   dailyChangeAmount: 655.40,
        //   dailyChangePercentage: 11.87,
        //   colorValue: 0xff28A745, // Strong green
        //   type: AccountType.general,
        //   hideEvents: false, // Initial value
        //   excludeFromTotal: false, // Initial value
        // ),
        // AccountSummary(
        //   id: 'investments',
        //   name: 'Investments',
        //   balance: 23000.50,
        //   dailyChangeAmount: 800.20,
        //   dailyChangePercentage: 3.48,
        //   colorValue: 0xffFFC107, // Deep yellow
        //   type: AccountType.brokerage,
        //   hideEvents: false, // Initial value
        //   excludeFromTotal: false, // Initial value
        // ),
        // // New: Cryptocurrency account
        // AccountSummary(
        //   id: 'crypto_wallet',
        //   name: 'Crypto Wallet',
        //   balance: 15000.00,
        //   dailyChangeAmount: 1200.00,
        //   dailyChangePercentage: 8.00,
        //   colorValue: 0xffFF007B, // A distinct color for crypto (e.g., Pink)
        //   type: AccountType.cryptocurrency,
        //   hideEvents: false,
        //   excludeFromTotal: false,
        // ),
      ],
      _events = new Map<String, Event>(),
      _tools = <ToolSummary>[
        // ToolSummary(
        //   name: 'Russian Ruble',
        //   quantity: 1200.00,
        //   percentageChange: 0.15,
        //   accountId: 'checking',
        //   type: ToolType.money,
        //   currentValue: 1200.00,
        //   ticker: 'RUR', // Added ticker
        // ),
        // ToolSummary(
        //   name: 'S&P 500 ETF',
        //   quantity: 5.5,
        //   percentageChange: 1.23,
        //   accountId: 'investments',
        //   type: ToolType.etf,
        //   currentValue: 2750.00,
        //   ticker: 'SPY', // Added ticker
        // ),
        // ToolSummary(
        //   name: 'Bitcoin',
        //   quantity: 0.12,
        //   percentageChange: -3.45,
        //   accountId: 'crypto_wallet', // Changed accountId to new crypto_wallet
        //   type: ToolType.cryptocurrency,
        //   currentValue: 7200.00,
        //   ticker: 'BTC',
        // ),
        // ToolSummary(
        //   name: 'Ethereum',
        //   quantity: 1.5,
        //   percentageChange: 2.10,
        //   accountId: 'crypto_wallet', // Added Ethereum to crypto_wallet
        //   type: ToolType.cryptocurrency,
        //   currentValue: 4500.00,
        //   ticker: 'ETH',
        // ),
        // ToolSummary(
        //   name: 'Fixed Deposit (6M)',
        //   quantity: 2000.00,
        //   percentageChange: 0.05,
        //   accountId: 'savings',
        //   type: ToolType.deposit,
        //   currentValue: 2000.00,
        //   startDate: DateTime(2023, 1, 1),
        //   endDate: DateTime(2023, 7, 1),
        //   payoutType: PayoutType.atEndOfTerm,
        //   withdrawalToolId: 'checking_RUR', // Example ID
        // ),
        // ToolSummary(
        //   name: 'Apple Inc. Stock',
        //   quantity: 10.0,
        //   percentageChange: 0.88,
        //   accountId: 'investments',
        //   type: ToolType.stocks,
        //   currentValue: 1800.00,
        //   ticker: 'AAPL', // Added ticker
        // ),
        // ToolSummary(
        //   name: 'Tesla Inc. Stock',
        //   quantity: 20.0,
        //   percentageChange: 0.88,
        //   accountId: 'investments',
        //   type: ToolType.stocks,
        //   currentValue: 18000.00,
        //   ticker: 'TSLA', // Added ticker
        // ),
        // ToolSummary(
        //   name: 'Nvidia Inc. Stock',
        //   quantity: 30.0,
        //   percentageChange: 0.88,
        //   accountId: 'investments',
        //   type: ToolType.stocks,
        //   currentValue: 38000.00,
        //   ticker: 'NVDA', // Added ticker
        // ),
        // ToolSummary(
        //   name: 'USD',
        //   quantity: 1200.00,
        //   percentageChange: 0,
        //   accountId: 'investments',
        //   type: ToolType.money,
        //   currentValue: 1200.00,
        // ),
        // ToolSummary(
        //   name: 'Russian Ruble',
        //   quantity: 5000.00,
        //   percentageChange: 0.0,
        //   accountId: 'crypto_wallet', // RUR for crypto_wallet
        //   type: ToolType.money,
        //   currentValue: 5000.00,
        //   ticker: 'RUR',
        // ),
        // ToolSummary(
        //   name: 'Mortgage Loan',
        //   quantity: 1.0, // Represents one loan agreement
        //   percentageChange: -0.10, // Annual interest rate as negative change
        //   accountId: 'checking',
        //   type: ToolType.credit,
        //   currentValue: -150000.00, // Principal amount as a negative liability
        //   interestRate: 10.0, // Example interest rate
        //   loanStartDate: DateTime(2022, 1, 1),
        //   loanTermMonths: 360, // 30 years
        //   paymentDayOfMonth: 15,
        //   creditPaymentType: CreditPaymentType.annuity,
        // ),
        // ToolSummary(
        //   name: 'Treasury Bonds',
        //   quantity: 3.0,
        //   percentageChange: 0.25,
        //   accountId: 'investments',
        //   type: ToolType.bonds,
        //   currentValue: 3000.00,
        //   ticker: 'GOV',
        //   faceValue: 1000.0, // Example face value
        // ),
      ],
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

  /// Returns an unmodifiable list of all account summaries, including 'total'.
  Map<String,ToolSummary> get tools =>
      {for (var item in _tools) item.id : item};

  /// Calculates and updates the balance, daily change amount, and daily change percentage for the 'total' account.
  void _updateTotalBalance() {
    double totalBalance = 0.0;
    double totalDailyChangeAmount = 0.0;
    bool changed = false;

    for (final AccountSummary acc in _accounts) {
      if (acc.id != 'total' && !acc.excludeFromTotal) {
        // Sum up current values of all tools for this account to get its balance
        final double accountToolsBalance = _tools
            .where((ToolSummary tool) => tool.accountId == acc.id)
            .fold(
              0.0,
              (double sum, ToolSummary tool) => sum + tool.currentValue,
            );

        // Update account's balance to reflect sum of its tools
        if (acc.balance != accountToolsBalance) {
          acc.balance = accountToolsBalance;
          changed = true;
        }

        totalBalance += acc.balance;
        totalDailyChangeAmount += acc.dailyChangeAmount;
      }
    }

    final AccountSummary totalAccount = _accounts.firstWhere(
      (AccountSummary acc) => acc.id == 'total',
    );

    if (totalAccount.balance != totalBalance) {
      totalAccount.balance = totalBalance;
      changed = true;
    }

    if (totalAccount.dailyChangeAmount != totalDailyChangeAmount) {
      totalAccount.dailyChangeAmount = totalDailyChangeAmount;
      changed = true;
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
      changed = true;
    }

    // if (changed) {
    //
    // }
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
      .toList();
  filtered.sort((ToolSummary a, ToolSummary b) {
    final int typeComparison = a.type.index.compareTo(b.type.index);
    if (typeComparison != 0) return typeComparison;
    return a.name.compareTo(b.name);
  });
  
  return filtered;
}

  /// Returns only money tools associated with a specific account.
  List<ToolSummary> getMoneyToolsForAccount(String accountId) {
    return _tools
        .where(
          (ToolSummary tool) =>
              tool.accountId == accountId && tool.type == ToolType.money,
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
    String accountId,
    String toolId,
    double amount,
    DateTime date,
  ) {

    final event = Event(
          eventId: eventId,
          eventType: eventType,
          name: name,
          description: description,
          amount: amount,
          accountId: accountId,
          toolId: toolId,
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

    // Deduct from source tool and account
    fromTool.currentValue -= (amount + commission);
    if (fromToolUnitPrice > 0) {
      fromTool.quantity -= (amount + commission) / fromToolUnitPrice;
    } else {
      debugPrint(
        'Warning: Source tool ${fromTool.name} has zero/negative effective unit price, cannot update quantity for transfer outflow.',
      );
    }
    // fromAccount.balance -= (amount + commission); // Account balance is updated by _updateTotalBalance

    // Add to destination tool and account
    toTool.currentValue += amount;
    if (toToolUnitPrice > 0) {
      toTool.quantity += amount / toToolUnitPrice;
    } else {
      debugPrint(
        'Warning: Destination tool ${toTool.name} has zero/negative effective unit price, cannot update quantity for transfer inflow.',
      );
    }
    // toAccount.balance += amount; // Account balance is updated by _updateTotalBalance

    _updateTotalBalance(); // This will recalculate account balances based on tool values
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

  /// Adds a new account.
  void addAccount(AccountSummary newAccount) {
    _accounts.isNotEmpty
      ? _accounts.removeWhere((item) => item.id == newAccount.id)
      : null;
    _accounts.add(newAccount);

    _updateTotalBalance(); // Recalculates total and notifies listeners
    // Notify for accounts list change
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

  /// Adds a new money tool to a specified account.
  void addMoneyTool(
    String accountId,
    String name,
    double quantity,
    String currencyTicker,
    double unitPrice,
  ) {
    final AccountSummary? account = getAccountById(accountId);
    if (account != null && account.id != 'total') {
      final double currentValue = quantity * unitPrice;
      _tools.add(
        ToolSummary(
          id: name,
          name: name,
          quantity: quantity,
          percentageChange: 0.0, // New money tools start with 0% change
          accountId: accountId,
          type: ToolType.money,
          currentValue: currentValue,
          ticker: currencyTicker,
        ),
      );
      // Account balance is updated by _updateTotalBalance
      _updateTotalBalance(); // Recalculates total and notifies listeners
      // Notify for tools list change
    } else if (account?.id == 'total') {
      debugPrint('Cannot add tools directly to "Total Balance" account.');
    } else {
      debugPrint('Account with ID "$accountId" not found.');
    }
  }

  /// Adds a new deposit tool to a specified account.
  /// Deducts the principal from a specified money tool within the same account.
  void addDeposit({
    required String accountId,
    required String name,
    required double quantity, // Principal amount
    required double annualYield, // Percentage
    required DateTime startDate,
    required DateTime endDate,
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
        id: name,
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
  void addOtherTool({
    required String accountId,
    required String name,
    required double
    amount, // Amount to be converted/used for the new tool (in RUB)
    required String withdrawalToolName, // Name of the money tool to deduct from
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add other tool to "Total Balance" or non-existent account.',
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

    // Calculate actual value being withdrawn (in RUB) based on the current effective rate of the withdrawal tool
    final double withdrawalToolUnitPrice =
        withdrawalTool.quantity > 0
            ? (withdrawalTool.currentValue / withdrawalTool.quantity)
            : (withdrawalTool.ticker == 'USD' ? 90.0 : 1.0);

    if (withdrawalTool.currentValue < amount) {
      // Compare in RUB
      debugPrint(
        'Insufficient funds in ${withdrawalTool.name} for this other tool.',
      );
      // Allowing to go negative for demonstration
    }

    // Deduct value and quantity from the withdrawal money tool
    withdrawalTool.currentValue -= amount; // Amount is in RUB
    if (withdrawalToolUnitPrice > 0) {
      withdrawalTool.quantity -= (amount / withdrawalToolUnitPrice);
    }

    // Add the new 'other' tool
    _tools.add(
      ToolSummary(
        id: name,
        name: name,
        quantity:
            amount /
            withdrawalToolUnitPrice, // Quantity based on how many units of the original tool were "converted"
        percentageChange: 0.0, // Initial change for 'other' tool
        accountId: accountId,
        type: ToolType.other,
        currentValue: amount, // Value in RUB
        ticker: withdrawalTool.ticker, // Ticker from the withdrawal tool
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
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
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add income to "Total Balance" or non-existent account.',
      );
      return;
    }

    final ToolSummary? targetTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.accountId == accountId &&
          tool.type == ToolType.money &&
          tool.name == toolName,
      orElse: () => null,
    );

    if (targetTool == null) {
      debugPrint(
        'Target money tool "$toolName" not found in account "$accountId".',
      );
      return;
    }

    // Calculate the 'unit price' to correctly update quantity for non-RUR currencies.
    // If the tool has a quantity, use its current effective unit price (currentValue / quantity).
    // If quantity is zero (e.g., first income to an empty currency tool), use a default rate.
    double effectiveRatePerUnit = 1.0; // Default for RUR
    if (targetTool.ticker == 'USD') {
      if (targetTool.quantity > 0) {
        effectiveRatePerUnit = targetTool.currentValue / targetTool.quantity;
      } else {
        // Fallback rate if tool is empty. This is crucial for new or zero-balance foreign currency tools.
        effectiveRatePerUnit =
            90.0; // Assuming a fixed or average USD rate for income
      }
    }

    // Update the current value (in RUB) of the tool
    targetTool.currentValue += amount;

    // Update the quantity of the tool based on the income amount (in RUB) and the effective rate.
    // This correctly translates RUB income into units of the tool's native currency.
    if (effectiveRatePerUnit > 0) {
      // Avoid division by zero
      targetTool.quantity += (amount / effectiveRatePerUnit);
    } else {
      debugPrint(
        'Warning: Effective unit price for tool ${targetTool.name} is zero/negative, cannot update quantity correctly for income.',
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
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
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint(
        'Cannot add expense to "Total Balance" or non-existent account.',
      );
      return;
    }

    final ToolSummary? targetTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.accountId == accountId &&
          tool.type == ToolType.money &&
          tool.name == toolName,
      orElse: () => null,
    );

    if (targetTool == null) {
      debugPrint(
        'Target money tool "$toolName" not found in account "$accountId".',
      );
      return;
    }

    // Calculate the 'unit price' to correctly update quantity for non-RUR currencies.
    double effectiveRatePerUnit = 1.0; // Default for RUR
    if (targetTool.ticker == 'USD') {
      if (targetTool.quantity > 0) {
        effectiveRatePerUnit = targetTool.currentValue / targetTool.quantity;
      } else {
        // Fallback rate if tool is empty or quantity is zero.
        effectiveRatePerUnit =
            90.0; // Assuming a fixed or average USD rate for expense
      }
    }

    // Check for sufficient funds. This is a simple check; more robust handling might involve
    // allowing overdrafts and marking the account as overdrawn.
    if (amount > 0 && targetTool.currentValue < amount) {
      debugPrint(
        'Warning: Insufficient funds in ${targetTool.name} to cover this expense.',
      );
      // For this app, we'll allow it to go negative to reflect possible overdrafts.
    }

    // Update the current value (in RUB) of the tool
    targetTool.currentValue -= amount;

    // Update the quantity of the tool based on the expense amount (in RUB) and the effective rate.
    if (effectiveRatePerUnit > 0) {
      // Avoid division by zero
      targetTool.quantity -= (amount / effectiveRatePerUnit);
    } else {
      debugPrint(
        'Warning: Effective unit price for tool ${targetTool.name} is zero/negative, cannot update quantity correctly for expense.',
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Helper to get the default money tool for an account (preferably RUR, else any).
  ToolSummary? _getDefaultMoneyToolForAccount(String accountId) {
    final List<ToolSummary> moneyTools = getMoneyToolsForAccount(accountId);
    // Prefer Russian Ruble tool
    final ToolSummary? rurTool = moneyTools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) => tool != null && tool.ticker == 'RUR',
      orElse: () => null,
    );
    if (rurTool != null) {
      return rurTool;
    }
    // Otherwise, return any other money tool if available
    return moneyTools.isNotEmpty ? moneyTools.first : null;
  }

  /// Buys a specified quantity of a stock for an account.
  /// Deducts total cost from the *money tool* of the active account.
  void buyStock({
    required String accountId,
    required String ticker,
    required String stockName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.brokerage) {
      debugPrint(
        'Cannot buy stock for "Total Balance" or non-brokerage/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to deduct funds from.',
      );
      return;
    }

    final double totalCost = (quantity * pricePerUnit) + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $stockName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for stock purchase.',
      );
    }

    ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.stocks,
      orElse: () => null,
    );

    if (existingTool != null) {
      // Update existing stock holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
    } else {
      // Add new stock tool
      _tools.add(
        ToolSummary(
          id: stockName,
          name: stockName,
          quantity: quantity,
          percentageChange:
              0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.stocks,
          currentValue: quantity * pricePerUnit,
          ticker: ticker,
        ),
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Sells a specified quantity of a stock for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  void sellStock({
    required String accountId,
    required String ticker,
    required String
    stockName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.brokerage) {
      debugPrint(
        'Cannot sell stock for "Total Balance" or non-brokerage/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to receive funds.',
      );
      return;
    }

    final ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.stocks,
      orElse: () => null,
    );

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
        'Insufficient quantity of $ticker in ${account.name} to sell.',
      );
      // Should prevent transaction or show an error
      return;
    }

    final double totalProceeds = (quantity * pricePerUnit) - commission;

    // Update existing stock holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for stock sale.',
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere(
        (ToolSummary tool) =>
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.stocks,
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Buys a specified quantity of an ETF for an account.
  /// Deducts total cost from the *money tool* of the active account.
  void buyEtf({
    required String accountId,
    required String ticker,
    required String etfName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.brokerage) {
      debugPrint(
        'Cannot buy ETF for "Total Balance" or non-brokerage/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to deduct funds from.',
      );
      return;
    }

    final double totalCost = (quantity * pricePerUnit) + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $etfName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for ETF purchase.',
      );
    }

    ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.etf,
      orElse: () => null,
    );

    if (existingTool != null) {
      // Update existing ETF holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
    } else {
      // Add new ETF tool
      _tools.add(
        ToolSummary(
          id: etfName,
          name: etfName,
          quantity: quantity,
          percentageChange:
              0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.etf,
          currentValue: quantity * pricePerUnit,
          ticker: ticker,
        ),
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Sells a specified quantity of an ETF for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  void sellEtf({
    required String accountId,
    required String ticker,
    required String
    etfName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.brokerage) {
      debugPrint(
        'Cannot sell ETF for "Total Balance" or non-brokerage/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to receive funds.',
      );
      return;
    }

    final ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.etf,
      orElse: () => null,
    );

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
        'Insufficient quantity of $ticker in ${account.name} to sell.',
      );
      // Should prevent transaction or show an error
      return;
    }

    final double totalProceeds = (quantity * pricePerUnit) - commission;

    // Update existing ETF holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for ETF sale.',
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere(
        (ToolSummary tool) =>
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.etf,
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Buys a specified quantity of a bond for an account.
  /// Deducts total cost (market price + ACI + commission) from the money tool.
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
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.brokerage) {
      debugPrint(
        'Cannot buy bond for "Total Balance" or non-brokerage/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to deduct funds from.',
      );
      return;
    }

    final double totalCost =
        (quantity * pricePerUnit) + accruedCouponIncome + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $bondName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for bond purchase.',
      );
    }

    ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.bonds,
      orElse: () => null,
    );

    if (existingTool != null) {
      // Update existing bond holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
      // Face value is usually constant for a given bond type, assume it matches
      // If it can change, a more complex update or separate bond series might be needed.
    } else {
      // Add new bond tool
      _tools.add(
        ToolSummary(
          id: bondName,
          name: bondName,
          quantity: quantity,
          percentageChange:
              0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.bonds,
          currentValue:
              quantity * pricePerUnit, // Current value is market value
          ticker: ticker,
          faceValue: faceValue, // Store nominal value
        ),
      );
    }

    _updateTotalBalance();
  }

  /// Sells a specified quantity of a bond for an account.
  /// Adds total proceeds (market price + ACI - commission) to the money tool.
  void sellBond({
    required String accountId,
    required String ticker,
    required String bondName,
    required double quantity, // Number of bonds
    required double pricePerUnit, // Market price per bond
    required double accruedCouponIncome, // Accumulated coupon income received
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.brokerage) {
      debugPrint(
        'Cannot sell bond for "Total Balance" or non-brokerage/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to receive funds.',
      );
      return;
    }

    final ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.bonds,
      orElse: () => null,
    );

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
        'Insufficient quantity of $ticker in ${account.name} to sell.',
      );
      return;
    }

    final double totalProceeds =
        (quantity * pricePerUnit) + accruedCouponIncome - commission;

    // Update existing bond holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for bond sale.',
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere(
        (ToolSummary tool) =>
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.bonds,
      );
    }

    _updateTotalBalance();
  }

  /// Buys a specified quantity of a cryptocurrency for an account.
  /// Deducts total cost from the *money tool* of the active account.
  void buyCrypto({
    required String accountId,
    required String ticker,
    required String cryptoName,
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.cryptocurrency) {
      debugPrint(
        'Cannot buy cryptocurrency for "Total Balance" or non-cryptocurrency/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to deduct funds from.',
      );
      return;
    }

    final double totalCost = (quantity * pricePerUnit) + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $cryptoName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for crypto purchase.',
      );
    }

    ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.cryptocurrency,
      orElse: () => null,
    );

    if (existingTool != null) {
      // Update existing crypto holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
    } else {
      // Add new crypto tool
      _tools.add(
        ToolSummary(
          id: cryptoName,
          name: cryptoName,
          quantity: quantity,
          percentageChange:
              0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.cryptocurrency,
          currentValue: quantity * pricePerUnit,
          ticker: ticker,
        ),
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }

  /// Sells a specified quantity of a cryptocurrency for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  void sellCrypto({
    required String accountId,
    required String ticker,
    required String
    cryptoName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null ||
        account.id == 'total' ||
        account.type != AccountType.cryptocurrency) {
      debugPrint(
        'Cannot sell cryptocurrency for "Total Balance" or non-cryptocurrency/non-existent account.',
      );
      return;
    }

    final ToolSummary? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint(
        'No money tool found in account "$accountId" to receive funds.',
      );
      return;
    }

    final ToolSummary? existingTool = _tools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) =>
          tool != null &&
          tool.ticker == ticker &&
          tool.accountId == accountId &&
          tool.type == ToolType.cryptocurrency,
      orElse: () => null,
    );

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
        'Insufficient quantity of $ticker in ${account.name} to sell.',
      );
      // Should prevent transaction or show an error
      return;
    }

    final double totalProceeds = (quantity * pricePerUnit) - commission;

    // Update existing crypto holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice =
        moneyTool.quantity > 0
            ? moneyTool.currentValue / moneyTool.quantity
            : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
        'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for crypto sale.',
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere(
        (ToolSummary tool) =>
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.cryptocurrency,
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
  }
}
