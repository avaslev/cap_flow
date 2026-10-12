import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';

/// M1 characterization tests for [AccountData].
///
/// These tests pin the CURRENT behavior (including quirks) so the typed-tool
/// refactor (REFACTORING_PLAN.md, M4) can be verified against it.

AccountSummary _account(
  String id, {
  bool excludeFromTotal = false,
  bool hideEvents = false,
}) {
  return AccountSummary(
    id: id,
    name: id,
    balance: 0,
    dailyChangeAmount: 0,
    dailyChangePercentage: 0,
    colorValue: 0xFF000000,
    type: AccountType.general,
    hideEvents: hideEvents,
    excludeFromTotal: excludeFromTotal,
  );
}

ToolSummary _moneyTool(
  String id,
  String accountId, {
  double quantity = 0,
  double currentValue = 0,
  String? ticker,
}) {
  return ToolSummary(
    id: id,
    name: id,
    quantity: quantity,
    percentageChange: 0,
    accountId: accountId,
    type: ToolType.money,
    currentValue: currentValue,
    ticker: ticker,
  );
}

void main() {
  group('AccountData initialization', () {
    test('creates virtual total account, active by default', () {
      final AccountData data = AccountData();
      expect(data.accounts.first.id, 'total');
      expect(data.accounts.first.balance, 0.0);
      expect(data.activeAccountId, 'total');
    });
  });

  group('Balances and Total aggregation', () {
    test('account balance equals sum of its tools; total excludes flagged', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a'), _account('b'), _account('ex', excludeFromTotal: true)]);
      data.addTool(_moneyTool('a-cash', 'a', quantity: 100, currentValue: 100));
      data.addTool(_moneyTool('b-cash', 'b', quantity: 50, currentValue: 50));
      data.addTool(
        ToolSummary(
          id: 'ex-dep',
          name: 'ex-dep',
          quantity: 1,
          percentageChange: 0,
          accountId: 'ex',
          type: ToolType.deposit,
          currentValue: 1000,
        ),
      );

      expect(data.getAccountById('a')!.balance, 100.0);
      expect(data.getAccountById('b')!.balance, 50.0);
      // Исключённый счёт: баланс считается и виден на карточке,
      // но в Total он не попадает.
      expect(data.getAccountById('ex')!.balance, 1000.0);
      expect(data.getAccountById('total')!.balance, 150.0);
    });

    test('included account balance tracks tools on every addTool', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(_moneyTool('t1', 'a', currentValue: 100));
      expect(data.getAccountById('a')!.balance, 100.0);
      data.addTool(_moneyTool('t2', 'a', currentValue: 250));
      expect(data.getAccountById('a')!.balance, 350.0);
      expect(data.getAccountById('total')!.balance, 350.0);
    });

    test('removeTool actually removes (refresh cleanup path)', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(_moneyTool('t1', 'a', currentValue: 100));
      data.addTool(_moneyTool('t2', 'a', currentValue: 200));
      // Refresh cleanup: t1 was deleted from DB.
      expect(data.removeTool('t1'), isTrue);
      expect(data.tools.containsKey('t1'), isFalse);
      expect(data.removeTool('t1'), isFalse); // already gone
      // Next recalc (triggered by any addTool in the refresh flow)
      // drops the removed tool from the balance.
      data.addTool(_moneyTool('t3', 'a', currentValue: 50));
      expect(data.getAccountById('a')!.balance, 250.0);
      expect(data.getAccountById('total')!.balance, 250.0);
    });

    test('addTool upserts by id', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(_moneyTool('t1', 'a', currentValue: 100));
      data.addTool(_moneyTool('t1', 'a', currentValue: 300));
      expect(data.getAccountById('a')!.balance, 300.0);
      expect(data.getAccountById('total')!.balance, 300.0);
    });
  });

  group('makeToolTransfer', () {
    late AccountData data;
    setUp(() {
      data = AccountData();
      data.addAccounts([_account('a'), _account('b'), _account('ex', excludeFromTotal: true)]);
      data.addTool(_moneyTool('a-cash', 'a', quantity: 100, currentValue: 100));
      data.addTool(_moneyTool('a-save', 'a', quantity: 0, currentValue: 0));
      data.addTool(_moneyTool('b-cash', 'b', quantity: 50, currentValue: 50));
      data.addTool(
        ToolSummary(
          id: 'a-dep',
          name: 'a-dep',
          quantity: 1,
          percentageChange: 0,
          accountId: 'a',
          type: ToolType.deposit,
          currentValue: 500,
        ),
      );
    });

    test('within account: value moves 1:1, quantity by unit price, total unchanged', () {
      data.makeToolTransfer(
        fromToolName: 'a-cash',
        fromAccountId: 'a',
        toToolName: 'a-save',
        toAccountId: 'a',
        amount: 40,
        date: DateTime(2026, 10, 10),
      );
      final ToolSummary from = data.tools['a-cash']!;
      final ToolSummary to = data.tools['a-save']!;
      expect(from.currentValue, 60.0);
      expect(from.quantity, 60.0); // unit price was 100/100 = 1
      expect(to.currentValue, 40.0);
      expect(to.quantity, 40.0); // empty dest falls back to rate 1.0
      // Nothing left the account (a: 60 + 40 + 500 deposit = 600; b: 50).
      expect(data.getAccountById('total')!.balance, 650.0);
    });

    test('across accounts with commission: total decreases by commission', () {
      data.makeToolTransfer(
        fromToolName: 'b-cash',
        fromAccountId: 'b',
        toToolName: 'a-cash',
        toAccountId: 'a',
        amount: 10,
        date: DateTime(2026, 10, 10),
        commission: 2,
      );
      expect(data.tools['b-cash']!.currentValue, 38.0); // 50 - 10 - 2
      expect(data.tools['b-cash']!.quantity, 38.0);
      expect(data.tools['a-cash']!.currentValue, 110.0); // 100 + 10
      // a = 610 (110 + 0 + 500 deposit), b = 38 → total 648 (650 - 2).
      expect(data.getAccountById('total')!.balance, 648.0);
    });

    test('insufficient funds are allowed (balance goes negative) — quirk', () {
      data.makeToolTransfer(
        fromToolName: 'a-save',
        fromAccountId: 'a',
        toToolName: 'a-cash',
        toAccountId: 'a',
        amount: 999999,
        date: DateTime(2026, 10, 10),
      );
      expect(data.tools['a-save']!.currentValue, -999999.0); // 0 - 999999
      expect(data.tools['a-cash']!.currentValue, 100.0 + 999999.0);
      // Transfer is within account 'a' → total is unchanged.
      expect(data.getAccountById('total')!.balance, 650.0);
    });

    test('non-money tools are rejected (no changes)', () {
      data.makeToolTransfer(
        fromToolName: 'a-dep',
        fromAccountId: 'a',
        toToolName: 'a-cash',
        toAccountId: 'a',
        amount: 100,
        date: DateTime(2026, 10, 10),
      );
      expect(data.tools['a-dep']!.currentValue, 500.0);
      expect(data.tools['a-cash']!.currentValue, 100.0);
      expect(data.getAccountById('total')!.balance, 650.0);
    });

    test('transfers to/from total account are rejected', () {
      data.makeToolTransfer(
        fromToolName: 'a-cash',
        fromAccountId: 'a',
        toToolName: 'b-cash',
        toAccountId: 'total',
        amount: 10,
        date: DateTime(2026, 10, 10),
      );
      expect(data.tools['a-cash']!.currentValue, 100.0);
      expect(data.tools['b-cash']!.currentValue, 50.0);
    });

    test('zero-quantity USD destination uses fallback rate 90 — quirk', () {
      data.addTool(
        _moneyTool('b-usd', 'b', quantity: 0, currentValue: 0, ticker: 'USD'),
      );
      data.makeToolTransfer(
        fromToolName: 'a-cash',
        fromAccountId: 'a',
        toToolName: 'b-usd',
        toAccountId: 'b',
        amount: 90,
        date: DateTime(2026, 10, 10),
      );
      expect(data.tools['b-usd']!.currentValue, 90.0);
      expect(data.tools['b-usd']!.quantity, 1.0); // 90 RUB / 90 fallback rate
    });
  });

  group('Events', () {
    test('allEvents sorted oldest first, upsert by eventId', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a'), _account('ex', excludeFromTotal: true)]);
      data.addEvent('e2', 'expense', 'Food', '', 'Food', 'a', 'a-cash', 100,
          DateTime(2026, 10, 5));
      data.addEvent('e1', 'income', 'Salary', '', 'Income', 'a', 'a-cash', 1000,
          DateTime(2026, 10, 1));
      data.addEvent('e3', 'income', 'Gift', '', 'Gift', 'ex', 'ex-cash', 50,
          DateTime(2026, 10, 3));

      final List<Event> events = data.allEvents;
      expect(events.map((Event e) => e.eventId).toList(), ['e1', 'e3', 'e2']);

      // Upsert: same id replaces, list length stays.
      data.addEvent('e1', 'income', 'Salary', '', 'Income', 'a', 'a-cash', 2000,
          DateTime(2026, 10, 1));
      expect(data.allEvents.length, 3);
      expect(
        data.allEvents.firstWhere((Event e) => e.eventId == 'e1').amount,
        2000.0,
      );
    });

    test('events of accounts with hideEvents are excluded from allEvents', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a', hideEvents: true), _account('b')]);
      data.addEvent('e1', 'income', 'Hidden', '', 'Income', 'a', 'a-cash', 100,
          DateTime(2026, 10, 1));
      data.addEvent('e2', 'income', 'Visible', '', 'Income', 'b', 'b-cash', 200,
          DateTime(2026, 10, 2));
      expect(data.allEvents.map((Event e) => e.eventId).toList(), ['e2']);
    });
  });

  group('Active account and delete mode', () {
    test('changing active account clears deletable mode', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a'), _account('b')]);
      data.setDeletableAccount('a');
      expect(data.isAccountDeletable('a'), isTrue);

      data.setActiveAccount('b');
      expect(data.isAccountDeletable('a'), isFalse);
    });

    test('setActiveAccount to same id keeps deletable mode', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.setActiveAccount('a'); // no-op: already active
      data.setDeletableAccount('a');
      data.setActiveAccount('a'); // same id → deletable mode preserved
      expect(data.isAccountDeletable('a'), isTrue);
    });
  });

  group('Liabilities (M4: typed tools)', () {
    test('credit stored as negative liability reduces account and total', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a'), _account('b')]);
      data.addTool(_moneyTool('a-cash', 'a', quantity: 100, currentValue: 100));
      data.addTool(_moneyTool('b-cash', 'b', quantity: 50, currentValue: 50));
      // Credits are stored as negative liabilities (addCredit convention).
      data.addTool(
        ToolSummary(
          id: 'a-credit',
          name: 'a-credit',
          quantity: 1,
          percentageChange: -12,
          accountId: 'a',
          type: ToolType.credit,
          currentValue: -30000,
          interestRate: 20,
        ),
      );

      // a = 100 - 30000; total = a + b.
      expect(data.getAccountById('a')!.balance, -29900.0);
      expect(data.getAccountById('total')!.balance, -29850.0);

      // Money-to-money transfer between own accounts keeps the total.
      data.makeToolTransfer(
        fromToolName: 'b-cash',
        fromAccountId: 'b',
        toToolName: 'a-cash',
        toAccountId: 'a',
        amount: 10,
        date: DateTime(2026, 10, 10),
      );
      expect(data.getAccountById('a')!.balance, -29890.0);
      expect(data.getAccountById('total')!.balance, -29850.0);
    });

    test('deposit without start date keeps replayed value (no accrual)', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(
        ToolSummary(
          id: 'a-dep',
          name: 'a-dep',
          quantity: 1,
          percentageChange: 0,
          accountId: 'a',
          type: ToolType.deposit,
          currentValue: 500,
        ),
      );
      // No startDate → no accrual strategy, replayed value as-is.
      expect(data.getAccountById('a')!.balance, 500.0);
      expect(data.getAccountById('total')!.balance, 500.0);
    });
  });

  group('addOtherTool (M: прочее)', () {
    test('без списания: актив добавлен, балансы не изменились', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(_moneyTool('a-cash', 'a', quantity: 100, currentValue: 100));

      data.addOtherTool(
        accountId: 'a',
        name: 'Квартира',
        toolId: 'ot1',
        amount: 5000000,
        quantity: 1,
        withdrawalToolName: null, // «уже в собственности»
      );

      expect(data.getAccountById('a')!.balance, 5000100.0); // 100 + 5 000 000
      expect(data.tools['ot1']!.currentValue, 5000000.0);
      expect(data.tools['a-cash']!.currentValue, 100.0); // не тронут
    });

    test('со списанием: деньги уменьшились на стоимость актива', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(_moneyTool('a-cash', 'a', quantity: 100, currentValue: 100));

      data.addOtherTool(
        accountId: 'a',
        name: 'Автомобиль',
        toolId: 'ot2',
        amount: 1500,
        quantity: 1,
        withdrawalToolName: 'a-cash',
      );

      expect(data.tools['a-cash']!.currentValue, -1400.0); // 100 - 1500
      expect(data.tools['ot2']!.currentValue, 1500.0);
      // Total = -1400 + 1500 = 100 (без изменений: внутренняя покупка).
      expect(data.getAccountById('total')!.balance, 100.0);
    });

    test('переоценка меняет стоимость тула', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(
        ToolSummary(
          id: 'ot1',
          name: 'Дача',
          quantity: 1,
          percentageChange: 0,
          accountId: 'a',
          type: ToolType.other,
          currentValue: 500000,
        ),
      );
      data.revalueOtherTool('Дача', 750000);
      expect(data.tools['ot1']!.currentValue, 750000.0);
      expect(data.getAccountById('a')!.balance, 750000.0);
    });
  });

  group('Tool lookups', () {
    test('getMoneyToolsForAccount returns only money tools', () {
      final AccountData data = AccountData();
      data.addAccounts([_account('a')]);
      data.addTool(_moneyTool('a-cash', 'a', currentValue: 100));
      data.addTool(
        ToolSummary(
          id: 'a-dep',
          name: 'a-dep',
          quantity: 1,
          percentageChange: 0,
          accountId: 'a',
          type: ToolType.deposit,
          currentValue: 500,
        ),
      );
      expect(
        data.getMoneyToolsForAccount('a').map((ToolSummary t) => t.id),
        ['a-cash'],
      );
    });

    test('target display account roundtrip', () {
      final AccountData data = AccountData();
      expect(data.targetDisplayAccount, isNull);
      data.setTargetDisplayAccount('a');
      expect(data.targetDisplayAccount, 'a');
      data.setTargetDisplayAccount(null);
      expect(data.targetDisplayAccount, isNull);
    });
  });
}
