
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


  Activity({
    required this.id,
    required this.toolId,
    required this.type,
    required this.createAt,
    required this.quantity,
    required this.price,
    required this.currency,
    required this.isTransmit,
     this.name,
     this.comment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'toolId': toolId,
      'type': type.name,
      'createAt': createAt.millisecondsSinceEpoch,
      'quantity': quantity,
      'price': price,
      'currency': currency.name,
      'isTransmit': isTransmit ? 1 : 0,
      'name': name,
      'comment': comment
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    print(map);
    return Activity(
      id: map['id'].toString(),
      toolId: map['toolId'].toString(),
      type: ActivityType.values.byName(map['type'].toString()),
      createAt: DateTime.fromMillisecondsSinceEpoch(int.parse(map['createAt'].toString())),
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toDouble() : 0,
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0,
      currency: Currency.values.byName(map['currency'].toString()),
      isTransmit: map['currency'].toString() == '1',
      name: map['name'].toString(),
      comment: map['comment'].toString()
    );
  }
}
