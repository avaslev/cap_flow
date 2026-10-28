import 'package:flutter_test/flutter_test.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/models/tools/typed_tool.dart';
import 'package:capflow/feature/tools/domain/credit_schedule.dart';
import 'package:capflow/feature/tools/domain/tool_operations.dart';
import 'package:capflow/feature/tools/domain/tool_valuation.dart';

/// M3 tests: valuation strategies, credit schedule math, allowed operations.

void main() {
  group('Deposit valuation', () {
    final DateTime start = DateTime(2026, 1, 1);

    test('no accrued interest before start or on the start day', () {
      expect(
        depositValue(
          principal: 100000,
          annualRate: 15,
          startDate: start,
          asOf: DateTime(2025, 12, 31),
        ),
        100000.0,
      );
      expect(
        depositValue(
          principal: 100000,
          annualRate: 15,
          startDate: start,
          asOf: start,
        ),
        100000.0,
      );
    });

    test('accrues by day: 100000 @ 15% for 365 days = 15000', () {
      expect(
        depositValue(
          principal: 100000,
          annualRate: 15,
          startDate: start,
          asOf: DateTime(2026, 12, 31), // 364 days after start
        ),
        closeTo(100000 + 100000 * 0.15 * 364 / 365, 0.01),
      );
    });

    test('accrual crosses month boundary correctly', () {
      // Jan 1 → Feb 1: 31 days.
      expect(
        depositValue(
          principal: 100000,
          annualRate: 15,
          startDate: start,
          asOf: DateTime(2026, 2, 1),
        ),
        closeTo(100000 + 100000 * 0.15 * 31 / 365, 0.01),
      );
    });

    test('accrual stops at endDate even if asOf is later', () {
      expect(
        depositValue(
          principal: 100000,
          annualRate: 15,
          startDate: start,
          endDate: DateTime(2026, 3, 1), // 59 days of term
          asOf: DateTime(2026, 6, 1),
        ),
        closeTo(100000 + 100000 * 0.15 * 59 / 365, 0.01),
      );
    });
  });

  group('Credit schedule: annuity', () {
    // 100000 @ 12% for 12 months.
    const double loan = 100000;
    const double rate = 12;
    const int term = 12;

    test('monthly payment is constant', () {
      final double payment = annuityMonthlyPayment(
        loanAmount: loan,
        annualRate: rate,
        termMonths: term,
      );
      expect(payment, closeTo(8884.88, 0.01));
    });

    test('zero-rate loan is paid in equal parts', () {
      expect(
        annuityMonthlyPayment(
          loanAmount: loan,
          annualRate: 0,
          termMonths: term,
        ),
        closeTo(8333.33, 0.01),
      );
    });

    test('split: interest decreases, principal grows, sum pays off the loan', () {
      double outstanding = loan;
      double totalInterest = 0;
      for (int n = 1; n <= term; n++) {
        final CreditPaymentSplit split = annuityPaymentSplit(
          loanAmount: loan,
          annualRate: rate,
          termMonths: term,
          paymentNumber: n,
        );
        expect(split.interest, closeTo(outstanding * 0.01, 0.01));
        expect(split.principal, greaterThanOrEqualTo(0));
        outstanding -= split.principal;
        totalInterest += split.interest;
      }
      expect(outstanding, closeTo(0, 0.01));
      expect(totalInterest, greaterThan(0));
    });

    test('final payment pays off the balance exactly', () {
      final CreditPaymentSplit last = annuityPaymentSplit(
        loanAmount: loan,
        annualRate: rate,
        termMonths: term,
        paymentNumber: term,
      );
      expect(last.outstandingAfter, closeTo(0, 0.01));
    });

    test('payment number outside schedule throws', () {
      expect(
        () => annuityPaymentSplit(
          loanAmount: loan,
          annualRate: rate,
          termMonths: term,
          paymentNumber: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => annuityPaymentSplit(
          loanAmount: loan,
          annualRate: rate,
          termMonths: term,
          paymentNumber: term + 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Credit schedule: differentiated', () {
    test('principal part is constant, payment decreases', () {
      const double loan = 120000;
      const double rate = 12;
      const int term = 12;

      CreditPaymentSplit previous = differentiatedPaymentSplit(
        loanAmount: loan,
        annualRate: rate,
        termMonths: term,
        paymentNumber: 1,
      );
      expect(previous.principal, closeTo(10000, 0.01));

      double outstanding = loan;
      for (int n = 1; n <= term; n++) {
        final CreditPaymentSplit split = differentiatedPaymentSplit(
          loanAmount: loan,
          annualRate: rate,
          termMonths: term,
          paymentNumber: n,
        );
        expect(split.principal, closeTo(10000, 0.01));
        expect(split.interest, closeTo(outstanding * 0.01, 0.01));
        outstanding = split.outstandingAfter;
        if (n > 1) {
          expect(split.payment, lessThan(previous.payment));
        }
        previous = split;
      }
      expect(outstanding, 0.0);
    });
  });

  group('Credit outstanding valuation', () {
    test('zero payments → full loan amount', () {
      expect(
        creditOutstandingValue(
          loanAmount: 100000,
          annualRate: 12,
          termMonths: 12,
          paymentType: CreditPaymentType.annuity,
          paymentsMade: 0,
        ),
        100000.0,
      );
    });

    test('annuity: after half the term roughly half the body is paid', () {
      final double outstanding = creditOutstandingValue(
        loanAmount: 100000,
        annualRate: 12,
        termMonths: 12,
        paymentType: CreditPaymentType.annuity,
        paymentsMade: 6,
      );
      expect(outstanding, greaterThan(40000));
      expect(outstanding, lessThan(60000));
    });

    test('differentiated: after 6 of 12 → exactly half', () {
      expect(
        creditOutstandingValue(
          loanAmount: 120000,
          annualRate: 12,
          termMonths: 12,
          paymentType: CreditPaymentType.differentiated,
          paymentsMade: 6,
        ),
        closeTo(60000, 0.01),
      );
    });
  });

  group('Allowed operations per kind', () {
    test('money: top-up/withdraw/transfers', () {
      final Set<ToolOperationType> ops = allowedOperations(
        const MoneyTool(id: 't', accountId: 'a', name: 'Cash'),
      );
      expect(ops, containsAll(<ToolOperationType>[
        ToolOperationType.topUp,
        ToolOperationType.withdraw,
        ToolOperationType.transferOut,
      ]));
      expect(ops.contains(ToolOperationType.creditPayment), isFalse);
    });

    test('deposit: top-up/withdraw/interest payout/mature', () {
      final Set<ToolOperationType> ops = allowedOperations(
        DepositTool(
          id: 't',
          accountId: 'a',
          name: 'Dep',
          interestRate: 15,
          startDate: DateTime(2026, 1, 1),
        ),
      );
      expect(
        ops,
        containsAll(<ToolOperationType>[
          ToolOperationType.topUp,
          ToolOperationType.withdraw,
          ToolOperationType.interestPayout,
          ToolOperationType.mature,
        ]),
      );
      expect(ops.contains(ToolOperationType.buy), isFalse);
    });

    test('credit: payment and early repayment, no withdraw', () {
      final Set<ToolOperationType> ops = allowedOperations(
        const CreditTool(id: 't', accountId: 'a', name: 'Loan', interestRate: 20),
      );
      expect(
        ops,
        containsAll(<ToolOperationType>[
          ToolOperationType.creditPayment,
          ToolOperationType.earlyRepayment,
        ]),
      );
      expect(ops.contains(ToolOperationType.withdraw), isFalse);
    });

    test('security: buy/sell; other: sell', () {
      expect(
        allowedOperations(
          const StockTool(id: 't', accountId: 'a', name: 'AAPL'),
        ),
        containsAll(<ToolOperationType>[
          ToolOperationType.buy,
          ToolOperationType.sell,
        ]),
      );
      expect(
        allowedOperations(
          const OtherTool(id: 't', accountId: 'a', name: 'Car'),
        ),
        <ToolOperationType>{ToolOperationType.sell},
      );
    });

    test('transfers only between money tools', () {
      expect(canAcceptTransfer(const MoneyTool(id: 't', accountId: 'a', name: 'C')), isTrue);
      expect(canAcceptTransfer(DepositTool(id: 't', accountId: 'a', name: 'D', interestRate: 10, startDate: DateTime(2026))), isFalse);
    });
  });
}
