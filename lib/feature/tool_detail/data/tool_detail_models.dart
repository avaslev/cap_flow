/// Data models specific to the tool_detail feature.
///
/// This file contains models that are isolated within the tool_detail module
/// to avoid cross-module dependencies.

/// Model for displaying tool detail information.
/// This is a simplified version of ToolSummary that doesn't rely
/// on the account feature.
class ToolDetailDisplay {
  final String id;
  final String name;
  final double quantity;
  final double percentageChange;
  final String accountId;
  final String type;
  final double currentValue;
  final String? ticker;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? payoutType;
  final String? withdrawalToolId;
  final double? interestRate;
  final DateTime? loanStartDate;
  final int? loanTermMonths;
  final int? paymentDayOfMonth;
  final String? creditPaymentType;
  final double? faceValue;

  const ToolDetailDisplay({
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
    this.faceValue,
  });

  /// Creates a ToolDetailDisplay from a Tool model.
  factory ToolDetailDisplay.fromTool(dynamic tool) {
    return ToolDetailDisplay(
      id: tool.id,
      name: tool.name,
      quantity: 0.0, // Will be calculated from events if needed
      percentageChange: 0.0, // Will be calculated based on price changes
      accountId: tool.accountId,
      type: tool.type,
      currentValue: 0.0, // Will be calculated from events
      ticker: tool.ticker,
      startDate: tool.startDate,
      endDate: tool.endDate,
      payoutType: null, // Not available in Tool model
      withdrawalToolId: null, // Not available in Tool model
      interestRate: tool.interestRate,
      loanStartDate: null, // Not available in Tool model
      loanTermMonths: null, // Not available in Tool model
      paymentDayOfMonth: tool.paymentDayOfMonth,
      creditPaymentType: null, // Not available in Tool model
      faceValue: tool.faceValue,
    );
  }

  /// Converts to a map for potential serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'percentageChange': percentageChange,
      'accountId': accountId,
      'type': type,
      'currentValue': currentValue,
      'ticker': ticker,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'payoutType': payoutType,
      'withdrawalToolId': withdrawalToolId,
      'interestRate': interestRate,
      'loanStartDate': loanStartDate?.millisecondsSinceEpoch,
      'loanTermMonths': loanTermMonths,
      'paymentDayOfMonth': paymentDayOfMonth,
      'creditPaymentType': creditPaymentType,
      'faceValue': faceValue,
    };
  }
}