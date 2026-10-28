import 'dart:math' as math;

import 'package:capflow/data/models/tools/tool_kind.dart';

/// Result of splitting a credit payment into interest and principal parts.
class CreditPaymentSplit {
  final double payment; // total paid this month
  final double interest; // part covering interest
  final double principal; // part reducing the outstanding body
  final double outstandingAfter;

  const CreditPaymentSplit({
    required this.payment,
    required this.interest,
    required this.principal,
    required this.outstandingAfter,
  });
}

double _monthlyRate(double annualRate) => annualRate / 100 / 12;

/// Classic annuity monthly payment for a loan.
///
/// A zero-rate loan is paid off in equal parts. [termMonths] and
/// [loanAmount] must be positive.
double annuityMonthlyPayment({
  required double loanAmount,
  required double annualRate,
  required int termMonths,
}) {
  if (loanAmount <= 0 || termMonths <= 0) {
    throw ArgumentError.value(
      loanAmount,
      'loanAmount',
      'loanAmount and termMonths must be positive',
    );
  }
  final double i = _monthlyRate(annualRate);
  if (i == 0) {
    return loanAmount / termMonths;
  }
  final double k = i / (1 - math.pow(1 + i, -termMonths));
  return loanAmount * k;
}

/// Splits payment number [paymentNumber] (1-based) of an annuity schedule.
CreditPaymentSplit annuityPaymentSplit({
  required double loanAmount,
  required double annualRate,
  required int termMonths,
  required int paymentNumber,
}) {
  if (paymentNumber < 1 || paymentNumber > termMonths) {
    throw ArgumentError.value(
      paymentNumber,
      'paymentNumber',
      'must be within 1..termMonths',
    );
  }
  final double i = _monthlyRate(annualRate);
  double outstanding = loanAmount;
  CreditPaymentSplit split = CreditPaymentSplit(
    payment: 0,
    interest: 0,
    principal: 0,
    outstandingAfter: loanAmount,
  );
  // Replay the schedule up to the requested payment to keep the split exact.
  for (int n = 1; n <= paymentNumber; n++) {
    final double interest = outstanding * i;
    double payment =
        termMonths > 0
            ? annuityMonthlyPayment(
              loanAmount: loanAmount,
              annualRate: annualRate,
              termMonths: termMonths,
            )
            : outstanding;
    if (n == termMonths) {
      payment = outstanding + interest; // final payment pays off exactly
    }
    final double principal = (payment - interest).clamp(0.0, outstanding);
    outstanding -= principal;
    split = CreditPaymentSplit(
      payment: payment,
      interest: interest,
      principal: principal,
      outstandingAfter: outstanding,
    );
  }
  return split;
}

/// Splits payment number [paymentNumber] (1-based) of a differentiated
/// schedule: constant principal part, interest on the outstanding balance.
CreditPaymentSplit differentiatedPaymentSplit({
  required double loanAmount,
  required double annualRate,
  required int termMonths,
  required int paymentNumber,
}) {
  if (paymentNumber < 1 || paymentNumber > termMonths) {
    throw ArgumentError.value(
      paymentNumber,
      'paymentNumber',
      'must be within 1..termMonths',
    );
  }
  final double i = _monthlyRate(annualRate);
  final double principalPart = loanAmount / termMonths;
  final double outstandingBefore = loanAmount - principalPart * (paymentNumber - 1);
  final double interest = outstandingBefore * i;
  final double outstandingAfter =
      (outstandingBefore - principalPart).clamp(0.0, double.infinity);
  return CreditPaymentSplit(
    payment: principalPart + interest,
    interest: interest,
    principal: principalPart,
    outstandingAfter: outstandingAfter,
  );
}

/// Splits a payment according to the credit payment type.
CreditPaymentSplit creditPaymentSplit({
  required CreditPaymentType paymentType,
  required double loanAmount,
  required double annualRate,
  required int termMonths,
  required int paymentNumber,
}) {
  return switch (paymentType) {
    CreditPaymentType.annuity => annuityPaymentSplit(
      loanAmount: loanAmount,
      annualRate: annualRate,
      termMonths: termMonths,
      paymentNumber: paymentNumber,
    ),
    CreditPaymentType.differentiated => differentiatedPaymentSplit(
      loanAmount: loanAmount,
      annualRate: annualRate,
      termMonths: termMonths,
      paymentNumber: paymentNumber,
    ),
  };
}
