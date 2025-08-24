
import 'package:uuid/uuid.dart';

enum Type {add, substract}
enum Currency {RUB, USD}

class Activity {
  String id = Uuid().v7();
  late Type type;
  late DateTime createAt;
  late num sum;
  late Currency currency;
  late String name;
  String? comment;

  Activity({required this.id, required this.type, required this.createAt, required this.sum, required this.currency, required this.name, this.comment});
  Activity.money(this.type, this.createAt, this.sum, this.currency, [this.comment = null, this.name = 'Money']);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'createAt': createAt.millisecondsSinceEpoch,
      'sum': sum,
      'currency': currency.name,
      'name': name,
      'comment': comment
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    print(map);
    return Activity(
      id: map['id'],
      type: Type.values.byName(map['type']),
      createAt: DateTime.fromMillisecondsSinceEpoch(map['createAt']),
      sum: map['sum'],
      currency: Currency.values.byName(map['currency']),
      name: map['name'],
      comment: map['comment']
    );
  }
}
