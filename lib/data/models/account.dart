/// Data model for an account summary.
class Account {
  final String id;
  final String name;
  final int colorValue;
  final String type;
  final String hideEvents; // New attribute to hide events for this account
  final String excludeFromTotal; // New attribute to exclude from total balance calculation
  final int sortOrder; // Порядок сортировки счетов (total всегда первый)
  final bool isArchived; // Скрытый (архивный) счёт: не в списке и не в Total

  Account({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.type,
    required this.hideEvents,
    required this.excludeFromTotal,
    this.sortOrder = 0,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'type': type,
      'hideEvents': hideEvents,
      'excludeFromTotal': excludeFromTotal,
      'sortOrder': sortOrder,
      'isArchived': isArchived ? 1 : 0,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'].toString(),
      name: map['name'].toString(),
      colorValue: int.parse(map['colorValue'].toString()),
      type: map['type'].toString(),
      hideEvents: map['hideEvents'].toString(),
      excludeFromTotal: map['excludeFromTotal'].toString(),
      // Порядок счёта (стрелки перестановки) — иначе после перезапуска
      // сортировка падает в fallback по id и порядок «слетает».
      sortOrder: int.tryParse(map['sortOrder']?.toString() ?? '') ?? 0,
      isArchived: map['isArchived']?.toString() == '1',
    );
  }
}
