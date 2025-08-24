import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Required for Timer or Future

/// Formats a double value as a currency string.
String formatCurrency(double amount) {
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2);
  return currencyFormat.format(amount);
}

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
  bool excludeFromTotal; // New attribute to exclude from total balance calculation

  AccountSummary({
    required this.id,
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
  final String description;
  final double amount;
  final bool isCredit; // true for income (+), false for expense (-)
  final String accountId; // To link events to specific accounts
  final DateTime date; // Date of the event

  Event({
    required this.description,
    required this.amount,
    required this.isCredit,
    required this.accountId,
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
class Tool {
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
  final String? withdrawalToolId; // ID of the money tool from which funds were taken

  // New Credit specific fields, nullable for other tool types
  final double? interestRate; // Annual interest rate for credit/loan
  final DateTime? loanStartDate; // Start date of the loan
  final int? loanTermMonths; // Term of the loan in months
  final int? paymentDayOfMonth; // Day of the month for credit payments
  final CreditPaymentType? creditPaymentType; // Type of payment for credit (annuity, differentiated)

  // New Bond specific fields
  final double? faceValue; // Nominal value of the bond

  Tool({
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
class AccountData extends ChangeNotifier {
  final List<AccountSummary> _accounts;
  final List<Event> _events;
  final List<Tool> _tools;
  String _activeAccountId;
  String? _deletableAccountId; // New state for delete mode

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
          AccountSummary(
            id: 'checking',
            name: 'Checking',
            balance: 12500.00,
            dailyChangeAmount: -120.00,
            dailyChangePercentage: -0.96,
            colorValue: 0xff007BFF, // Vibrant blue
            type: AccountType.general,
            hideEvents: false, // Initial value
            excludeFromTotal: false, // Initial value
          ),
          AccountSummary(
            id: 'savings',
            name: 'Savings',
            balance: 5523.34,
            dailyChangeAmount: 655.40,
            dailyChangePercentage: 11.87,
            colorValue: 0xff28A745, // Strong green
            type: AccountType.general,
            hideEvents: false, // Initial value
            excludeFromTotal: false, // Initial value
          ),
          AccountSummary(
            id: 'investments',
            name: 'Investments',
            balance: 23000.50,
            dailyChangeAmount: 800.20,
            dailyChangePercentage: 3.48,
            colorValue: 0xffFFC107, // Deep yellow
            type: AccountType.brokerage,
            hideEvents: false, // Initial value
            excludeFromTotal: false, // Initial value
          ),
          // New: Cryptocurrency account
          AccountSummary(
            id: 'crypto_wallet',
            name: 'Crypto Wallet',
            balance: 15000.00,
            dailyChangeAmount: 1200.00,
            dailyChangePercentage: 8.00,
            colorValue: 0xffFF007B, // A distinct color for crypto (e.g., Pink)
            type: AccountType.cryptocurrency,
            hideEvents: false,
            excludeFromTotal: false,
          ),
        ],
        _events = <Event>[
          Event(
            description: 'Salary Deposit',
            amount: 3000.00,
            isCredit: true,
            accountId: 'checking',
            date: DateTime.now().subtract(const Duration(days: 2)), // Past
          ),
          Event(
            description: 'Groceries',
            amount: 85.50,
            isCredit: false,
            accountId: 'checking',
            date: DateTime.now().subtract(const Duration(days: 1)), // Past
          ),
          Event(
            description: 'Online Subscription',
            amount: 15.00,
            isCredit: false,
            accountId: 'checking',
            date: DateTime.now().subtract(const Duration(days: 2)), // Past
          ),
          Event(
            description: 'Freelance Payment',
            amount: 500.00,
            isCredit: true,
            accountId: 'savings',
            date: DateTime.now().subtract(const Duration(days: 3)), // Past
          ),
          Event(
            description: 'Restaurant Dinner',
            amount: 60.00,
            isCredit: false,
            accountId: 'checking',
            date: DateTime.now().subtract(const Duration(days: 4)), // Past
          ),
          Event(
            description: 'Utility Bill',
            amount: 120.00,
            isCredit: false,
            accountId: 'checking',
            date: DateTime.now().subtract(const Duration(days: 5)), // Past
          ),
          Event(
            description: 'Refund from Store',
            amount: 45.00,
            isCredit: true,
            accountId: 'checking',
            date: DateTime.now().subtract(const Duration(days: 6)), // Past
          ),
          Event(
            description: 'Future Income',
            amount: 1000.00,
            isCredit: true,
            accountId: 'savings',
            date: DateTime.now().add(const Duration(days: 1)), // Future
          ),
          Event(
            description: 'Upcoming Bill',
            amount: 75.00,
            isCredit: false,
            accountId: 'checking',
            date: DateTime.now().add(const Duration(days: 2)), // Future
          ),
          Event(
            description: 'Dividends',
            amount: 250.00,
            isCredit: true,
            accountId: 'investments',
            date: DateTime.now().add(const Duration(days: 3)), // Future
          ),
        ],
        _tools = <Tool>[
          Tool(
            name: 'Russian Ruble',
            quantity: 1200.00,
            percentageChange: 0.15,
            accountId: 'checking',
            type: ToolType.money,
            currentValue: 1200.00,
            ticker: 'RUR', // Added ticker
          ),
          Tool(
            name: 'S&P 500 ETF',
            quantity: 5.5,
            percentageChange: 1.23,
            accountId: 'investments',
            type: ToolType.etf,
            currentValue: 2750.00,
            ticker: 'SPY', // Added ticker
          ),
          Tool(
            name: 'Bitcoin',
            quantity: 0.12,
            percentageChange: -3.45,
            accountId: 'crypto_wallet', // Changed accountId to new crypto_wallet
            type: ToolType.cryptocurrency,
            currentValue: 7200.00,
            ticker: 'BTC',
          ),
          Tool(
            name: 'Ethereum',
            quantity: 1.5,
            percentageChange: 2.10,
            accountId: 'crypto_wallet', // Added Ethereum to crypto_wallet
            type: ToolType.cryptocurrency,
            currentValue: 4500.00,
            ticker: 'ETH',
          ),
          Tool(
            name: 'Fixed Deposit (6M)',
            quantity: 2000.00,
            percentageChange: 0.05,
            accountId: 'savings',
            type: ToolType.deposit,
            currentValue: 2000.00,
            startDate: DateTime(2023, 1, 1),
            endDate: DateTime(2023, 7, 1),
            payoutType: PayoutType.atEndOfTerm,
            withdrawalToolId: 'checking_RUR', // Example ID
          ),
          Tool(
            name: 'Apple Inc. Stock',
            quantity: 10.0,
            percentageChange: 0.88,
            accountId: 'investments',
            type: ToolType.stocks,
            currentValue: 1800.00,
            ticker: 'AAPL', // Added ticker
          ),
          Tool(
            name: 'Tesla Inc. Stock',
            quantity: 20.0,
            percentageChange: 0.88,
            accountId: 'investments',
            type: ToolType.stocks,
            currentValue: 18000.00,
            ticker: 'TSLA', // Added ticker
          ),
          Tool(
            name: 'Nvidia Inc. Stock',
            quantity: 30.0,
            percentageChange: 0.88,
            accountId: 'investments',
            type: ToolType.stocks,
            currentValue: 38000.00,
            ticker: 'NVDA', // Added ticker
          ),
          Tool(
            name: 'USD',
            quantity: 1200.00,
            percentageChange: 0,
            accountId: 'investments',
            type: ToolType.money,
            currentValue: 1200.00,
          ),
          Tool(
            name: 'Russian Ruble',
            quantity: 5000.00,
            percentageChange: 0.0,
            accountId: 'crypto_wallet', // RUR for crypto_wallet
            type: ToolType.money,
            currentValue: 5000.00,
            ticker: 'RUR',
          ),
          Tool(
            name: 'Mortgage Loan',
            quantity: 1.0, // Represents one loan agreement
            percentageChange: -0.10, // Annual interest rate as negative change
            accountId: 'checking',
            type: ToolType.credit,
            currentValue: -150000.00, // Principal amount as a negative liability
            interestRate: 10.0, // Example interest rate
            loanStartDate: DateTime(2022, 1, 1),
            loanTermMonths: 360, // 30 years
            paymentDayOfMonth: 15,
            creditPaymentType: CreditPaymentType.annuity,
          ),
          Tool(
            name: 'Treasury Bonds',
            quantity: 3.0,
            percentageChange: 0.25,
            accountId: 'investments',
            type: ToolType.bonds,
            currentValue: 3000.00,
            ticker: 'GOV',
            faceValue: 1000.0, // Example face value
          ),
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

  /// Calculates and updates the balance, daily change amount, and daily change percentage for the 'total' account.
  void _updateTotalBalance() {
    double totalBalance = 0.0;
    double totalDailyChangeAmount = 0.0;
    bool changed = false;

    for (final AccountSummary acc in _accounts) {
      if (acc.id != 'total' && !acc.excludeFromTotal) {
        // Sum up current values of all tools for this account to get its balance
        final double accountToolsBalance = _tools
            .where((Tool tool) => tool.accountId == acc.id)
            .fold(0.0, (double sum, Tool tool) => sum + tool.currentValue);

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
          totalDailyChangeAmount > 0 ? double.infinity : double.negativeInfinity;
    }

    if (totalAccount.dailyChangePercentage != totalDailyChangePercentage) {
      totalAccount.dailyChangePercentage = totalDailyChangePercentage;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Returns events for a specific account, sorted by date (oldest first).
  /// Events are filtered based on the account's hideEvents flag.
  List<Event> getEventsForAccount(String accountId) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.hideEvents) {
      return <Event>[]; // Return empty list if account not found or events are hidden
    }
    return _events
        .where((Event event) => event.accountId == accountId)
        .toList()
      ..sort(
        (Event a, Event b) => a.date.compareTo(b.date), // Changed to oldest first
      );
  }

  /// Returns all events across all accounts, sorted by date (oldest first).
  /// Events from accounts with hideEvents flag set to true are excluded.
  List<Event> get allEvents {
    final List<Event> filteredEvents = _events.where((Event event) {
      final AccountSummary? account = getAccountById(event.accountId);
      return account != null && !account.hideEvents;
    }).toList();

    final List<Event> sortedEvents = List<Event>.from(filteredEvents)
      ..sort((Event a, Event b) =>
          a.date.compareTo(b.date)); // Changed to oldest first
    return List<Event>.unmodifiable(sortedEvents);
  }

  /// Returns tools associated with a specific account, sorted by type and then name.
  List<Tool> getToolsForAccount(String accountId) {
    return _tools.where((Tool tool) => tool.accountId == accountId).toList()
      ..sort((Tool a, Tool b) {
        final int typeComparison = a.type.index.compareTo(b.type.index);
        if (typeComparison != 0) {
          return typeComparison;
        }
        return a.name.compareTo(b.name);
      });
  }

  /// Returns only money tools associated with a specific account.
  List<Tool> getMoneyToolsForAccount(String accountId) {
    return _tools
        .where((Tool tool) =>
            tool.accountId == accountId && tool.type == ToolType.money)
        .toList();
  }

  /// Returns all money tools from all accounts.
  List<Tool> get allMoneyTools {
    return _tools.where((Tool tool) => tool.type == ToolType.money).toList();
  }

  /// Returns a [Tool] by its name and accountId, or null if not found.
  Tool? getToolByNameAndAccountId(String toolName, String accountId) {
    try {
      return _tools.firstWhere((Tool tool) => tool.name == toolName && tool.accountId == accountId);
    } catch (e) {
      return null;
    }
  }

  /// Returns a [Tool] by its ticker and accountId, or null if not found.
  Tool? getToolByTickerAndAccountId(String ticker, String accountId) {
    try {
      return _tools.firstWhere((Tool tool) =>
          tool.ticker == ticker && tool.accountId == accountId);
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

  /// Returns the ID of the currently active account.
  String get activeAccountId => _activeAccountId;

  /// Sets the active account by its ID.
  void setActiveAccount(String id) {
    if (_activeAccountId != id) {
      _activeAccountId = id;
      _deletableAccountId =
          null; // Clear deletable mode when changing active account
      notifyListeners(); // Notify listeners when active account changes
    }
  }

  /// Returns the ID of the account currently in deletable mode.
  String? get deletableAccountId => _deletableAccountId;

  /// Sets the account ID to be marked for deletion.
  void setDeletableAccount(String? id) {
    if (_deletableAccountId != id) {
      _deletableAccountId = id;
      notifyListeners();
    }
  }

  /// Clears the deletable account mode.
  void clearDeletableAccount() {
    if (_deletableAccountId != null) {
      _deletableAccountId = null;
      notifyListeners();
    }
  }

  /// Checks if a given account is currently marked for deletion.
  bool isAccountDeletable(String id) {
    return _deletableAccountId == id;
  }

  /// Adds a new financial event (income or expense) and updates the account balance.
  void addEvent(
    String accountId,
    String description,
    double amount,
    bool isCredit,
  ) {
    final AccountSummary? account = getAccountById(accountId);
    if (account != null && account.id != 'total') {
      _events.add(
        Event(
          description: description,
          amount: amount,
          isCredit: isCredit,
          accountId: accountId,
          date: DateTime.now(),
        ),
      );
      // Event logic updates account balance, but actual tool balances are managed by addIncome/addExpense
      // This general addEvent is likely for internal use or less detailed operations
      if (isCredit) {
        account.balance += amount;
      } else {
        account.balance -= amount;
      }
      _updateTotalBalance(); // This will notify listeners for account balance changes
      notifyListeners(); // Also notify for events list change
    } else if (account?.id == 'total') {
      debugPrint('Cannot add transactions directly to "Total Balance" account.');
    } else {
      debugPrint('Account with ID "$accountId" not found.');
    }
  }

  /// Performs a transfer between two accounts and updates their balances.
  void makeTransfer(String fromAccountId, String toAccountId, double amount) {
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
    // This is account-level transfer, not tool-level. Tool-level handles currency conversions.
    // This method is now effectively deprecated or used for simpler transfers.
    // Consider consolidating with makeToolTransfer if all transfers are tool-based.
    if (fromAccount.balance < amount) {
      debugPrint(
          'Insufficient funds in ${fromAccount.name} for this transfer.');
      return;
    }

    fromAccount.balance -= amount;
    toAccount.balance += amount;

    // Record as two events for historical tracking
    _events.add(
      Event(
        description: 'Transfer to ${toAccount.name}',
        amount: amount,
        isCredit: false,
        accountId: fromAccountId,
        date: DateTime.now(),
      ),
    );
    _events.add(
      Event(
        description: 'Transfer from ${fromAccount.name}',
        amount: amount,
        isCredit: true,
        accountId: toAccountId,
        date: DateTime.now(),
      ),
    );

    _updateTotalBalance(); // This will notify listeners for account balance changes
    notifyListeners(); // Also notify for events list change
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
    final Tool? fromTool =
        getToolByNameAndAccountId(fromToolName, fromAccountId);
    final Tool? toTool = getToolByNameAndAccountId(toToolName, toAccountId);

    if (fromTool == null) {
      debugPrint(
          'Source money tool "$fromToolName" not found in account "$fromAccountId".');
      return;
    }
    if (toTool == null) {
      debugPrint(
          'Destination money tool "$toToolName" not found in account "$toAccountId".');
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
    double fromToolUnitPrice = fromTool.quantity > 0
        ? fromTool.currentValue / fromTool.quantity
        : (fromTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    double toToolUnitPrice = toTool.quantity > 0
        ? toTool.currentValue / toTool.quantity
        : (toTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    // Check for sufficient funds in the source tool (in RUB equivalent)
    if (fromTool.currentValue < (amount + commission)) {
      debugPrint(
          'Insufficient funds in ${fromTool.name} (${fromAccount.name}) for this transfer.');
      // Allowing to go negative for demonstration, in a real app this would trigger an an error message
    }

    // Deduct from source tool and account
    fromTool.currentValue -= (amount + commission);
    if (fromToolUnitPrice > 0) {
      fromTool.quantity -= (amount + commission) / fromToolUnitPrice;
    } else {
      debugPrint(
          'Warning: Source tool ${fromTool.name} has zero/negative effective unit price, cannot update quantity for transfer outflow.');
    }
    // fromAccount.balance -= (amount + commission); // Account balance is updated by _updateTotalBalance

    // Add to destination tool and account
    toTool.currentValue += amount;
    if (toToolUnitPrice > 0) {
      toTool.quantity += amount / toToolUnitPrice;
    } else {
      debugPrint(
          'Warning: Destination tool ${toTool.name} has zero/negative effective unit price, cannot update quantity for transfer inflow.');
    }
    // toAccount.balance += amount; // Account balance is updated by _updateTotalBalance

    // Record events
    _events.add(
      Event(
        description: 'Transfer: ${fromTool.name} -> ${toTool.name}',
        amount: amount,
        isCredit: false,
        accountId: fromAccountId,
        date: date,
      ),
    );
    _events.add(
      Event(
        description: 'Transfer: ${fromTool.name} -> ${toTool.name}',
        amount: amount,
        isCredit: true,
        accountId: toAccountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Transfer Commission (from ${fromTool.name})',
          amount: commission,
          isCredit: false,
          accountId: fromAccountId,
          date: date,
        ),
      );
    }

    _updateTotalBalance(); // This will recalculate account balances based on tool values
    notifyListeners(); // Also notify for events list change
  }

  /// Deletes an account and associated events/tools.
  void deleteAccount(String accountId) {
    if (accountId == 'total') {
      debugPrint('Cannot delete "Total Balance" account.');
      return;
    }

    _accounts.removeWhere((AccountSummary acc) => acc.id == accountId);
    _events.removeWhere((Event event) => event.accountId == accountId);
    _tools.removeWhere((Tool tool) => tool.accountId == accountId);

    if (_activeAccountId == accountId) {
      _activeAccountId = 'total'; // Reset active account if deleted
    }
    _deletableAccountId = null; // Exit delete mode
    _updateTotalBalance(); // Recalculate total balance
    notifyListeners();
  }

  /// Adds a new account.
  void addAccount(
    String name,
    double initialBalance,
    int colorValue,
    AccountType type,
    bool hideEvents, // New parameter
    bool excludeFromTotal, // New parameter
  ) {
    final String newId = DateTime.now().microsecondsSinceEpoch.toString();
    final AccountSummary newAccount = AccountSummary(
      id: newId,
      name: name,
      balance: initialBalance,
      dailyChangeAmount: 0.0,
      dailyChangePercentage: 0.0,
      colorValue: colorValue,
      type: type,
      hideEvents: hideEvents, // Pass the selected hideEvents value
      excludeFromTotal: excludeFromTotal, // Pass the selected excludeFromTotal value
    );
    _accounts.add(newAccount);

    // Initial money tool if needed (simplified from previous logic)
    _tools.add(
      Tool(
        name: 'Russian Ruble', // Descriptive name for cash
        quantity: initialBalance.abs(), // Quantity should be positive
        percentageChange: 0.0, // Initial cash has no change
        accountId: newId,
        type: ToolType.money,
        currentValue: initialBalance,
        ticker: 'RUR', // Specific ticker as requested
      ),
    );

    _activeAccountId = newId; // Make the newly added account active
    _updateTotalBalance(); // Recalculates total and notifies listeners
    notifyListeners(); // Notify for accounts list change
  }

  /// Adds a new money tool to a specified account.
  void addMoneyTool(String accountId, String name, double quantity,
      String currencyTicker, double unitPrice) {
    final AccountSummary? account = getAccountById(accountId);
    if (account != null && account.id != 'total') {
      final double currentValue = quantity * unitPrice;
      _tools.add(
        Tool(
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
      notifyListeners(); // Notify for tools list change
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
          'Cannot add deposit to "Total Balance" or non-existent account.');
      return;
    }

    final Tool? withdrawalTool = _tools.cast<Tool?>().firstWhere(
          (Tool? tool) =>
              tool != null &&
              tool.accountId == accountId &&
              tool.type == ToolType.money &&
              tool.name == withdrawalToolName,
          orElse: () => null,
        );

    if (withdrawalTool == null) {
      debugPrint(
          'Withdrawal money tool "$withdrawalToolName" not found in account "$accountId".');
      return;
    }

    if (withdrawalTool.quantity < quantity) {
      debugPrint(
          'Insufficient funds in ${withdrawalTool.name} to create deposit.');
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
      Tool(
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

    // Add an event for the deposit creation (as an outflow from the money tool)
    _events.add(
      Event(
        description: 'Deposit: "$name" created (from ${withdrawalTool.name})',
        amount: withdrawalValue, // Record the value of outflow
        isCredit: false, // Outflow from existing money tool
        accountId: accountId,
        date: DateTime.now(),
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
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
    required String transferToMoneyToolName, // Name of the money tool to transfer funds to
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint('Cannot add credit to "Total Balance" or non-existent account.');
      return;
    }

    // Find the money tool to transfer funds to
    final Tool? transferToTool = _tools.cast<Tool?>().firstWhere(
          (Tool? tool) =>
              tool != null &&
              tool.accountId == accountId &&
              tool.type == ToolType.money &&
              tool.name == transferToMoneyToolName,
          orElse: () => null,
        );

    if (transferToTool == null) {
      debugPrint(
          'Target money tool "$transferToMoneyToolName" not found in account "$accountId".');
      return;
    }

    // Update the balance of the target money tool
    // Assuming amount is in RUB, update value and calculate quantity increase
    final double effectiveRatePerUnit = transferToTool.quantity > 0
        ? transferToTool.currentValue / transferToTool.quantity
        : (transferToTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    transferToTool.currentValue += amount; // Amount is in RUB
    if (effectiveRatePerUnit > 0) {
      transferToTool.quantity += (amount / effectiveRatePerUnit);
    }

    // Add the new credit tool (as a liability, hence negative current value)
    _tools.add(
      Tool(
        name: name,
        quantity: 1.0, // Represents one credit agreement
        percentageChange: -interestRate, // Annual interest rate as negative change
        accountId: accountId,
        type: ToolType.credit,
        currentValue: -amount, // Principal amount as a negative liability (in RUB)
        interestRate: interestRate,
        loanStartDate: loanStartDate,
        loanTermMonths: loanTermMonths,
        paymentDayOfMonth: paymentDayOfMonth,
        creditPaymentType: creditPaymentType,
      ),
    );

    // Add an event for the credit creation (as an inflow to the account)
    _events.add(
      Event(
        description: 'Credit: "$name" received (to ${transferToTool.name})',
        amount: amount,
        isCredit: true, // Inflow from credit
        accountId: accountId,
        date: DateTime.now(),
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Adds a new 'other' tool to a specified account.
  /// Deducts the specified amount from a selected money tool within the same account.
  void addOtherTool({
    required String accountId,
    required String name,
    required double amount, // Amount to be converted/used for the new tool (in RUB)
    required String withdrawalToolName, // Name of the money tool to deduct from
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint('Cannot add other tool to "Total Balance" or non-existent account.');
      return;
    }

    final Tool? withdrawalTool = _tools.cast<Tool?>().firstWhere(
          (Tool? tool) =>
              tool != null &&
              tool.accountId == accountId &&
              tool.type == ToolType.money &&
              tool.name == withdrawalToolName,
          orElse: () => null,
        );

    if (withdrawalTool == null) {
      debugPrint(
          'Withdrawal money tool "$withdrawalToolName" not found in account "$accountId".');
      return;
    }

    // Calculate actual value being withdrawn (in RUB) based on the current effective rate of the withdrawal tool
    final double withdrawalToolUnitPrice = withdrawalTool.quantity > 0
        ? (withdrawalTool.currentValue / withdrawalTool.quantity)
        : (withdrawalTool.ticker == 'USD' ? 90.0 : 1.0);

    if (withdrawalTool.currentValue < amount) {
      // Compare in RUB
      debugPrint(
          'Insufficient funds in ${withdrawalTool.name} for this other tool.');
      // Allowing to go negative for demonstration
    }

    // Deduct value and quantity from the withdrawal money tool
    withdrawalTool.currentValue -= amount; // Amount is in RUB
    if (withdrawalToolUnitPrice > 0) {
      withdrawalTool.quantity -= (amount / withdrawalToolUnitPrice);
    }

    // Add the new 'other' tool
    _tools.add(
      Tool(
        name: name,
        quantity: amount /
            withdrawalToolUnitPrice, // Quantity based on how many units of the original tool were "converted"
        percentageChange: 0.0, // Initial change for 'other' tool
        accountId: accountId,
        type: ToolType.other,
        currentValue: amount, // Value in RUB
        ticker: withdrawalTool.ticker, // Ticker from the withdrawal tool
      ),
    );

    // Add an event for the 'other' tool creation (as an outflow from the money tool)
    _events.add(
      Event(
        description: 'Other Tool: "$name" created (from ${withdrawalTool.name})',
        amount: amount, // Record the value of outflow in RUB
        isCredit: false, // Outflow from existing money tool
        accountId: accountId,
        date: DateTime.now(),
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Toggles the hideEvents flag for a specific account.
  void toggleHideEvents(String accountId) {
    final AccountSummary? account = getAccountById(accountId);
    if (account != null && account.id != 'total') {
      account.hideEvents = !account.hideEvents;
      notifyListeners(); // Notify listeners to update UI
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
      notifyListeners(); // Notify listeners to update UI
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
    required double amount, // This amount is the increase in VALUE (RUB equivalent)
    required DateTime date,
    required String category,
    String? comment,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint('Cannot add income to "Total Balance" or non-existent account.');
      return;
    }

    final Tool? targetTool = _tools.cast<Tool?>().firstWhere(
          (Tool? tool) =>
              tool != null &&
              tool.accountId == accountId &&
              tool.type == ToolType.money &&
              tool.name == toolName,
          orElse: () => null,
        );

    if (targetTool == null) {
      debugPrint('Target money tool "$toolName" not found in account "$accountId".');
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
        effectiveRatePerUnit = 90.0; // Assuming a fixed or average USD rate for income
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
          'Warning: Effective unit price for tool ${targetTool.name} is zero/negative, cannot update quantity correctly for income.');
    }

    _events.add(
      Event(
        description: '$category${comment != null && comment.isNotEmpty ? ' ($comment)' : ''}',
        amount: amount,
        isCredit: true,
        accountId: accountId,
        date: date,
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Adds a new expense event, updating a specific money tool and the account balance.
  /// The 'amount' is expected to be in the base currency (RUB).
  void addExpense({
    required String accountId,
    required String toolName,
    required double amount, // This amount is the decrease in VALUE (RUB equivalent)
    required DateTime date,
    required String category,
    String? comment,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total') {
      debugPrint('Cannot add expense to "Total Balance" or non-existent account.');
      return;
    }

    final Tool? targetTool = _tools.cast<Tool?>().firstWhere(
          (Tool? tool) =>
              tool != null &&
              tool.accountId == accountId &&
              tool.type == ToolType.money &&
              tool.name == toolName,
          orElse: () => null,
        );

    if (targetTool == null) {
      debugPrint('Target money tool "$toolName" not found in account "$accountId".');
      return;
    }

    // Calculate the 'unit price' to correctly update quantity for non-RUR currencies.
    double effectiveRatePerUnit = 1.0; // Default for RUR
    if (targetTool.ticker == 'USD') {
      if (targetTool.quantity > 0) {
        effectiveRatePerUnit = targetTool.currentValue / targetTool.quantity;
      } else {
        // Fallback rate if tool is empty or quantity is zero.
        effectiveRatePerUnit = 90.0; // Assuming a fixed or average USD rate for expense
      }
    }

    // Check for sufficient funds. This is a simple check; more robust handling might involve
    // allowing overdrafts and marking the account as overdrawn.
    if (amount > 0 && targetTool.currentValue < amount) {
      debugPrint('Warning: Insufficient funds in ${targetTool.name} to cover this expense.');
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
          'Warning: Effective unit price for tool ${targetTool.name} is zero/negative, cannot update quantity correctly for expense.');
    }

    _events.add(
      Event(
        description: '$category${comment != null && comment.isNotEmpty ? ' ($comment)' : ''}',
        amount: amount,
        isCredit: false, // Expense
        accountId: accountId,
        date: date,
      ),
    );

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Helper to get the default money tool for an account (preferably RUR, else any).
  Tool? _getDefaultMoneyToolForAccount(String accountId) {
    final List<Tool> moneyTools = getMoneyToolsForAccount(accountId);
    // Prefer Russian Ruble tool
    final Tool? rurTool = moneyTools.cast<Tool?>().firstWhere(
        (Tool? tool) => tool != null && tool.ticker == 'RUR',
        orElse: () => null);
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
    if (account == null || account.id == 'total' || account.type != AccountType.brokerage) {
      debugPrint('Cannot buy stock for "Total Balance" or non-brokerage/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to deduct funds from.');
      return;
    }

    final double totalCost = (quantity * pricePerUnit) + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $stockName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for stock purchase.');
    }

    Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.stocks,
        orElse: () => null);

    if (existingTool != null) {
      // Update existing stock holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
    } else {
      // Add new stock tool
      _tools.add(
        Tool(
          name: stockName,
          quantity: quantity,
          percentageChange: 0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.stocks,
          currentValue: quantity * pricePerUnit,
          ticker: ticker,
        ),
      );
    }

    _events.add(
      Event(
        description: 'Buy $quantity $ticker ($stockName) @ ${formatCurrency(pricePerUnit)}',
        amount: quantity * pricePerUnit,
        isCredit: false, // Expense
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Stock Buy Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Sells a specified quantity of a stock for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  void sellStock({
    required String accountId,
    required String ticker,
    required String stockName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total' || account.type != AccountType.brokerage) {
      debugPrint('Cannot sell stock for "Total Balance" or non-brokerage/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to receive funds.');
      return;
    }

    final Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.stocks,
        orElse: () => null);

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
          'Insufficient quantity of $ticker in ${account.name} to sell.');
      // Should prevent transaction or show an error
      return;
    }

    final double totalProceeds = (quantity * pricePerUnit) - commission;

    // Update existing stock holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for stock sale.');
    }

    _events.add(
      Event(
        description: 'Sell $quantity $ticker ($stockName) @ ${formatCurrency(pricePerUnit)}',
        amount: quantity * pricePerUnit,
        isCredit: true, // Income
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Stock Sell Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere((Tool tool) => tool.ticker == ticker && tool.accountId == accountId && tool.type == ToolType.stocks);
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
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
    if (account == null || account.id == 'total' || account.type != AccountType.brokerage) {
      debugPrint('Cannot buy ETF for "Total Balance" or non-brokerage/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to deduct funds from.');
      return;
    }

    final double totalCost = (quantity * pricePerUnit) + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $etfName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for ETF purchase.');
    }

    Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.etf,
        orElse: () => null);

    if (existingTool != null) {
      // Update existing ETF holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
    } else {
      // Add new ETF tool
      _tools.add(
        Tool(
          name: etfName,
          quantity: quantity,
          percentageChange: 0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.etf,
          currentValue: quantity * pricePerUnit,
          ticker: ticker,
        ),
      );
    }

    _events.add(
      Event(
        description: 'Buy $quantity $ticker ($etfName) @ ${formatCurrency(pricePerUnit)}',
        amount: quantity * pricePerUnit,
        isCredit: false, // Expense
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'ETF Buy Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Sells a specified quantity of an ETF for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  void sellEtf({
    required String accountId,
    required String ticker,
    required String etfName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total' || account.type != AccountType.brokerage) {
      debugPrint('Cannot sell ETF for "Total Balance" or non-brokerage/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to receive funds.');
      return;
    }

    final Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.etf,
        orElse: () => null);

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
          'Insufficient quantity of $ticker in ${account.name} to sell.');
      // Should prevent transaction or show an error
      return;
    }

    final double totalProceeds = (quantity * pricePerUnit) - commission;

    // Update existing ETF holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for ETF sale.');
    }

    _events.add(
      Event(
        description: 'Sell $quantity $ticker ($etfName) @ ${formatCurrency(pricePerUnit)}',
        amount: quantity * pricePerUnit,
        isCredit: true, // Income
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'ETF Sell Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere((Tool tool) => tool.ticker == ticker && tool.accountId == accountId && tool.type == ToolType.etf);
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
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
    if (account == null || account.id == 'total' || account.type != AccountType.brokerage) {
      debugPrint('Cannot buy bond for "Total Balance" or non-brokerage/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to deduct funds from.');
      return;
    }

    final double totalCost =
        (quantity * pricePerUnit) + accruedCouponIncome + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $bondName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for bond purchase.');
    }

    Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.bonds,
        orElse: () => null);

    if (existingTool != null) {
      // Update existing bond holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
      // Face value is usually constant for a given bond type, assume it matches
      // If it can change, a more complex update or separate bond series might be needed.
    } else {
      // Add new bond tool
      _tools.add(
        Tool(
          name: bondName,
          quantity: quantity,
          percentageChange: 0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.bonds,
          currentValue: quantity * pricePerUnit, // Current value is market value
          ticker: ticker,
          faceValue: faceValue, // Store nominal value
        ),
      );
    }

    _events.add(
      Event(
        description: 'Buy $quantity $ticker ($bondName) @ ${formatCurrency(pricePerUnit)} + ACI ${formatCurrency(accruedCouponIncome)}',
        amount: totalCost, // Record full cost as event amount
        isCredit: false, // Expense
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Bond Buy Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    _updateTotalBalance();
    notifyListeners();
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
    if (account == null || account.id == 'total' || account.type != AccountType.brokerage) {
      debugPrint('Cannot sell bond for "Total Balance" or non-brokerage/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to receive funds.');
      return;
    }

    final Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.bonds,
        orElse: () => null);

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint('Insufficient quantity of $ticker in ${account.name} to sell.');
      return;
    }

    final double totalProceeds =
        (quantity * pricePerUnit) + accruedCouponIncome - commission;

    // Update existing bond holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for bond sale.');
    }

    _events.add(
      Event(
        description: 'Sell $quantity $ticker ($bondName) @ ${formatCurrency(pricePerUnit)} + ACI ${formatCurrency(accruedCouponIncome)}',
        amount: totalProceeds, // Record full proceeds as event amount
        isCredit: true, // Income
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Bond Sell Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere((Tool tool) => tool.ticker == ticker && tool.accountId == accountId && tool.type == ToolType.bonds);
    }

    _updateTotalBalance();
    notifyListeners();
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
    if (account == null || account.id == 'total' || account.type != AccountType.cryptocurrency) {
      debugPrint('Cannot buy cryptocurrency for "Total Balance" or non-cryptocurrency/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to deduct funds from.');
      return;
    }

    final double totalCost = (quantity * pricePerUnit) + commission;

    if (moneyTool.currentValue < totalCost) {
      debugPrint('Insufficient funds in ${moneyTool.name} to buy $cryptoName.');
      // Allow for now, but in a real app, this should prevent the transaction or warn user.
    }

    // Deduct from money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue -= totalCost;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity -= (totalCost / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for crypto purchase.');
    }

    Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.cryptocurrency,
        orElse: () => null);

    if (existingTool != null) {
      // Update existing crypto holding
      existingTool.quantity += quantity;
      existingTool.currentValue += (quantity * pricePerUnit);
    } else {
      // Add new crypto tool
      _tools.add(
        Tool(
          name: cryptoName,
          quantity: quantity,
          percentageChange: 0.0, // Initial purchase has no immediate percentage change
          accountId: accountId,
          type: ToolType.cryptocurrency,
          currentValue: quantity * pricePerUnit,
          ticker: ticker,
        ),
      );
    }

    _events.add(
      Event(
        description: 'Buy $quantity $ticker ($cryptoName) @ ${formatCurrency(pricePerUnit)}',
        amount: quantity * pricePerUnit,
        isCredit: false, // Expense
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Crypto Buy Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }

  /// Sells a specified quantity of a cryptocurrency for an account.
  /// Adds total proceeds to the *money tool* of the active account.
  void sellCrypto({
    required String accountId,
    required String ticker,
    required String cryptoName, // For event description, not strictly needed for lookup
    required double quantity,
    required double pricePerUnit,
    required double commission,
    required DateTime date,
  }) {
    final AccountSummary? account = getAccountById(accountId);
    if (account == null || account.id == 'total' || account.type != AccountType.cryptocurrency) {
      debugPrint('Cannot sell cryptocurrency for "Total Balance" or non-cryptocurrency/non-existent account.');
      return;
    }

    final Tool? moneyTool = _getDefaultMoneyToolForAccount(accountId);
    if (moneyTool == null) {
      debugPrint('No money tool found in account "$accountId" to receive funds.');
      return;
    }

    final Tool? existingTool = _tools.cast<Tool?>().firstWhere(
        (Tool? tool) =>
            tool != null &&
            tool.ticker == ticker &&
            tool.accountId == accountId &&
            tool.type == ToolType.cryptocurrency,
        orElse: () => null);

    if (existingTool == null || existingTool.quantity < quantity) {
      debugPrint(
          'Insufficient quantity of $ticker in ${account.name} to sell.');
      // Should prevent transaction or show an error
      return;
    }

    final double totalProceeds = (quantity * pricePerUnit) - commission;

    // Update existing crypto holding
    existingTool.quantity -= quantity;
    existingTool.currentValue -= (quantity * pricePerUnit);

    // Add proceeds to money tool
    final double moneyToolUnitPrice = moneyTool.quantity > 0
        ? moneyTool.currentValue / moneyTool.quantity
        : (moneyTool.ticker == 'USD' ? 90.0 : 1.0); // Fallback rate

    moneyTool.currentValue += totalProceeds;
    if (moneyToolUnitPrice > 0) {
      moneyTool.quantity += (totalProceeds / moneyToolUnitPrice);
    } else {
      debugPrint(
          'Warning: Money tool ${moneyTool.name} has zero/negative effective unit price, cannot update quantity for crypto sale.');
    }

    _events.add(
      Event(
        description: 'Sell $quantity $ticker ($cryptoName) @ ${formatCurrency(pricePerUnit)}',
        amount: quantity * pricePerUnit,
        isCredit: true, // Income
        accountId: accountId,
        date: date,
      ),
    );

    if (commission > 0) {
      _events.add(
        Event(
          description: 'Crypto Sell Commission ($ticker)',
          amount: commission,
          isCredit: false, // Expense
          accountId: accountId,
          date: date,
        ),
      );
    }

    // Remove tool if quantity drops to zero or below
    if (existingTool.quantity <= 0) {
      _tools.removeWhere((Tool tool) => tool.ticker == ticker && tool.accountId == accountId && tool.type == ToolType.cryptocurrency);
    }

    _updateTotalBalance(); // Will update account balance based on new tool values
    notifyListeners();
  }
}

/// Helper function to get an icon for AccountType.
IconData _getAccountIcon(AccountType type) {
  switch (type) {
    case AccountType.general:
      return Icons.account_balance_wallet;
    case AccountType.brokerage:
      return Icons.bar_chart;
    case AccountType.cryptocurrency:
      return Icons.currency_bitcoin;
  }
}

/// A widget to display a single account summary card.
class AccountCard extends StatelessWidget {
  final AccountSummary account;

  const AccountCard({
    Key? key,
    required this.account,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors based on account data for aesthetics and readability
    final Color cardColor = Color(account.colorValue);
    final Color textColor =
        cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color positiveChangeColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.8);
    final Color negativeChangeColor = Theme.of(context).colorScheme.error;

    return Consumer<AccountData>(
      builder: (BuildContext context, AccountData accountData, Widget? child) {
        final bool isDeletable = accountData.isAccountDeletable(account.id);
        final bool canBeDeleted = account.id != 'total';

        return GestureDetector(
          onTap: () {
            if (isDeletable) {
              // If this card is in delete mode, tapping it exits delete mode
              accountData.clearDeletableAccount();
            } else {
              // If not in delete mode, or another card was in delete mode,
              // first clear delete mode, then set active account.
              accountData.clearDeletableAccount();
              accountData.setActiveAccount(account.id);
            }
          },
          onLongPress: canBeDeleted
              ? () {
                  accountData.setDeletableAccount(account.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Long pressed ${account.name} for deletion/settings.'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              : null, // No long press for 'total' account
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 110, // Fixed height for each card
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2), // changes position of shadow
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Row(
                      // Row for icon and account name
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          _getAccountIcon(account.type),
                          color: textColor.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            account.name,
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Expanded(
                          // Use Expanded to prevent overflow for long numbers
                          child: Text(
                            formatCurrency(account.balance),
                            textAlign:
                                TextAlign.start, // Align to start for currency
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                          ),
                        ),
                        // Only show chart icon for non-total accounts, statistics for total
                        if (account.id != 'total')
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'View Account Chart (Not Implemented)')),
                                );
                              },
                              child: Icon(Icons.show_chart,
                                  color: textColor, size: 20),
                            ),
                          )
                        else if (account.id == 'total')
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'View Total Statistics (Not Implemented)')),
                                );
                              },
                              child: Icon(Icons.bar_chart,
                                  color: textColor, size: 20),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Text(
                            '${account.dailyChangeAmount >= 0 ? '+' : ''}${formatCurrency(account.dailyChangeAmount)}',
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: account.dailyChangeAmount >= 0
                                      ? positiveChangeColor
                                      : negativeChangeColor,
                                ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              "|",
                              textAlign: TextAlign.start,
                              overflow: TextOverflow.clip,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                            ),
                          ),
                          Text(
                            '${account.dailyChangePercentage >= 0 ? '+' : ''}${account.dailyChangePercentage.toStringAsFixed(2)}%',
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: account.dailyChangePercentage >= 0
                                      ? positiveChangeColor
                                      : negativeChangeColor,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Display icons at bottom-left when not in delete mode
                if (account.id != 'total' && !isDeletable)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          account.hideEvents
                              ? Icons.notifications_off
                              : Icons.notifications,
                          color: textColor.withOpacity(0.8),
                          size: 20,
                        ),
                        // New: Icon for 'excludeFromTotal' if true
                        if (account.excludeFromTotal)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.visibility_off,
                              color: textColor.withOpacity(0.8),
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (isDeletable && canBeDeleted) ...<Widget>[
                  Positioned(
                    top: -12,
                    right: -15, // Rightmost position
                    child: IconButton(
                      icon: Icon(Icons.delete_forever,
                          color: Theme.of(context).colorScheme.error, size: 28),
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: Text(
                                  'Are you sure you want to delete ${account.name} and all its associated transactions and tools? This action cannot be undone.'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop(false);
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop(true);
                                  },
                                  child: Text('Delete',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirm == true) {
                          accountData.deleteAccount(account.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${account.name} deleted successfully.'),
                                duration: const Duration(seconds: 1)),
                          );
                        } else {
                          accountData
                              .clearDeletableAccount(); // Exit delete mode if cancelled
                        }
                      },
                    ),
                  ),
                  Positioned(
                    top: -12,
                    right: 25, // To the left of delete button
                    child: IconButton(
                      icon: Icon(
                          account.hideEvents
                              ? Icons.notifications_off
                              : Icons.notifications,
                          color: textColor,
                          size: 28),
                      onPressed: () {
                        accountData.toggleHideEvents(account.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Events for ${account.name} are now ${account.hideEvents ? 'hidden' : 'visible'}.'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: -12,
                    right: 65, // To the left of notification button
                    child: IconButton(
                      icon: Icon(
                          account.excludeFromTotal
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: textColor,
                          size: 28),
                      onPressed: () {
                        accountData.toggleExcludeFromTotal(account.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${account.name} is now ${account.excludeFromTotal ? 'excluded from' : 'included in'} Total Balance calculation.'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A widget to display a single financial event/transaction.
class EventTile extends StatelessWidget {
  final Event event;
  final AccountData accountData;

  const EventTile({
    Key? key,
    required this.event,
    required this.accountData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String accountName =
        accountData.getAccountById(event.accountId)?.name ?? "Unknown";
    final bool isPastEvent = event.date.isBefore(DateTime.now());
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0, // Flat design
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      // Highlight past events with a distinct background color
      color: isPastEvent ? colorScheme.surfaceVariant : colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: <Widget>[
            Icon(
              event.isCredit ? Icons.arrow_upward : Icons.arrow_downward,
              color: event.isCredit ? colorScheme.primary : colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(event.date)} - $accountName',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${event.isCredit ? '+' : '-'}${formatCurrency(event.amount.abs())}',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: event.isCredit
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget to display a list of financial events.
class EventList extends StatelessWidget {
  final AccountData accountData;
  final int maxEvents;

  const EventList({
    Key? key,
    required this.accountData,
    this.maxEvents = 10, // Changed default to showing top 10 events
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Event> events = accountData.allEvents;

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No recent events to display.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // To allow parent SingleChildScrollView to scroll
      itemCount: events.length > maxEvents ? maxEvents : events.length,
      itemBuilder: (BuildContext context, int index) {
        final Event event = events[index];
        return EventTile(event: event, accountData: accountData);
      },
    );
  }
}

/// A widget to display a single financial tool/asset.
class ToolTile extends StatelessWidget {
  final Tool tool;

  const ToolTile({
    Key? key,
    required this.tool,
  }) : super(key: key);

  IconData _getToolIcon(ToolType type) {
    switch (type) {
      case ToolType.money:
        return Icons.money;
      case ToolType.deposit:
        return Icons.account_balance;
      case ToolType.credit:
        return Icons.credit_card;
      case ToolType.stocks:
        return Icons.trending_up;
      case ToolType.bonds:
        return Icons.receipt_long;
      case ToolType.etf:
        return Icons.auto_graph;
      case ToolType.cryptocurrency:
        return Icons.currency_bitcoin;
      case ToolType.other:
        return Icons.category;
    }
  }

  String _getPayoutTypeDisplayName(PayoutType type) {
    switch (type) {
      case PayoutType.atEndOfTerm:
        return 'В конце срока';
      case PayoutType.monthly:
        return 'Ежемесячно';
      case PayoutType.monthlyToWithdrawalAccount:
        return 'Ежемесячно на счет списания';
    }
  }

  String _getCreditPaymentTypeDisplayName(CreditPaymentType type) {
    switch (type) {
      case CreditPaymentType.annuity:
        return 'Аннуитетный (Annuity)';
      case CreditPaymentType.differentiated:
        return 'Дифференцированный (Differentiated)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color positiveChangeColor = colorScheme.primary.withOpacity(0.8);
    final Color negativeChangeColor = colorScheme.error;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: <Widget>[
            Icon(
              _getToolIcon(tool.type),
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tool.name,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (tool.ticker != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            tool.ticker!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        '${tool.quantity.toStringAsFixed(2)} шт.',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (tool.type == ToolType.deposit && tool.startDate != null)
                    Text(
                      '${DateFormat('MMM d, yyyy').format(tool.startDate!)} - ${DateFormat('MMM d, yyyy').format(tool.endDate!)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.deposit && tool.payoutType != null)
                    Text(
                      _getPayoutTypeDisplayName(tool.payoutType!),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.credit && tool.loanStartDate != null)
                    Text(
                      'Start: ${DateFormat('MMM d, yyyy').format(tool.loanStartDate!)} - ${tool.loanTermMonths} Months',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.credit &&
                      tool.paymentDayOfMonth != null &&
                      tool.creditPaymentType != null)
                    Text(
                      'Pay on Day ${tool.paymentDayOfMonth} (${_getCreditPaymentTypeDisplayName(tool.creditPaymentType!)})',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.credit && tool.interestRate != null)
                    Text(
                      'Interest: ${tool.interestRate!.toStringAsFixed(2)}% APY',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (tool.type == ToolType.bonds && tool.faceValue != null)
                    Text(
                      'Nominal: ${formatCurrency(tool.faceValue!)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatCurrency(tool.currentValue),
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tool.currentValue >= 0
                            ? colorScheme.onSurface
                            : colorScheme.error,
                      ),
                ),
                if (tool.percentageChange != 0) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${tool.percentageChange >= 0 ? '+' : ''}${tool.percentageChange.toStringAsFixed(2)}% ${tool.type == ToolType.deposit ? '(APY)' : ''}',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tool.percentageChange >= 0
                              ? positiveChangeColor
                              : negativeChangeColor,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget to display a list of financial tools.
class ToolList extends StatelessWidget {
  final AccountData accountData;
  final String accountId;

  const ToolList({
    Key? key,
    required this.accountData,
    required this.accountId,
  }) : super(key: key);

  String _getToolTypeDisplayName(ToolType type) {
    switch (type) {
      case ToolType.money:
        return 'Cash & Currencies';
      case ToolType.deposit:
        return 'Deposits';
      case ToolType.credit:
        return 'Credits & Loans';
      case ToolType.stocks:
        return 'Stocks';
      case ToolType.bonds:
        return 'Bonds';
      case ToolType.etf:
        return 'ETFs';
      case ToolType.cryptocurrency:
        return 'Cryptocurrencies';
      case ToolType.other:
        return 'Other Assets';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Tool> tools = accountData.getToolsForAccount(accountId);

    if (tools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No financial tools for this account.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Group tools by type
    final Map<ToolType, List<Tool>> groupedTools = {};
    for (final Tool tool in tools) {
      groupedTools.putIfAbsent(tool.type, () => <Tool>[]).add(tool);
    }

    // Sort group keys for consistent display order
    final List<ToolType> sortedTypes = groupedTools.keys.toList()
      ..sort((ToolType a, ToolType b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedTypes.map<Widget>((ToolType type) {
        final List<Tool> toolsInGroup = groupedTools[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 8),
              child: Text(
                _getToolTypeDisplayName(type),
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
              ),
            ),
            ...toolsInGroup
                .map<Widget>((Tool tool) => ToolTile(tool: tool))
                .toList(),
          ],
        );
      }).toList(),
    );
  }
}

/// Helper function to get display name for AccountType.
String _getAccountTypeDisplayName(AccountType type) {
  switch (type) {
    case AccountType.general:
      return 'General Account';
    case AccountType.brokerage:
      return 'Brokerage Account';
    case AccountType.cryptocurrency:
      return 'Cryptocurrency Account';
  }
}

/// Helper function to get display name for PayoutType.
String _getPayoutTypeDisplayName(PayoutType type) {
  switch (type) {
    case PayoutType.atEndOfTerm:
      return 'В конце срока';
    case PayoutType.monthly:
      return 'Ежемесячная выплата';
    case PayoutType.monthlyToWithdrawalAccount:
      return 'Ежемесячная выплата на счет списания';
  }
}

/// Helper function to get display name for CreditPaymentType.
String _getCreditPaymentTypeDisplayName(CreditPaymentType type) {
  switch (type) {
    case CreditPaymentType.annuity:
      return 'Аннуитетный (Annuity)';
    case CreditPaymentType.differentiated:
      return 'Дифференцированный (Differentiated)';
  }
}

/// A modal bottom sheet for selecting a financial action.
class ActionSelectionBottomSheet extends StatelessWidget {
  final String activeAccountId;

  const ActionSelectionBottomSheet({super.key, required this.activeAccountId});

  @override
  Widget build(BuildContext context) {
    final AccountData accountData = Provider.of<AccountData>(context);
    final AccountSummary? activeAccount =
        accountData.getAccountById(activeAccountId);
    final bool isGeneralAccount =
        activeAccount != null && activeAccount.type == AccountType.general;
    final bool isBrokerageAccount =
        activeAccount != null && activeAccount.type == AccountType.brokerage;
    final bool isCryptocurrencyAccount = // NEW
        activeAccount != null && activeAccount.type == AccountType.cryptocurrency;
    final bool hasMoneyTools =
        accountData.getMoneyToolsForAccount(activeAccountId).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              "Choose Action",
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.arrow_upward,
                color: Theme.of(context).colorScheme.primary),
            title: Text(
              "Доход (Income)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () {
              Navigator.pop(context); // Close the bottom sheet
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: AddIncomeForm(accountId: activeAccountId),
                  );
                },
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20.0)),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.arrow_downward,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              "Расход (Expense)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () {
              Navigator.pop(context); // Close the bottom sheet
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: AddExpenseForm(accountId: activeAccountId),
                  );
                },
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20.0)),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
              );
            },
          ),
          if (hasMoneyTools) // Conditionally show Transfer action
            ListTile(
              leading: Icon(Icons.swap_horiz,
                  color: Theme.of(context).colorScheme.secondary),
              title: Text(
                "Перевод (Transfer)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddTransferForm(activeAccountId: activeAccountId),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          if (isGeneralAccount) // Only show for general accounts
            ListTile(
              leading: Icon(Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.secondary),
              title: Text(
                "Добавить инструмент (Деньги)", // Add Money Tool
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddMoneyToolForm(accountId: activeAccountId),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          if (isGeneralAccount) // Only show for general accounts
            ListTile(
              leading: Icon(Icons.savings,
                  color: Theme.of(context).colorScheme.secondary),
              title: Text(
                "Добавить депозит", // Add Deposit
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddDepositForm(accountId: activeAccountId),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          if (isGeneralAccount) // Only show for general accounts
            ListTile(
              leading: Icon(Icons.credit_score,
                  color: Theme.of(context).colorScheme.secondary),
              title: Text(
                "Добавить кредит (Add Credit)", // New: Add Credit
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child:
                          AddCreditForm(accountId: activeAccountId), // New form for credit
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          if (isGeneralAccount) // Only show for general accounts
            ListTile(
              leading: Icon(Icons.category,
                  color: Theme.of(context).colorScheme.secondary),
              title: Text(
                "Добавить инструмент (Прочее)", // Add Other Tool
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child:
                          AddOtherToolForm(accountId: activeAccountId), // New form for other tool
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          if (isBrokerageAccount) ...<Widget>[
            // New: Actions for Brokerage accounts
            ListTile(
              leading: Icon(Icons.add_shopping_cart,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(
                "Купить Акции (Buy Stocks)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType: ToolType.stocks,
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.sell,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                "Продать Акции (Sell Stocks)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType: ToolType.stocks,
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
            // New: ETF Actions
            ListTile(
              leading: Icon(Icons.add_chart,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(
                "Купить ETF (Buy ETF)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType: ToolType.etf,
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.trending_down,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                "Продать ETF (Sell ETF)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType: ToolType.etf,
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
            // New: Bond Actions
            ListTile(
              leading: Icon(Icons.attach_money,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(
                "Купить Облигации (Buy Bonds)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType: ToolType.bonds,
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.money_off_csred,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                "Продать Облигации (Sell Bonds)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType: ToolType.bonds,
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          ],
          // NEW: Cryptocurrency Actions
          if (isCryptocurrencyAccount) ...<Widget>[
            ListTile(
              leading: Icon(Icons.currency_bitcoin,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(
                "Купить Криптовалюту (Buy Crypto)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.buy,
                        investmentType:
                            ToolType.cryptocurrency, // Specify crypto type
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.currency_yen, // Using yen for selling crypto
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                "Продать Криптовалюту (Sell Crypto)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddInvestmentOperationForm(
                        accountId: activeAccountId,
                        operationType: InvestmentOperationType.sell,
                        investmentType:
                            ToolType.cryptocurrency, // Specify crypto type
                      ),
                    );
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                );
              },
            ),
          ],
          ListTile(
            leading: Icon(Icons.list_alt,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            title: Text(
              "Посмотреть активности по счету",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () {
              Navigator.pop(context); // Close the bottom sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('View account activities selected')),
              );
              // TODO: Navigate to All Events screen (or specific account events)
            },
          ),
          const SizedBox(height: 8.0), // Some bottom padding
        ],
      ),
    );
  }
}

/// A modal bottom sheet for creating a new account.
class AddAccountForm extends StatefulWidget {
  const AddAccountForm({super.key});

  @override
  State<AddAccountForm> createState() => _AddAccountFormState();
}

class _AddAccountFormState extends State<AddAccountForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  int _selectedColorValue = 0xff007BFF; // Default color: Vibrant blue
  AccountType _selectedAccountType = AccountType.general; // Default account type
  bool _hideEventsInitial = false; // New state for initial hideEvents value
  bool _excludeFromTotalInitial =
      false; // New state for initial excludeFromTotal value

  final List<Map<String, Object>> _availableColors = const <Map<String, Object>>[
    {'name': 'Vibrant Blue', 'value': 0xff007BFF},
    {'name': 'Strong Green', 'value': 0xff28A745},
    {'name': 'Deep Yellow', 'value': 0xffFFC107},
    {'name': 'Cyan', 'value': 0xff17A2B8},
    {'name': 'Orange', 'value': 0xffFD7E14},
    {'name': 'Indigo', 'value': 0xff6610F2},
    {'name': 'Deep Purple', 'value': 0xff6A0DAD}, // Total balance color
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _createAccount() {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text.trim();
      final double initialBalance = double.parse(_balanceController.text);

      Provider.of<AccountData>(context, listen: false).addAccount(
        name,
        initialBalance,
        _selectedColorValue,
        _selectedAccountType,
        _hideEventsInitial, // Pass the selected hideEvents value
        _excludeFromTotalInitial, // Pass the selected excludeFromTotal value
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account "$name" created successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Create New Account",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.account_balance_wallet,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an account name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Initial Balance',
                  hintText: 'e.g., 1000.50 or -500.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.currency_ruble,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an initial balance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  // Removed the negative balance check here to allow liabilities
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Account Type:',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                value: _selectedAccountType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.category, color: colorScheme.onSurfaceVariant),
                ),
                items: AccountType.values
                    .map<DropdownMenuItem<AccountType>>((AccountType type) {
                  return DropdownMenuItem<AccountType>(
                    value: type,
                    child: Text(_getAccountTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (AccountType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedAccountType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  'Hide Events for this Account',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                ),
                value: _hideEventsInitial,
                onChanged: (bool value) {
                  setState(() {
                    _hideEventsInitial = value;
                  });
                },
                secondary: Icon(
                    _hideEventsInitial
                        ? Icons.notifications_off
                        : Icons.notifications,
                    color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(
                  'Exclude from Total Balance',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                ),
                value: _excludeFromTotalInitial,
                onChanged: (bool value) {
                  setState(() {
                    _excludeFromTotalInitial = value;
                  });
                },
                secondary: Icon(
                    _excludeFromTotalInitial
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Select Card Color:',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableColors
                    .map<Widget>((Map<String, Object> colorMap) {
                      final int colorValue = colorMap['value']! as int;
                      final bool isSelected = _selectedColorValue == colorValue;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorValue = colorValue;
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: colorScheme.primary,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize:
                      const Size(double.infinity, 50), // Ensure button fills width
                ),
                icon:
                    Icon(Icons.add_card, color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Create Account",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for adding a new money tool.
class AddMoneyToolForm extends StatefulWidget {
  final String accountId;

  const AddMoneyToolForm({super.key, required this.accountId});

  @override
  State<AddMoneyToolForm> createState() => _AddMoneyToolFormState();
}

class _AddMoneyToolFormState extends State<AddMoneyToolForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _usdRateController = TextEditingController();

  String _selectedCurrency = 'RUR'; // Default currency

  @override
  void initState() {
    super.initState();
    // Initialize USD rate to a reasonable default if USD is already selected
    if (_selectedCurrency == 'USD') {
      _usdRateController.text = '90.0'; // Example default USD rate
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _usdRateController.dispose();
    super.dispose();
  }

  void _addTool() {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text.trim();
      final double quantity = double.parse(_quantityController.text);
      final String currencyTicker = _selectedCurrency;
      double unitPrice;

      if (_selectedCurrency == 'RUR') {
        unitPrice = 1.0;
      } else {
        unitPrice = double.parse(_usdRateController.text);
      }

      Provider.of<AccountData>(context, listen: false).addMoneyTool(
        widget.accountId,
        name,
        quantity,
        currencyTicker,
        unitPrice,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Money tool "$name" added successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Add Money Tool",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.label, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for the money tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g., 1000.00 or -50.50',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.numbers, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a quantity';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.currency_exchange,
                      color: colorScheme.onSurfaceVariant),
                ),
                items: <String>['RUR', 'USD']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCurrency = newValue;
                      if (newValue == 'USD' && _usdRateController.text.isEmpty) {
                        _usdRateController.text = '90.0'; // Default rate
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_selectedCurrency == 'USD') ...<Widget>[
                TextFormField(
                  controller: _usdRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'USD Exchange Rate to RUB (Цена за единицу)',
                    hintText: 'e.g., 90.0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: Icon(Icons.currency_ruble,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter USD exchange rate';
                    }
                    final double? rate = double.tryParse(value);
                    if (rate == null || rate <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: _addTool,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize:
                      const Size(double.infinity, 50), // Ensure button fills width
                ),
                icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Add Money Tool",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for adding a new deposit.
class AddDepositForm extends StatefulWidget {
  final String accountId;

  const AddDepositForm({super.key, required this.accountId});

  @override
  State<AddDepositForm> createState() => _AddDepositFormState();
}

class _AddDepositFormState extends State<AddDepositForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _annualYieldController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWithdrawalToolName;
  PayoutType? _selectedPayoutType = PayoutType.atEndOfTerm; // Default payout type

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 365)); // Default to 1 year later
    _startDateController.text = DateFormat('yyyy-MM-dd').format(_startDate!);
    _endDateController.text = DateFormat('yyyy-MM-dd').format(_endDate!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _annualYieldController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate! : _endDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  void _addDeposit() {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text.trim();
      final double quantity = double.parse(_quantityController.text);
      final double annualYield = double.parse(_annualYieldController.text);

      if (_startDate == null ||
          _endDate == null ||
          _selectedWithdrawalToolName == null ||
          _selectedPayoutType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      Provider.of<AccountData>(context, listen: false).addDeposit(
        accountId: widget.accountId,
        name: name,
        quantity: quantity,
        annualYield: annualYield,
        startDate: _startDate!,
        endDate: _endDate!,
        payoutType: _selectedPayoutType!,
        withdrawalToolName: _selectedWithdrawalToolName!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deposit "$name" created successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData = Provider.of<AccountData>(context);
    final List<Tool> moneyTools =
        accountData.getMoneyToolsForAccount(widget.accountId);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Add New Deposit",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Deposit Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.description,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a deposit name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Principal Amount',
                  hintText: 'e.g., 50000.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.account_balance,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the principal amount';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _annualYieldController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Annual Yield (%)',
                  hintText: 'e.g., 5.5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.percent, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the annual yield';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Start Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context, true),
                validator: (String? value) {
                  if (_startDate == null) {
                    return 'Please select a start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'End Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context, false),
                validator: (String? value) {
                  if (_endDate == null) {
                    return 'Please select an end date';
                  }
                  if (_startDate != null && _endDate!.isBefore(_startDate!)) {
                    return 'End date must be after start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedWithdrawalToolName,
                decoration: InputDecoration(
                  labelText: 'Withdrawal Account (Money Tool)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money, color: colorScheme.onSurfaceVariant),
                ),
                items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
                  return DropdownMenuItem<String>(
                    value: tool.name,
                    child:
                        Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedWithdrawalToolName = newValue;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a withdrawal money tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PayoutType>(
                value: _selectedPayoutType,
                decoration: InputDecoration(
                  labelText: 'Payout Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.payment, color: colorScheme.onSurfaceVariant),
                ),
                items: PayoutType.values
                    .map<DropdownMenuItem<PayoutType>>((PayoutType type) {
                  return DropdownMenuItem<PayoutType>(
                    value: type,
                    child: Text(_getPayoutTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (PayoutType? newValue) {
                  setState(() {
                    _selectedPayoutType = newValue;
                  });
                },
                validator: (PayoutType? value) {
                  if (value == null) {
                    return 'Please select a payout type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize:
                      const Size(double.infinity, 50), // Ensure button fills width
                ),
                icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Add Deposit",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for adding a new credit.
class AddCreditForm extends StatefulWidget {
  final String accountId;

  const AddCreditForm({super.key, required this.accountId});

  @override
  State<AddCreditForm> createState() => _AddCreditFormState();
}

class _AddCreditFormState extends State<AddCreditForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _loanStartDateController = TextEditingController();
  final TextEditingController _loanTermMonthsController = TextEditingController();
  final TextEditingController _paymentDayOfMonthController = TextEditingController();

  String? _selectedTransferToMoneyToolName;
  DateTime? _loanStartDate;
  CreditPaymentType? _selectedPaymentType = CreditPaymentType.annuity; // Default

  @override
  void initState() {
    super.initState();
    _loanStartDate = DateTime.now();
    _loanStartDateController.text = DateFormat('yyyy-MM-dd').format(_loanStartDate!);
    // Pre-select the first available money tool if any exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);
      final List<Tool> moneyTools =
          accountData.getMoneyToolsForAccount(widget.accountId);
      if (moneyTools.isNotEmpty) {
        setState(() {
          _selectedTransferToMoneyToolName = moneyTools.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    _loanStartDateController.dispose();
    _loanTermMonthsController.dispose();
    _paymentDayOfMonthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _loanStartDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _loanStartDate = picked;
        _loanStartDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addCredit() {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text.trim();
      final double amount = double.parse(_amountController.text);
      final double interestRate = double.parse(_interestRateController.text);
      final int loanTermMonths = int.parse(_loanTermMonthsController.text);
      final int paymentDayOfMonth = int.parse(_paymentDayOfMonthController.text);

      if (_loanStartDate == null ||
          _selectedTransferToMoneyToolName == null ||
          _selectedPaymentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      Provider.of<AccountData>(context, listen: false).addCredit(
        accountId: widget.accountId,
        name: name,
        amount: amount,
        interestRate: interestRate,
        loanStartDate: _loanStartDate!,
        loanTermMonths: loanTermMonths,
        paymentDayOfMonth: paymentDayOfMonth,
        creditPaymentType: _selectedPaymentType!,
        transferToMoneyToolName: _selectedTransferToMoneyToolName!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit "$name" added successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData = Provider.of<AccountData>(context);
    final List<Tool> moneyTools =
        accountData.getMoneyToolsForAccount(widget.accountId);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Add New Credit",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Credit Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.description,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a credit name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTransferToMoneyToolName,
                decoration: InputDecoration(
                  labelText: 'Transfer Funds To (Money Tool)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money, color: colorScheme.onSurfaceVariant),
                ),
                items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
                  return DropdownMenuItem<String>(
                    value: tool.name,
                    child:
                        Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTransferToMoneyToolName = newValue;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a money tool to transfer funds to';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Loan Amount',
                  hintText: 'e.g., 100000.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.payments, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the loan amount';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Annual Interest Rate (%)',
                  hintText: 'e.g., 12.5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.percent, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the annual interest rate';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val < 0) {
                    return 'Please enter a valid non-negative number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _loanStartDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Loan Start Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context),
                validator: (String? value) {
                  if (_loanStartDate == null) {
                    return 'Please select a start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _loanTermMonthsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Loan Term (Months)',
                  hintText: 'e.g., 36',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.timer, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the loan term in months';
                  }
                  final int? val = int.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive integer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentDayOfMonthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Payment Day of Month',
                  hintText: 'e.g., 15 (for the 15th of the month)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_view_day,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the payment day of month';
                  }
                  final int? val = int.tryParse(value);
                  if (val == null || val < 1 || val > 31) {
                    return 'Please enter a valid day (1-31)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CreditPaymentType>(
                value: _selectedPaymentType,
                decoration: InputDecoration(
                  labelText: 'Payment Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.payment, color: colorScheme.onSurfaceVariant),
                ),
                items: CreditPaymentType.values
                    .map<DropdownMenuItem<CreditPaymentType>>(
                        (CreditPaymentType type) {
                  return DropdownMenuItem<CreditPaymentType>(
                    value: type,
                    child: Text(_getCreditPaymentTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (CreditPaymentType? newValue) {
                  setState(() {
                    _selectedPaymentType = newValue;
                  });
                },
                validator: (CreditPaymentType? value) {
                  if (value == null) {
                    return 'Please select a payment type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addCredit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Add Credit",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for adding a new 'other' tool.
class AddOtherToolForm extends StatefulWidget {
  final String accountId;

  const AddOtherToolForm({super.key, required this.accountId});

  @override
  State<AddOtherToolForm> createState() => _AddOtherToolFormState();
}

class _AddOtherToolFormState extends State<AddOtherToolForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedWithdrawalToolName;

  @override
  void initState() {
    super.initState();
    // Pre-select the first available money tool if any exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);
      final List<Tool> moneyTools =
          accountData.getMoneyToolsForAccount(widget.accountId);
      if (moneyTools.isNotEmpty) {
        setState(() {
          _selectedWithdrawalToolName = moneyTools.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _addOtherTool() {
    if (_formKey.currentState!.validate()) {
      final String name = _nameController.text.trim();
      final double amount = double.parse(_amountController.text);

      if (_selectedWithdrawalToolName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a withdrawal money tool.')),
        );
        return;
      }

      Provider.of<AccountData>(context, listen: false).addOtherTool(
        accountId: widget.accountId,
        name: name,
        amount: amount,
        withdrawalToolName: _selectedWithdrawalToolName!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Other tool "$name" added successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData = Provider.of<AccountData>(context);
    final List<Tool> moneyTools =
        accountData.getMoneyToolsForAccount(widget.accountId);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Add New Other Tool",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tool Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.label,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for the tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedWithdrawalToolName,
                decoration: InputDecoration(
                  labelText: 'Withdrawal Account (Money Tool)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money, color: colorScheme.onSurfaceVariant),
                ),
                items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
                  return DropdownMenuItem<String>(
                    value: tool.name,
                    child:
                        Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedWithdrawalToolName = newValue;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a withdrawal money tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Amount (Quantity for this tool)',
                  hintText: 'e.g., 50.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.numbers, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the amount';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addOtherTool,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize:
                      const Size(double.infinity, 50), // Ensure button fills width
                ),
                icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Add Other Tool",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for adding income.
class AddIncomeForm extends StatefulWidget {
  final String accountId;

  const AddIncomeForm({super.key, required this.accountId});

  @override
  State<AddIncomeForm> createState() => _AddIncomeFormState();
}

class _AddIncomeFormState extends State<AddIncomeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedMoneyToolName; // To hold the selected money tool

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    // Pre-select the first available money tool for the active account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);
      final List<Tool> moneyTools =
          accountData.getMoneyToolsForAccount(widget.accountId);
      if (moneyTools.isNotEmpty) {
        setState(() {
          _selectedMoneyToolName = moneyTools.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _commentController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addIncome() {
    if (_formKey.currentState!.validate()) {
      final String category = _categoryController.text.trim();
      final double amount = double.parse(_amountController.text);
      final String? comment = _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim();

      if (_selectedDate == null || _selectedMoneyToolName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      Provider.of<AccountData>(context, listen: false).addIncome(
        accountId: widget.accountId,
        toolName: _selectedMoneyToolName!,
        amount: amount,
        date: _selectedDate!,
        category: category,
        comment: comment,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Income added successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData = Provider.of<AccountData>(context);
    final List<Tool> moneyTools =
        accountData.getMoneyToolsForAccount(widget.accountId);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Add Income",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _selectedMoneyToolName,
                decoration: InputDecoration(
                  labelText: 'Target Money Tool',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money, color: colorScheme.onSurfaceVariant),
                ),
                items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
                  return DropdownMenuItem<String>(
                    value: tool.name,
                    child:
                        Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMoneyToolName = newValue;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a money tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Amount (RUB equivalent)',
                  hintText: 'e.g., 5000.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.attach_money,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the amount';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Operation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context),
                validator: (String? value) {
                  if (_selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Salary, Gift, Refund',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.category, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'Comment (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.comment, color: colorScheme.onSurfaceVariant),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addIncome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: Icon(Icons.add_circle_outline,
                    color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Add Income",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for adding expense.
class AddExpenseForm extends StatefulWidget {
  final String accountId;

  const AddExpenseForm({super.key, required this.accountId});

  @override
  State<AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedMoneyToolName; // To hold the selected money tool

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    // Pre-select the first available money tool for the active account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);
      final List<Tool> moneyTools =
          accountData.getMoneyToolsForAccount(widget.accountId);
      if (moneyTools.isNotEmpty) {
        setState(() {
          _selectedMoneyToolName = moneyTools.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _commentController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addExpense() {
    if (_formKey.currentState!.validate()) {
      final String category = _categoryController.text.trim();
      final double amount = double.parse(_amountController.text);
      final String? comment = _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim();

      if (_selectedDate == null || _selectedMoneyToolName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      Provider.of<AccountData>(context, listen: false).addExpense(
        accountId: widget.accountId,
        toolName: _selectedMoneyToolName!,
        amount: amount,
        date: _selectedDate!,
        category: category,
        comment: comment,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense added successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData = Provider.of<AccountData>(context);
    final List<Tool> moneyTools =
        accountData.getMoneyToolsForAccount(widget.accountId);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Add Expense",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _selectedMoneyToolName,
                decoration: InputDecoration(
                  labelText: 'Source Money Tool',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money, color: colorScheme.onSurfaceVariant),
                ),
                items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
                  return DropdownMenuItem<String>(
                    value: tool.name,
                    child:
                        Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMoneyToolName = newValue;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a money tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Amount (RUB equivalent)',
                  hintText: 'e.g., 50.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money_off, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the amount';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Operation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context),
                validator: (String? value) {
                  if (_selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Groceries, Rent, Transport',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.category, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'Comment (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.comment, color: colorScheme.onSurfaceVariant),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error, // Use error color for expense button
                  foregroundColor: colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: Icon(Icons.remove_circle_outline,
                    color: colorScheme.onError, size: 20),
                label: Text(
                  "Add Expense",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onError,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for making a transfer between money tools.
class AddTransferForm extends StatefulWidget {
  final String activeAccountId;

  const AddTransferForm({super.key, required this.activeAccountId});

  @override
  State<AddTransferForm> createState() => _AddTransferFormState();
}

class _AddTransferFormState extends State<AddTransferForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedSourceToolName; // Only money tools from active account
  String? _selectedDestinationToolIdentifier; // Format: "toolName|accountId"

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);
      final List<Tool> sourceMoneyTools =
          accountData.getMoneyToolsForAccount(widget.activeAccountId);
      if (sourceMoneyTools.isNotEmpty) {
        setState(() {
          _selectedSourceToolName = sourceMoneyTools.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commissionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _makeTransfer() {
    if (_formKey.currentState!.validate()) {
      if (_selectedSourceToolName == null ||
          _selectedDestinationToolIdentifier == null ||
          _selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      final double amount = double.parse(_amountController.text);
      final double commission = _commissionController.text.trim().isEmpty
          ? 0.0
          : double.parse(_commissionController.text);

      final List<String> destinationParts =
          _selectedDestinationToolIdentifier!.split('|');
      final String destinationToolName = destinationParts[0];
      final String destinationAccountId = destinationParts[1];

      Provider.of<AccountData>(context, listen: false).makeToolTransfer(
        fromToolName: _selectedSourceToolName!,
        fromAccountId: widget.activeAccountId,
        toToolName: destinationToolName,
        toAccountId: destinationAccountId,
        amount: amount,
        date: _selectedDate!,
        commission: commission,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer completed successfully!')),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData = Provider.of<AccountData>(context);

    // Filter source tools by active account
    final List<Tool> sourceMoneyTools =
        accountData.getMoneyToolsForAccount(widget.activeAccountId);

    // Get all money tools for destination, exclude already selected source tool
    final List<Tool> allPossibleDestinationTools =
        accountData.allMoneyTools.where((Tool tool) {
      // Don't allow transferring to the same tool it's coming from
      return !(tool.name == _selectedSourceToolName &&
          tool.accountId == widget.activeAccountId);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Make Transfer",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _selectedSourceToolName,
                decoration: InputDecoration(
                  labelText: 'From (Source Money Tool)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.outbox, color: colorScheme.onSurfaceVariant),
                ),
                items: sourceMoneyTools.map<DropdownMenuItem<String>>((Tool tool) {
                  return DropdownMenuItem<String>(
                    value: tool.name,
                    child:
                        Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSourceToolName = newValue;
                    // If the selected source tool is now the same as the destination, clear destination
                    if (_selectedDestinationToolIdentifier != null) {
                      final List<String> destParts =
                          _selectedDestinationToolIdentifier!.split('|');
                      if (destParts[0] == _selectedSourceToolName &&
                          destParts[1] == widget.activeAccountId) {
                        _selectedDestinationToolIdentifier = null;
                      }
                    }
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a source money tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDestinationToolIdentifier,
                decoration: InputDecoration(
                  labelText: 'To (Destination Money Tool)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.inbox, color: colorScheme.onSurfaceVariant),
                ),
                items: allPossibleDestinationTools
                    .map<DropdownMenuItem<String>>((Tool tool) {
                  final String toolAccountName =
                      accountData.getAccountById(tool.accountId)?.name ??
                          'Unknown Account';
                  return DropdownMenuItem<String>(
                    value: '${tool.name}|${tool.accountId}',
                    child: Text(
                        '${tool.name} (${toolAccountName}) - ${formatCurrency(tool.currentValue)}'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDestinationToolIdentifier = newValue;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a destination money tool';
                  }
                  // Prevent selecting the same tool as source
                  final List<String> destParts = value.split('|');
                  if (destParts[0] == _selectedSourceToolName &&
                      destParts[1] == widget.activeAccountId) {
                    return 'Cannot transfer to the same source tool';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Amount (RUB equivalent)',
                  hintText: 'e.g., 1000.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.payments, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the amount';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Transfer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context),
                validator: (String? value) {
                  if (_selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commissionController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: 'Commission (Optional, RUB equivalent)',
                  hintText: 'e.g., 5.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money_off, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value != null && value.isNotEmpty) {
                    final double? val = double.tryParse(value);
                    if (val == null || val < 0) {
                      return 'Please enter a valid non-negative number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _makeTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: Icon(Icons.swap_horiz,
                    color: colorScheme.onPrimary, size: 20),
                label: Text(
                  "Complete Transfer",
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet for buying or selling stocks or ETFs.
class AddInvestmentOperationForm extends StatefulWidget {
  final String accountId;
  final InvestmentOperationType operationType;
  final ToolType investmentType; // e.g., ToolType.stocks or ToolType.etf or ToolType.bonds

  const AddInvestmentOperationForm({
    super.key,
    required this.accountId,
    required this.operationType,
    required this.investmentType,
  });

  @override
  State<AddInvestmentOperationForm> createState() =>
      _AddInvestmentOperationFormState();
}

class _AddInvestmentOperationFormState
    extends State<AddInvestmentOperationForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  // New controllers for bonds
  final TextEditingController _faceValueController = TextEditingController();
  final TextEditingController _accruedCouponIncomeController =
      TextEditingController();

  DateTime? _selectedDate;
  List<String> _investmentSuggestions = <String>[];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    final AccountData accountData =
        Provider.of<AccountData>(context, listen: false);

    if (widget.operationType == InvestmentOperationType.sell) {
      // For selling, suggest only investments currently held in this account of the specified type
      _investmentSuggestions = accountData
          .getToolsForAccount(widget.accountId)
          .where((Tool tool) =>
              tool.type == widget.investmentType && tool.ticker != null)
          .map<String>((Tool tool) => tool.ticker!)
          .toList();
    } else {
      // For buying, suggest all known investment options relevant to the type
      _investmentSuggestions = accountData.allInvestmentOptions.keys
          .where((String ticker) {
            // Determine if the ticker matches the current investmentType
            // This is a heuristic based on initial data, not a robust solution for all tickers
            if (widget.investmentType == ToolType.stocks) {
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
            } else if (widget.investmentType == ToolType.etf) {
              return ['SPY', 'QQQ', 'DIA', 'GLD', 'ARKK'].contains(ticker);
            } else if (widget.investmentType == ToolType.bonds) {
              return ['GOV', 'CORP'].contains(ticker);
            } else if (widget.investmentType == ToolType.cryptocurrency) {
              return ['BTC', 'ETH', 'XRP', 'LTC'].contains(ticker);
            }
            return false;
          }).toList();
    }
    _investmentSuggestions.sort(); // Keep suggestions sorted
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    _dateController.dispose();
    _faceValueController.dispose();
    _accruedCouponIncomeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _performInvestmentOperation() {
    if (_formKey.currentState!.validate()) {
      final String ticker = _tickerController.text.trim().toUpperCase();
      final String name = _nameController.text.trim();
      final double quantity = double.parse(_quantityController.text);
      final double price = double.parse(_priceController.text);
      final double commission = _commissionController.text.trim().isEmpty
          ? 0.0
          : double.parse(_commissionController.text);

      double? faceValue;
      double? accruedCouponIncome;

      if (widget.investmentType == ToolType.bonds) {
        faceValue = double.parse(_faceValueController.text);
        accruedCouponIncome = double.parse(_accruedCouponIncomeController.text);
      }

      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date.')),
        );
        return;
      }

      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);

      if (widget.operationType == InvestmentOperationType.buy) {
        if (widget.investmentType == ToolType.stocks) {
          accountData.buyStock(
            accountId: widget.accountId,
            ticker: ticker,
            stockName: name,
            quantity: quantity,
            pricePerUnit: price,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bought $quantity shares of $ticker!')),
          );
        } else if (widget.investmentType == ToolType.etf) {
          accountData.buyEtf(
            accountId: widget.accountId,
            ticker: ticker,
            etfName: name,
            quantity: quantity,
            pricePerUnit: price,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bought $quantity units of $ticker ETF!')),
          );
        } else if (widget.investmentType == ToolType.bonds) {
          accountData.buyBond(
            accountId: widget.accountId,
            ticker: ticker,
            bondName: name,
            quantity: quantity,
            pricePerUnit: price,
            faceValue: faceValue!,
            accruedCouponIncome: accruedCouponIncome!,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bought $quantity bonds of $ticker!')),
          );
        } else if (widget.investmentType == ToolType.cryptocurrency) {
          // NEW
          accountData.buyCrypto(
            accountId: widget.accountId,
            ticker: ticker,
            cryptoName: name,
            quantity: quantity,
            pricePerUnit: price,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Bought $quantity units of $ticker cryptocurrency!')),
          );
        }
      } else {
        // Sell operation
        if (widget.investmentType == ToolType.stocks) {
          accountData.sellStock(
            accountId: widget.accountId,
            ticker: ticker,
            stockName: name,
            quantity: quantity,
            pricePerUnit: price,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sold $quantity shares of $ticker!')),
          );
        } else if (widget.investmentType == ToolType.etf) {
          accountData.sellEtf(
            accountId: widget.accountId,
            ticker: ticker,
            etfName: name,
            quantity: quantity,
            pricePerUnit: price,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sold $quantity units of $ticker ETF!')),
          );
        } else if (widget.investmentType == ToolType.bonds) {
          accountData.sellBond(
            accountId: widget.accountId,
            ticker: ticker,
            bondName: name,
            quantity: quantity,
            pricePerUnit: price,
            accruedCouponIncome: accruedCouponIncome!,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sold $quantity bonds of $ticker!')),
          );
        } else if (widget.investmentType == ToolType.cryptocurrency) {
          // NEW
          accountData.sellCrypto(
            accountId: widget.accountId,
            ticker: ticker,
            cryptoName: name,
            quantity: quantity,
            pricePerUnit: price,
            commission: commission,
            date: _selectedDate!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Sold $quantity units of $ticker cryptocurrency!')),
          );
        }
      }
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AccountData accountData =
        Provider.of<AccountData>(context, listen: false);

    final String investmentTypeName;
    IconData tickerPrefixIcon;
    switch (widget.investmentType) {
      case ToolType.stocks:
        investmentTypeName = "Акции";
        tickerPrefixIcon = Icons.trending_up;
        break;
      case ToolType.etf:
        investmentTypeName = "ETF";
        tickerPrefixIcon = Icons.auto_graph;
        break;
      case ToolType.bonds:
        investmentTypeName = "Облигации";
        tickerPrefixIcon = Icons.receipt_long;
        break;
      case ToolType.cryptocurrency: // NEW
        investmentTypeName = "Криптовалюту";
        tickerPrefixIcon = Icons.currency_bitcoin;
        break;
      default:
        investmentTypeName = "Инвестиция"; // Fallback
        tickerPrefixIcon = Icons.currency_exchange;
    }

    final String title = widget.operationType == InvestmentOperationType.buy
        ? "Купить $investmentTypeName"
        : "Продать $investmentTypeName";
    final String buttonText = widget.operationType == InvestmentOperationType.buy
        ? "Купить"
        : "Продать";
    final IconData buttonIcon = widget.operationType == InvestmentOperationType.buy
        ? Icons.add_shopping_cart
        : Icons.sell;
    final Color buttonColor = widget.operationType == InvestmentOperationType.buy
        ? colorScheme.primary
        : colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  final String lowerCaseQuery =
                      textEditingValue.text.toLowerCase();
                  return _investmentSuggestions.where((String option) {
                    return option.toLowerCase().contains(lowerCaseQuery) ||
                           (accountData.allInvestmentOptions[option]?.toLowerCase() ?? '')
                               .contains(lowerCaseQuery);
                  });
                },
                onSelected: (String selection) {
                  _tickerController.text = selection;
                  _nameController.text =
                      accountData.allInvestmentOptions[selection] ?? '';
                  debugPrint('You selected $selection');
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  // Sync internal controller with Autocomplete's controller
                  _tickerController.text = fieldTextEditingController.text;
                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Ticker Symbol (e.g., AAPL, SPY, GOV, BTC)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(tickerPrefixIcon, // Use dynamic icon
                          color: colorScheme.onSurfaceVariant),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a ticker symbol';
                      }
                      return null;
                    },
                    onChanged: (String value) {
                      final String? name =
                          accountData.allInvestmentOptions[value.toUpperCase()];
                      if (name != null && name.isNotEmpty) {
                        _nameController.text = name;
                      } else {
                        // Clear name if ticker doesn't match a known investment
                        _nameController.text = '';
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '$investmentTypeName Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.label, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a $investmentTypeName name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity (шт.)',
                  hintText: 'e.g., 10.5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.numbers, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  // For sell operation, validate sufficient quantity based on specific investment type
                  if (widget.operationType == InvestmentOperationType.sell) {
                    final Tool? existingInvestment = _tickerController.text.trim().isEmpty
                        ? null
                        : accountData.getToolsForAccount(widget.accountId).cast<Tool?>().firstWhere(
                              (Tool? tool) =>
                                  tool != null &&
                                  tool.ticker == _tickerController.text.trim().toUpperCase() &&
                                  tool.type == widget.investmentType,
                              orElse: () => null,
                            );

                    if (existingInvestment == null || val > existingInvestment.quantity) {
                      return 'Insufficient ${investmentTypeName.toLowerCase()} to sell. Available: ${existingInvestment?.quantity ?? 0}';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price Per Unit (RUB)',
                  hintText: 'e.g., 150.75',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.money,
                      color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter price per unit';
                  }
                  final double? val = double.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (widget.investmentType == ToolType.bonds &&
                  widget.operationType == InvestmentOperationType.buy)
                Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _faceValueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Bond Face Value (Nominal)',
                        hintText: 'e.g., 1000.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        prefixIcon: Icon(Icons.badge,
                            color: colorScheme.onSurfaceVariant),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter bond nominal value';
                        }
                        final double? val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              if (widget.investmentType == ToolType.bonds)
                Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _accruedCouponIncomeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Accrued Coupon Income (RUB)',
                        hintText: 'e.g., 12.50',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        prefixIcon: Icon(Icons.account_balance_wallet,
                            color: colorScheme.onSurfaceVariant),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter accrued coupon income (ACI)';
                        }
                        final double? val = double.tryParse(value);
                        if (val == null || val < 0) {
                          return 'Please enter a valid non-negative number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              TextFormField(
                controller: _commissionController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Commission (Optional, RUB)',
                  hintText: 'e.g., 5.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon:
                      Icon(Icons.money_off, color: colorScheme.onSurfaceVariant),
                ),
                validator: (String? value) {
                  if (value != null && value.isNotEmpty) {
                    final double? val = double.tryParse(value);
                    if (val == null || val < 0) {
                      return 'Please enter a valid non-negative number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Operation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(Icons.calendar_today,
                      color: colorScheme.onSurfaceVariant),
                ),
                onTap: () => _selectDate(context),
                validator: (String? value) {
                  if (_selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _performInvestmentOperation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: Icon(buttonIcon, color: colorScheme.onPrimary, size: 20),
                label: Text(
                  buttonText,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen displaying the list of transactions, grouped by day.
class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final AccountData accountData =
        Provider.of<AccountData>(context, listen: false);

    // Find initial page index based on activeAccountId
    int initialPageIndex = accountData.accounts.indexWhere(
      (AccountSummary acc) => acc.id == accountData.activeAccountId,
    );
    if (initialPageIndex == -1) {
      initialPageIndex = 0; // Default to first account if not found
    }

    _pageController = PageController(
      initialPage: initialPageIndex,
      viewportFraction: 0.9, // Adjust to show a portion of next/prev cards
    );

    _pageController.addListener(_onPageChanged);
    accountData.addListener(_onAccountDataChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    Provider.of<AccountData>(context, listen: false)
        .removeListener(_onAccountDataChanged);
    super.dispose();
  }

  /// Listener for AccountData changes to sync PageView.
  void _onAccountDataChanged() {
    final AccountData accountData =
        Provider.of<AccountData>(context, listen: false);
    final int newActiveIndex = accountData.accounts.indexWhere(
      (AccountSummary acc) => acc.id == accountData.activeAccountId,
    );

    // Only animate if the active account changed and PageController is ready
    if (_pageController.hasClients &&
        _pageController.page != null &&
        newActiveIndex != -1 &&
        newActiveIndex != _pageController.page!.round()) {
      _pageController.animateToPage(
        newActiveIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Listener for PageController changes to sync AccountData.
  void _onPageChanged() {
    // Update active account in data model only when page settles on an integer
    if (_pageController.page != null && _pageController.page! % 1 == 0) {
      final AccountData accountData =
          Provider.of<AccountData>(context, listen: false);
      final int currentPageIndex = _pageController.page!.round();
      if (currentPageIndex >= 0 &&
          currentPageIndex < accountData.accounts.length) {
        final String newAccountId = accountData.accounts[currentPageIndex].id;
        if (accountData.activeAccountId != newAccountId) {
          accountData.setActiveAccount(newAccountId);
        }
      }
    }
  }

  void _showAddAccountForm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled:
          true, // Allow content to be scrollable if keyboard appears
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const AddAccountForm(),
        );
      },
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
    );
  }

  void _showActionBottomSheet(BuildContext context) {
    final AccountData accountData =
        Provider.of<AccountData>(context, listen: false);
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return ActionSelectionBottomSheet(
            activeAccountId: accountData.activeAccountId);
      },
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AccountData accountData = Provider.of<AccountData>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surface,
        title: Text(
          "My Accounts",
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
        ),
        actions: <Widget>[
          IconButton(
            icon:
                Icon(Icons.add, color: colorScheme.onSurfaceVariant, size: 24),
            onPressed: () {
              _showAddAccountForm(context);
            },
          )
        ],
      ),
      body: GestureDetector(
        // Tap anywhere on the body to exit delete mode
        onTap: () {
          if (accountData.deletableAccountId != null) {
            accountData.clearDeletableAccount();
          }
        },
        // Add horizontal drag gesture to change active account
        onHorizontalDragEnd: (DragEndDetails details) {
          // If in delete mode, a swipe should just clear delete mode
          if (accountData.deletableAccountId != null) {
            accountData.clearDeletableAccount();
            return;
          }

          // Ensure there's a valid velocity
          if (details.primaryVelocity == null) return;

          final int currentIndex = _pageController.page?.round() ?? 0;
          final int numAccounts = accountData.accounts.length;

          // Swipe left (negative velocity) to go to the next account
          if (details.primaryVelocity! < 0) {
            if (currentIndex < numAccounts - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
          // Swipe right (positive velocity) to go to the previous account
          else if (details.primaryVelocity! > 0) {
            if (currentIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 16.0),
                padding: const EdgeInsets.symmetric(
                    vertical:
                        8.0), // Horizontal padding handled by PageView's itemBuilder
                width: MediaQuery.of(context).size.width,
                height: 140,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: accountData.accounts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AccountSummary account = accountData.accounts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0), // Spacing between cards
                      child: AccountCard(account: account),
                    );
                  },
                ),
              ),
              if (accountData.activeAccountId != 'total' &&
                  accountData.deletableAccountId ==
                      null) // Show buttons if not 'total' account AND not in delete mode
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('View Events (Not Implemented)')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          icon: Icon(Icons.history, // Icon for events/history
                              size: 20, color: colorScheme.onPrimary),
                          label: Text(
                            "События", // "Events" in Russian
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // Spacing between buttons
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showActionBottomSheet(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          icon: Icon(Icons.add_circle, // Icon for add action
                              size: 20, color: colorScheme.onSecondary),
                          label: Text(
                            "Добавить", // "Add" in Russian
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                  color: colorScheme.onSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Conditional display for Tools and Events sections
              Consumer<AccountData>(
                builder: (BuildContext context, AccountData accountData,
                    Widget? child) {
                  final AccountSummary? activeAccount =
                      accountData.getAccountById(accountData.activeAccountId);

                  if (activeAccount == null) {
                    return const Center(child: Text("Select an account."));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Financial Tools Section (Displayed for all accounts *except* 'total')
                      if (activeAccount.id != 'total') ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 24, left: 16, right: 16, bottom: 8),
                          child: Text(
                            "Финансовые инструменты", // "Financial Tools"
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onBackground,
                                ),
                          ),
                        ),
                        ToolList(
                            accountData: accountData,
                            accountId: activeAccount.id),
                      ],

                      // Recent Events Section (Displayed *only* for 'total' account)
                      if (activeAccount.id == 'total') ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 24, left: 16, right: 16, bottom: 8),
                          child: Text(
                            "Последние события", // "Recent Events"
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onBackground,
                                ),
                          ),
                        ),
                        EventList(
                          accountData: accountData,
                          maxEvents: 5, // As per original code, total gets 5
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(
    ChangeNotifierProvider<AccountData>(
      create: (BuildContext context) => AccountData(),
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          home: const AccountListScreen(),
        );
      },
    ),
  );
}