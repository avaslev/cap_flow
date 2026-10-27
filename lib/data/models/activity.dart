enum ActivityType {add, substract}
enum Currency {RUB, USD, EUR, CNY}

class Activity {
  /// Код валюты (RUB/USD/EUR/CNY) → значение enum.
  /// Неизвестный код приводится к RUB, чтобы `fromMap` не падал на старых
  /// или будущих записях.
  static Currency currencyFromCode(String? code) {
    for (final Currency c in Currency.values) {
      if (c.name == code) return c;
    }
    return Currency.RUB;
  }

  /// Маркер реализованной прибыли: quantity = 0, сумма в price.
  static const String investmentGainName = 'Доход от продажи';

  /// Маркер реализованного убытка: quantity = 0, сумма в price.
  static const String investmentLossName = 'Убыток от продажи';

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
  /// Общий id пары переводов (обе половины: списание и зачисление).
  final String? transferPairId;

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
    this.transferPairId,
  });

  Activity copyWith({
    String? id,
    String? toolId,
    ActivityType? type,
    DateTime? createAt,
    double? quantity,
    double? price,
    Currency? currency,
    bool? isTransmit,
    String? name,
    String? comment,
    String? eventId,
    double? interestAmount,
    double? principalAmount,
    String? transferPairId,
  }) {
    return Activity(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      type: type ?? this.type,
      createAt: createAt ?? this.createAt,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isTransmit: isTransmit ?? this.isTransmit,
      name: name ?? this.name,
      comment: comment ?? this.comment,
      eventId: eventId ?? this.eventId,
      interestAmount: interestAmount ?? this.interestAmount,
      principalAmount: principalAmount ?? this.principalAmount,
      transferPairId: transferPairId ?? this.transferPairId,
    );
  }

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
      'interestAmount': interestAmount,
      'principalAmount': principalAmount,
      'transfer_pair_id': transferPairId,
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
      interestAmount: (map['interestAmount'] as num?)?.toDouble(),
      principalAmount: (map['principalAmount'] as num?)?.toDouble(),
      transferPairId: map['transfer_pair_id']?.toString(),
    );
  }
}
