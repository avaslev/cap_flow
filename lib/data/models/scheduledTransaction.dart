class ScheduledTransaction {
  final String id;                       // UUID
  final String accountId;
  final String name;                     // название события
  final double amount;                   // сумма
  final String type;                     // income | expense | transfer
  final String category;                 // категория
  final DateTime date;                   // дата первой плановой операции
  final DateTime nextExecutionDate;      // дата следующего запуска
  final int totalExecutions;             // общее количество запусков
  final int executedCount;               // количество уже выполненных запусков
  final String walletId;                 // исходный кошелёк
  final String? destinationWalletId;     // целевой кошелёк (для переводов)
  final String? comment;                 // необязательный комментарий
  final String? depositToolId;           // связь с депозитом (проценты)
  final String recurrenceType;           // none | weekly | monthly | annually | monthlyOnDay
  final DateTime? recurrenceEndDate;     // дата окончания повторения
  final int? recurrenceDayOfMonth;       // день месяца для RecurrenceType.monthlyOnDay

  const ScheduledTransaction({
    required this.id,
    required this.accountId,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.walletId,
    required this.recurrenceType,
    this.depositToolId,
    this.destinationWalletId,
    this.comment,
    this.recurrenceEndDate,
    this.recurrenceDayOfMonth,
    required this.nextExecutionDate,
    required this.totalExecutions,
    required this.executedCount,
  });

  /// Преобразует объект в `Map<String, dynamic>` — имена колонок
  /// соответствуют стилю snake_case, используемому в таблице.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'name': name,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date.millisecondsSinceEpoch,
      'wallet_id': walletId,
      'destination_wallet_id': destinationWalletId,
      'comment': comment,
      'recurrence_type': recurrenceType,
      'recurrence_end_date': recurrenceEndDate?.millisecondsSinceEpoch,
      'recurrence_day_of_month': recurrenceDayOfMonth,
      // новые колонки
      'next_execution_date': nextExecutionDate.millisecondsSinceEpoch,
      'total_executions': totalExecutions,
      'executed_count': executedCount,
      'deposit_tool_id': depositToolId,
    };
  }

  /// Создаёт объект из карты, полученной из SQLite.
  factory ScheduledTransaction.fromMap(Map<String, dynamic> map) {
    return ScheduledTransaction(
      id: map['id'].toString(),
      accountId: map['account_id'].toString(),
      name: map['name'].toString(),
      amount: (map['amount'] as num).toDouble(),
      type: map['type'].toString(),
      category: map['category'].toString(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      walletId: map['wallet_id'].toString(),
      destinationWalletId: map['destination_wallet_id']?.toString(),
      comment: map['comment']?.toString(),
      recurrenceType: map['recurrence_type'].toString(),
      recurrenceEndDate: map['recurrence_end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['recurrence_end_date'] as int)
          : null,
      recurrenceDayOfMonth: map['recurrence_day_of_month'] as int?,
      // новые поля
      nextExecutionDate: DateTime.fromMillisecondsSinceEpoch(
          map['next_execution_date'] as int),
      totalExecutions: map['total_executions'] as int,
      executedCount: map['executed_count'] as int,
      depositToolId: map['deposit_tool_id']?.toString(),
    );
  }

  @override
  String toString() {
    return 'ScheduledTransaction('
        'id: $id, accountId: $accountId, name: $name, amount: $amount, '
        'type: ${type}, category: $category, date: $date, '
        'walletId: $walletId, destinationWalletId: $destinationWalletId, '
        'comment: $comment, recurrenceType: ${recurrenceType}, '
        'recurrenceEndDate: $recurrenceEndDate, recurrenceDayOfMonth: $recurrenceDayOfMonth, '
        'nextExecutionDate: $nextExecutionDate, totalExecutions: $totalExecutions, '
        'executedCount: $executedCount)';
  }

  /// Создаёт копию с изменёнными полями.
  ScheduledTransaction copyWith({
    String? id,
    String? accountId,
    String? name,
    double? amount,
    String? eType,
    String? category,
    DateTime? date,
    String? walletId,
    String? destinationWalletId,
    String? comment,
    String? recurrenceType,
    DateTime? recurrenceEndDate,
    int? recurrenceDayOfMonth,
    DateTime? nextExecutionDate,
    int? totalExecutions,
    int? executedCount,
    String? depositToolId,
  }) {
    return ScheduledTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: eType ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      walletId: walletId ?? this.walletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      comment: comment ?? this.comment,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceDayOfMonth:
          recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      totalExecutions: totalExecutions ?? this.totalExecutions,
      executedCount: executedCount ?? this.executedCount,
      depositToolId: depositToolId ?? this.depositToolId,
    );
  }
}
