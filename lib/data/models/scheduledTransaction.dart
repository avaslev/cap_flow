/// Класс, представляющий запланированную транзакцию, сохраняемую в SQLite.
class ScheduledTransaction {
  final String id; // уникальный идентификатор (UUID)
  final String accountId;
  final String name; // название события
  final double amount; // сумма
  final String type; // тип (income, expense, transfer)
  final String category; // категория
  final DateTime date; // дата первой плановой операции
  final String walletId; // исходный кошелёк
  final String? destinationWalletId; // целевой кошелёк (для переводов)
  final String? comment; // необязательный комментарий
  final String recurrenceType; // тип повторения
  final DateTime? recurrenceEndDate; // дата окончания повторения
  final int?
  recurrenceDayOfMonth; // день месяца для RecurrenceType.monthlyOnDay

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
    this.destinationWalletId,
    this.comment,
    this.recurrenceEndDate,
    this.recurrenceDayOfMonth,
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
      recurrenceEndDate:
          map['recurrence_end_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                map['recurrence_end_date'] as int,
              )
              : null,
      recurrenceDayOfMonth: map['recurrence_day_of_month'] as int?,
    );
  }

  @override
  String toString() {
    return 'ScheduledTransaction('
        'id: $id, accountId: $accountId, name: $name, amount: $amount, type: ${type}, '
        'category: $category, date: $date, walletId: $walletId, '
        'destinationWalletId: $destinationWalletId, comment: $comment, '
        'recurrenceType: ${recurrenceType}, '
        'recurrenceEndDate: $recurrenceEndDate, '
        'recurrenceDayOfMonth: $recurrenceDayOfMonth)';
  }
}
