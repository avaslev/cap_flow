enum ActivityType {add, substract}
enum Currency {RUB, USD}

class Activity {
  final String id;
  final String toolId;
  final ActivityType type;
  final DateTime createAt;
  final double quantity;
  final double price;
  final Currency currency;
  final bool isTransmit;
  final String? name;
  final String? comment;
  final String? eventId; // Новое свойство
  final double? interestAmount; // кредит: процентная часть платежа
  final double? principalAmount; // кредит: часть платежа, гасящая тело

  Activity({
    required this.id,
    required this.toolId,
    required this.type,
    required this.createAt,
    required this.quantity,
    required this.price,
    required this.currency,
    required this.isTransmit,
    this.interestAmount,
    this.principalAmount,
    this.name,
    this.comment,
    this.eventId, // Добавлено в конструктор
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tool_id': toolId,
      'type': type.name,
      'create_at': createAt.millisecondsSinceEpoch,
      'quantity': quantity,
      'price': price,
      'currency': currency.name,
      'is_transmit': isTransmit ? 1 : 0,
      'name': name,
      'comment': comment,
      'event_id': eventId, // Добавлено в метод toMap
      'interest_amount': interestAmount,
      'principal_amount': principalAmount,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'].toString(),
      toolId: map['tool_id'].toString(),
      type: ActivityType.values.byName(map['type'].toString()),
      createAt: DateTime.fromMillisecondsSinceEpoch(int.parse(map['create_at'].toString())),
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toDouble() : 0,
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0,
      currency: Currency.values.byName(map['currency'].toString()),
      isTransmit: map['is_transmit'].toString() == '1',
      name: map['name']?.toString(),
      comment: map['comment']?.toString(),
      eventId: map['event_id']?.toString(), // Добавлено в метод fromMap
      interestAmount: (map['interest_amount'] as num?)?.toDouble(),
      principalAmount: (map['principal_amount'] as num?)?.toDouble(),
    );
  }
}
