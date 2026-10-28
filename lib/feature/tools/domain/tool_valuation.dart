import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/models/tools/typed_tool.dart';
import 'package:capflow/feature/tools/domain/credit_schedule.dart';

/// Valuation strategies per tool kind. All values are in account currency
/// (RUB equivalent).

/// Cash: value equals the replayed quantity (RUB equivalent).
double moneyValue(double quantity) => quantity;

/// Securities: quantity × market price.
double securitiesValue({required double quantity, required double price}) =>
    quantity * price;

/// Manually valued instrument.
double otherValue(double manualValue) => manualValue;

/// Deposit: principal plus interest accrued by day, capped at [endDate].
///
/// Interest = principal × rate/100 × days/365, where days counts from
/// [startDate]; a day is counted starting from the start date. [asOf] before
/// the start date yields zero accrued interest. When [endDate] is set, the
/// accrual stops at the end of the term.
double depositValue({
  required double principal,
  required double annualRate,
  required DateTime startDate,
  DateTime? endDate,
  required DateTime asOf,
}) {
  final DateTime effectiveEnd = (endDate != null && endDate.isBefore(asOf))
      ? endDate
      : asOf;
  final DateTime startDay = DateTime(startDate.year, startDate.month, startDate.day);
  final DateTime endDay = DateTime(
    effectiveEnd.year,
    effectiveEnd.month,
    effectiveEnd.day,
  );
  final int days = endDay.difference(startDay).inDays;
  if (days <= 0) {
    return principal;
  }
  final double accrued = principal * (annualRate / 100) * days / 365;
  return principal + accrued;
}

/// Credit: outstanding body after [paymentsMade] payments of the schedule.
///
/// The returned value is positive; account/total aggregation subtracts it
/// (the credit is a liability). When the loan is not started yet
/// ([paymentsMade] == 0) the full loan amount is outstanding.
double creditOutstandingValue({
  required double loanAmount,
  required double annualRate,
  required int termMonths,
  required CreditPaymentType paymentType,
  required int paymentsMade,
}) {
  if (paymentsMade <= 0) {
    return loanAmount;
  }
  final CreditPaymentSplit split = creditPaymentSplit(
    paymentType: paymentType,
    loanAmount: loanAmount,
    annualRate: annualRate,
    termMonths: termMonths,
    paymentNumber: paymentsMade.clamp(1, termMonths),
  );
  return split.outstandingAfter;
}

/// Top-level entry: current value of a typed tool.
double toolCurrentValue({
  required TypedTool tool,
  required double replayedValue,
  required double quantity,
  DateTime? asOf,
  double lastPrice = 1.0,
}) {
  final DateTime at = asOf ?? DateTime.now();
  return switch (tool) {
    MoneyTool() => moneyValue(quantity),
    DepositTool t => depositValue(
      principal: replayedValue,
      annualRate: t.interestRate,
      startDate: t.startDate,
      endDate: t.endDate,
      asOf: at,
    ),
    CreditTool t => creditOutstandingValue(
      loanAmount: replayedValue,
      annualRate: t.interestRate,
      termMonths: t.termMonths ?? 0,
      paymentType: t.paymentType ?? CreditPaymentType.annuity,
      paymentsMade: 0, // wired to the execution counters in M4
    ),
    SecurityTool() => securitiesValue(quantity: quantity, price: lastPrice),
    OtherTool() => otherValue(replayedValue),
  };
}
