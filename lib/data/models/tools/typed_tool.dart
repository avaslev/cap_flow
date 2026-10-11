import 'package:investflow/data/models/tools/tool_kind.dart';

/// Sealed base for typed tools.
///
/// One account may hold any number of tools of any kind — all code must work
/// with collections of [TypedTool] and switch over subtypes, never assume
/// "one deposit per account".
sealed class TypedTool {
  final String id;
  final String accountId;
  final String name;
  final String? ticker;

  /// Lifecycle flag: closed tools keep their history in the DB but are
  /// hidden from display lists.
  final bool isClosed;

  const TypedTool({
    required this.id,
    required this.accountId,
    required this.name,
    this.ticker,
    this.isClosed = false,
  });

  ToolType get kind;
}

/// Cash instrument: `quantity` holds currency units.
class MoneyTool extends TypedTool {
  const MoneyTool({
    required super.id,
    required super.accountId,
    required super.name,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.money;
}

/// Bank deposit: principal grows with accrued interest.
class DepositTool extends TypedTool {
  final double interestRate; // annual, percent
  final DateTime startDate;
  final DateTime? endDate;
  final PayoutType? payoutType;
  final String? withdrawalToolId; // money tool receiving payouts

  const DepositTool({
    required super.id,
    required super.accountId,
    required super.name,
    required this.interestRate,
    required this.startDate,
    this.endDate,
    this.payoutType,
    this.withdrawalToolId,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.deposit;
}

/// Credit/loan: principal outstanding is reduced by payments.
class CreditTool extends TypedTool {
  final double interestRate; // annual, percent
  final DateTime? loanStartDate;
  final int? termMonths;
  final int? paymentDayOfMonth;
  final CreditPaymentType? paymentType;

  const CreditTool({
    required super.id,
    required super.accountId,
    required super.name,
    required this.interestRate,
    this.loanStartDate,
    this.termMonths,
    this.paymentDayOfMonth,
    this.paymentType,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.credit;
}

/// Securities base: quantity × market price.
sealed class SecurityTool extends TypedTool {
  final double? faceValue; // bonds only

  const SecurityTool({
    required super.id,
    required super.accountId,
    required super.name,
    this.faceValue,
    super.ticker,
    super.isClosed,
  });
}

class StockTool extends SecurityTool {
  const StockTool({
    required super.id,
    required super.accountId,
    required super.name,
    super.faceValue,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.stocks;
}

class BondTool extends SecurityTool {
  const BondTool({
    required super.id,
    required super.accountId,
    required super.name,
    super.faceValue,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.bonds;
}

class CryptoTool extends SecurityTool {
  const CryptoTool({
    required super.id,
    required super.accountId,
    required super.name,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.cryptocurrency;
}

/// Manually valued instrument (e.g. real estate, car).
class OtherTool extends TypedTool {
  const OtherTool({
    required super.id,
    required super.accountId,
    required super.name,
    super.ticker,
    super.isClosed,
  });

  @override
  ToolType get kind => ToolType.other;
}
