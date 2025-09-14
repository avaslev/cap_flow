import 'package:flutter/material.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';

/// Enum representing the type of a financial event.
enum FinancialEventType {
  income,
  expense,
  transfer,
}

/// Extension to provide display names and icons for FinancialEventType.
extension FinancialEventTypeExtension on FinancialEventType {
  String get displayName {
    switch (this) {
      case FinancialEventType.income:
        return 'Доход';
      case FinancialEventType.expense:
        return 'Расход';
      case FinancialEventType.transfer:
        return 'Перевод';
    }
  }

  IconData get icon {
    switch (this) {
      case FinancialEventType.income:
        return Icons.arrow_upward;
      case FinancialEventType.expense:
        return Icons.arrow_downward;
      case FinancialEventType.transfer:
        return Icons.swap_horiz;
    }
  }

  Color get color {
    switch (this) {
      case FinancialEventType.income:
        return Colors.green;
      case FinancialEventType.expense:
        return Colors.red;
      case FinancialEventType.transfer:
        return Colors.blueGrey;
    }
  }
}

/// Enum representing the recurrence type of a financial event.
enum RecurrenceType {
  none,
  weekly,
  monthly,
  annually,
  monthlyOnDay,
}

/// Extension to provide display names for RecurrenceType.
extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return 'Не повторяется';
      case RecurrenceType.weekly:
        return 'Каждую неделю';
      case RecurrenceType.monthly:
        return 'Каждый месяц (в тот же день)';
      case RecurrenceType.annually:
        return 'Каждый год';
      case RecurrenceType.monthlyOnDay:
        return 'Каждый месяц (в определенный день)';
    }
  }
}

/// Represents a single financial event.
@immutable
class FinancialEvent {
  final String id;
  final String name;
  final double amount;
  final FinancialEventType type;
  final String category;
  final DateTime date;
  final String walletId; // Source wallet for transfers
  final String? destinationWalletId; // Destination wallet for transfers, nullable
  final String? comment; // New: Optional comment field

  final RecurrenceType recurrenceType;
  final DateTime? recurrenceEndDate; // Nullable, end date for recurrence
  final int? recurrenceDayOfMonth; // For MonthlyOnDay, e.g., 15 for 15th of month

  const FinancialEvent({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.walletId,
    this.destinationWalletId, // Make it optional
    this.comment, // Initialize new field
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceEndDate,
    this.recurrenceDayOfMonth,
  });

  /// Creates a copy of this FinancialEvent with optional new values.
  FinancialEvent copyWith({
    String? id,
    String? name,
    double? amount,
    FinancialEventType? type,
    String? category,
    DateTime? date,
    String? walletId,
    String? destinationWalletId,
    String? comment, // Add to copyWith
    RecurrenceType? recurrenceType,
    DateTime? recurrenceEndDate,
    int? recurrenceDayOfMonth,
  }) {
    return FinancialEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      walletId: walletId ?? this.walletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      comment: comment ?? this.comment, // Use new field
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
    );
  }

  @override
  String toString() {
    return 'FinancialEvent(id: $id, name: $name, amount: $amount, type: ${type.displayName}, category: $category, date: $date, walletId: $walletId, destinationWalletId: $destinationWalletId, comment: $comment, recurrenceType: ${recurrenceType.displayName}, recurrenceEndDate: $recurrenceEndDate, recurrenceDayOfMonth: $recurrenceDayOfMonth)';
  }
}

extension FinancialEventX on FinancialEvent {
  ScheduledTransaction toScheduledTransaction(String accountId) => ScheduledTransaction(
        id: id,
        accountId: accountId,
        name: name,
        amount: amount,
        type: type.name,                     // enum → string
        category: category,
        date: date,
        walletId: walletId,
        destinationWalletId: destinationWalletId,
        comment: comment,
        recurrenceType: recurrenceType.name,
        recurrenceEndDate: recurrenceEndDate,
        recurrenceDayOfMonth: recurrenceDayOfMonth,
      );
}