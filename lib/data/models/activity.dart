
import 'package:uuid/uuid.dart';

enum ActivityType {add, substract, transmit}
enum Currency {RUB, USD}

class Activity {
  final String id;
  final String toolId;
  final ActivityType type;
  final DateTime createAt;
  final double count;
  final double price;
  final Currency currency;
  final String? name;
  final String? comment;


  Activity({
    required this.id,
    required this.toolId,
    required this.type,
    required this.createAt,
    required this.count,
    required this.price,
    required this.currency,
     this.name,
     this.comment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'toolId': toolId,
      'type': type.name,
      'createAt': createAt.millisecondsSinceEpoch,
      'count': count,
      'price': price,
      'currency': currency.name,
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
      count: double.parse(map['count'].toString()),
      price: double.parse(map['price'].toString()),
      currency: Currency.values.byName(map['currency'].toString()),
      name: map['name'].toString(),
      comment: map['comment'].toString()
    );
  }
}
