import 'package:flutter_test/flutter_test.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/models/tools/typed_tool.dart';
import 'package:capflow/data/models/tools/typed_tool_mapper.dart';
import 'package:capflow/feature/account/data/accountDataState.dart';

/// M2 tests: DB row ↔ typed domain model mapping and ToolSummary building.

Tool _dbTool(String type) {
  return Tool(
    id: 't1',
    accountId: 'a1',
    name: 'Test Tool',
    type: type,
    ticker: 'TST',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
    payType: 'monthly',
    interestRate: 15.5,
    paymentDayOfMonth: 10,
    faceValue: 1000,
    termMonths: 12,
  );
}

void main() {
  group('typedToolFromDb selects the right subtype', () {
    test('money ignores type-specific metadata', () {
      final TypedTool tool = typedToolFromDb(_dbTool('money'));
      expect(tool, isA<MoneyTool>());
      expect(tool.kind, ToolType.money);
      expect(tool.id, 't1');
      expect(tool.accountId, 'a1');
      expect(tool.name, 'Test Tool');
      expect(tool.ticker, 'TST');
    });

    test('deposit keeps deposit metadata', () {
      final TypedTool tool = typedToolFromDb(_dbTool('deposit'));
      expect(tool, isA<DepositTool>());
      final DepositTool deposit = tool as DepositTool;
      expect(deposit.interestRate, 15.5);
      expect(deposit.startDate, DateTime(2026, 1, 1));
      expect(deposit.endDate, DateTime(2026, 12, 31));
      expect(deposit.payoutType, PayoutType.monthly);
    });

    test('credit keeps credit metadata incl. termMonths', () {
      final Tool creditRow = Tool(
        id: 't1',
        accountId: 'a1',
        name: 'Test Tool',
        type: 'credit',
        ticker: 'TST',
        startDate: DateTime(2026, 1, 1),
        payType: 'annuity',
        interestRate: 15.5,
        paymentDayOfMonth: 10,
        termMonths: 12,
      );
      final TypedTool tool = typedToolFromDb(creditRow);
      expect(tool, isA<CreditTool>());
      final CreditTool credit = tool as CreditTool;
      expect(credit.interestRate, 15.5);
      expect(credit.loanStartDate, DateTime(2026, 1, 1));
      expect(credit.termMonths, 12);
      expect(credit.paymentDayOfMonth, 10);
      expect(credit.paymentType, CreditPaymentType.annuity);
    });

    test('stock and bond carry faceValue, crypto does not crash', () {
      expect(typedToolFromDb(_dbTool('stocks')), isA<StockTool>());
      expect(
        (typedToolFromDb(_dbTool('bonds')) as BondTool).faceValue,
        1000.0,
      );
      expect(typedToolFromDb(_dbTool('cryptocurrency')), isA<CryptoTool>());
    });

    test('other maps to OtherTool', () {
      expect(typedToolFromDb(_dbTool('other')), isA<OtherTool>());
    });

    test('isClosed roundtrip', () {
      final Tool row = Tool(
        id: 't1',
        accountId: 'a1',
        name: 'Old Deposit',
        type: 'deposit',
        isClosed: true,
      );
      final TypedTool tool = typedToolFromDb(row);
      expect(tool.isClosed, isTrue);
      final Tool back = typedToolToDb(tool);
      expect(back.isClosed, isTrue);
    });

    test('unknown type fails fast', () {
      expect(
        () => typedToolFromDb(_dbTool('gold_bar')),
        throwsArgumentError,
      );
    });
  });

  group('typedToolToDb isolates foreign metadata', () {
    test('money row has no deposit/credit fields', () {
      final Tool row = typedToolToDb(
        const MoneyTool(
          id: 't1',
          accountId: 'a1',
          name: 'Cash',
          ticker: 'RUB',
        ),
      );
      expect(row.type, 'money');
      expect(row.startDate, isNull);
      expect(row.endDate, isNull);
      expect(row.payType, isNull);
      expect(row.interestRate, isNull);
      expect(row.paymentDayOfMonth, isNull);
      expect(row.faceValue, isNull);
      expect(row.termMonths, isNull);
    });

    test('deposit row keeps deposit fields only', () {
      final Tool row = typedToolToDb(
        DepositTool(
          id: 't1',
          accountId: 'a1',
          name: 'Dep',
          interestRate: 15,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 7, 1),
          payoutType: PayoutType.monthly,
        ),
      );
      expect(row.type, 'deposit');
      expect(row.startDate, DateTime(2026, 1, 1));
      expect(row.endDate, DateTime(2026, 7, 1));
      expect(row.payType, 'monthly');
      expect(row.interestRate, 15.0);
      expect(row.paymentDayOfMonth, isNull);
      expect(row.termMonths, isNull);
      expect(row.faceValue, isNull);
    });

    test('credit row keeps credit fields only', () {
      final Tool row = typedToolToDb(
        CreditTool(
          id: 't1',
          accountId: 'a1',
          name: 'Loan',
          interestRate: 20,
          loanStartDate: DateTime(2026, 2, 1),
          termMonths: 24,
          paymentDayOfMonth: 5,
          paymentType: CreditPaymentType.annuity,
        ),
      );
      expect(row.type, 'credit');
      expect(row.startDate, DateTime(2026, 2, 1));
      expect(row.payType, 'annuity');
      expect(row.interestRate, 20.0);
      expect(row.paymentDayOfMonth, 5);
      expect(row.termMonths, 24);
      expect(row.endDate, isNull);
    });

    test('bond row keeps faceValue', () {
      final Tool row = typedToolToDb(
        const BondTool(
          id: 't1',
          accountId: 'a1',
          name: 'Bond',
          faceValue: 1000,
          ticker: 'GOV',
        ),
      );
      expect(row.type, 'bonds');
      expect(row.faceValue, 1000.0);
    });
  });

  group('ToolSummary.fromTyped', () {
    test('deposit metadata flows into the summary', () {
      final ToolSummary summary = ToolSummary.fromTyped(
        DepositTool(
          id: 't1',
          accountId: 'a1',
          name: 'Dep',
          interestRate: 15,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 7, 1),
          payoutType: PayoutType.atEndOfTerm,
          withdrawalToolId: 'cash-1',
        ),
        quantity: 1,
        currentValue: 50000,
        percentageChange: 15,
      );
      expect(summary.type, ToolType.deposit);
      expect(summary.quantity, 1.0);
      expect(summary.currentValue, 50000.0);
      expect(summary.percentageChange, 15.0);
      expect(summary.startDate, DateTime(2026, 1, 1));
      expect(summary.endDate, DateTime(2026, 7, 1));
      expect(summary.payoutType, PayoutType.atEndOfTerm);
      expect(summary.withdrawalToolId, 'cash-1');
      expect(summary.interestRate, 15.0);
    });

    test('credit metadata flows into the summary', () {
      final ToolSummary summary = ToolSummary.fromTyped(
        CreditTool(
          id: 't2',
          accountId: 'a1',
          name: 'Loan',
          interestRate: 20,
          loanStartDate: DateTime(2026, 2, 1),
          termMonths: 24,
          paymentDayOfMonth: 5,
          paymentType: CreditPaymentType.differentiated,
        ),
      );
      expect(summary.type, ToolType.credit);
      expect(summary.loanTermMonths, 24);
      expect(summary.paymentDayOfMonth, 5);
      expect(summary.creditPaymentType, CreditPaymentType.differentiated);
      expect(summary.loanStartDate, DateTime(2026, 2, 1));
    });

    test('security faceValue flows into the summary', () {
      final ToolSummary summary = ToolSummary.fromTyped(
        const BondTool(
          id: 't3',
          accountId: 'a1',
          name: 'Bond',
          faceValue: 1000,
          ticker: 'GOV',
        ),
        quantity: 10,
        currentValue: 980,
      );
      expect(summary.type, ToolType.bonds);
      expect(summary.faceValue, 1000.0);
      expect(summary.ticker, 'GOV');
    });
  });
}
