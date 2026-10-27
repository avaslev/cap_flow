import 'package:investflow/data/models/activity.dart';
import 'package:sqflite/sqflite.dart';

/// Связывает старые пары «создание тула с переводом с основного» общим
/// `transfer_pair_id`, чтобы в «Активности» они были одной строкой.
///
/// Новые записи получают id сразу при создании; функция нужна только для
/// данных, созданных до этого. Работает идемпотентно: трогает лишь
/// transmit-записи без пары и только известные шаблоны имён.
Future<void> backfillTransferPairs(Database db) async {
  final List<Map<String, dynamic>> rows = await db.query(
    'activities',
    where: "is_transmit = 1 AND (transfer_pair_id IS NULL OR transfer_pair_id = '')",
  );
  if (rows.isEmpty) return;

  final List<Map<String, dynamic>> toolRows = await db.query(
    'tools',
    columns: <String>['id', 'type'],
  );
  final Map<String, String> toolTypeById = <String, String>{
    for (final Map<String, dynamic> t in toolRows)
      t['id'].toString(): t['type'].toString(),
  };

  final Map<String, String> assignments = computeTransferPairBackfill(
    rows.map((Map<String, dynamic> row) => Activity.fromMap(row)).toList(),
    toolTypeById,
  );
  if (assignments.isEmpty) return;

  await db.transaction((Transaction txn) async {
    for (final MapEntry<String, String> entry in assignments.entries) {
      await txn.update(
        'activities',
        <String, Object?>{'transfer_pair_id': entry.value},
        where: 'id = ?',
        whereArgs: <Object?>[entry.key],
      );
    }
  });
}

/// Чистая часть бэкфилла: для каждой найденной пары возвращает
/// `activityId -> transferPairId`.
Map<String, String> computeTransferPairBackfill(
  List<Activity> activities,
  Map<String, String> toolTypeById,
) {
  final Map<String, String> result = <String, String>{};
  final Map<int, List<Activity>> groups = <int, List<Activity>>{};
  for (final Activity a in activities) {
    if (!a.isTransmit) continue;
    final String? pairId = a.transferPairId;
    if (pairId != null && pairId.isNotEmpty) continue;
    groups
        .putIfAbsent(a.createAt.millisecondsSinceEpoch, () => <Activity>[])
        .add(a);
  }

  for (final List<Activity> group in groups.values) {
    _pairMoneyCreation(group, result);
    _pairDeposit(group, toolTypeById, result);
    _pairCredit(group, toolTypeById, result);
    _pairOther(group, toolTypeById, result);
    _pairInvestmentBuy(group, toolTypeById, result);
    _pairInvestmentSell(group, toolTypeById, result);
  }
  return result;
}

bool _sameValue(Activity a, Activity b) =>
    (a.price * a.quantity - b.price * b.quantity).abs() < 0.01;

String? _quoted(String? value) {
  final RegExpMatch? match = RegExp(r'«(.+)»').firstMatch(value ?? '');
  return match?.group(1);
}

bool _hasType(
  Map<String, String> toolTypeById,
  Activity a,
  String type,
) {
  final String? actual = toolTypeById[a.toolId];
  return actual == null || actual == type;
}

bool _hasAnyType(
  Map<String, String> toolTypeById,
  Activity a,
  Set<String> types,
) {
  final String? actual = toolTypeById[a.toolId];
  return actual == null || types.contains(actual);
}

void _pairUnique({
  required List<Activity> froms,
  required List<Activity> tos,
  required bool Function(Activity from, Activity to) matches,
  required Map<String, String> result,
}) {
  for (final Activity from in froms) {
    if (result.containsKey(from.id)) continue;
    final List<Activity> candidates = tos
        .where(
          (Activity to) => !result.containsKey(to.id) && matches(from, to),
        )
        .toList();
    if (candidates.length != 1) continue;
    final Activity to = candidates.single;
    final List<Activity> reverse = froms
        .where(
          (Activity f) => !result.containsKey(f.id) && matches(f, to),
        )
        .toList();
    if (reverse.length != 1) continue;
    result[from.id] = from.id;
    result[to.id] = from.id;
  }
}

/// money-форма: обе половины называются «Открытие «Валюта»».
void _pairMoneyCreation(List<Activity> group, Map<String, String> result) {
  bool isMoneyOpen(Activity a) =>
      (a.name ?? '').startsWith('Открытие «') &&
      (a.name ?? '').endsWith('»');
  final List<Activity> froms = group
      .where((Activity a) => a.type == ActivityType.substract && isMoneyOpen(a))
      .toList();
  final List<Activity> tos = group
      .where((Activity a) => a.type == ActivityType.add && isMoneyOpen(a))
      .toList();
  _pairUnique(
    froms: froms,
    tos: tos,
    matches: (Activity from, Activity to) =>
        from.name == to.name && _sameValue(from, to),
    result: result,
  );
}

/// Депозит: списание «Открытие депозита «Название»» + зачисление
/// «Открытие депозита».
void _pairDeposit(
  List<Activity> group,
  Map<String, String> toolTypeById,
  Map<String, String> result,
) {
  final List<Activity> froms = group
      .where(
        (Activity a) =>
            a.type == ActivityType.substract &&
            (a.name ?? '').startsWith('Открытие депозита «') &&
            _hasType(toolTypeById, a, 'money'),
      )
      .toList();
  final List<Activity> tos = group
      .where(
        (Activity a) =>
            a.type == ActivityType.add &&
            a.name == 'Открытие депозита' &&
            _hasType(toolTypeById, a, 'deposit'),
      )
      .toList();
  _pairUnique(
    froms: froms,
    tos: tos,
    matches: _sameValue,
    result: result,
  );
}

/// Кредит: списание с кредит-тула + зачисление на money-тул,
/// одинаковое имя «Получение кредита «Название»».
void _pairCredit(
  List<Activity> group,
  Map<String, String> toolTypeById,
  Map<String, String> result,
) {
  bool isCreditName(Activity a) =>
      (a.name ?? '').startsWith('Получение кредита «');
  final List<Activity> froms = group
      .where(
        (Activity a) =>
            a.type == ActivityType.substract &&
            isCreditName(a) &&
            _hasType(toolTypeById, a, 'credit'),
      )
      .toList();
  final List<Activity> tos = group
      .where(
        (Activity a) =>
            a.type == ActivityType.add &&
            isCreditName(a) &&
            _hasType(toolTypeById, a, 'money'),
      )
      .toList();
  _pairUnique(
    froms: froms,
    tos: tos,
    matches: (Activity from, Activity to) =>
        from.name == to.name && _sameValue(from, to),
    result: result,
  );
}

/// Прочий актив: «Покупка актива «Название»» + «Актив «Название»».
void _pairOther(
  List<Activity> group,
  Map<String, String> toolTypeById,
  Map<String, String> result,
) {
  final List<Activity> froms = group
      .where(
        (Activity a) =>
            a.type == ActivityType.substract &&
            (a.name ?? '').startsWith('Покупка актива «') &&
            _hasType(toolTypeById, a, 'money'),
      )
      .toList();
  final List<Activity> tos = group
      .where(
        (Activity a) =>
            a.type == ActivityType.add &&
            (a.name ?? '').startsWith('Актив «') &&
            _hasType(toolTypeById, a, 'other'),
      )
      .toList();
  _pairUnique(
    froms: froms,
    tos: tos,
    matches: (Activity from, Activity to) =>
        _quoted(from.name) == _quoted(to.name) && _sameValue(from, to),
    result: result,
  );
}

/// Покупка инструмента: списание «Buy <name> (money out)» + зачисление
/// «Buy <name>» на stocks/bonds/cryptocurrency-тул.
void _pairInvestmentBuy(
  List<Activity> group,
  Map<String, String> toolTypeById,
  Map<String, String> result,
) {
  final RegExp fromPattern = RegExp(r'^Buy (.+) \(money out\)$');
  final Map<String, String> assetByFromId = <String, String>{};
  final List<Activity> froms = <Activity>[];
  for (final Activity a in group) {
    if (a.type != ActivityType.substract || !a.isTransmit) continue;
    if (!_hasType(toolTypeById, a, 'money')) continue;
    final RegExpMatch? match = fromPattern.firstMatch(a.name ?? '');
    if (match == null) continue;
    assetByFromId[a.id] = match.group(1)!;
    froms.add(a);
  }
  if (froms.isEmpty) return;

  const Set<String> assetTypes = <String>{
    'stocks',
    'bonds',
    'cryptocurrency',
  };
  final List<Activity> tos = group
      .where(
        (Activity a) =>
            a.type == ActivityType.add &&
            a.isTransmit &&
            _hasAnyType(toolTypeById, a, assetTypes) &&
            (a.name ?? '').startsWith('Buy '),
      )
      .toList();

  _pairUnique(
    froms: froms,
    tos: tos,
    matches: (Activity from, Activity to) =>
        to.name == 'Buy ${assetByFromId[from.id]}' && _sameValue(from, to),
    result: result,
  );
}

/// Продажа инструмента: списание «Sell <name>» с stocks/bonds/
/// cryptocurrency-тула + зачисление «Sell <name> (money in)».
///
/// Суммы половин не совпадают (списание идёт по себестоимости),
/// поэтому пара ищется по имени и времени, а не по значению.
void _pairInvestmentSell(
  List<Activity> group,
  Map<String, String> toolTypeById,
  Map<String, String> result,
) {
  final RegExp toPattern = RegExp(r'^Sell (.+) \(money in\)$');
  final Map<String, String> assetByToId = <String, String>{};
  final List<Activity> tos = <Activity>[];
  for (final Activity a in group) {
    if (a.type != ActivityType.add || !a.isTransmit) continue;
    if (!_hasType(toolTypeById, a, 'money')) continue;
    final RegExpMatch? match = toPattern.firstMatch(a.name ?? '');
    if (match == null) continue;
    assetByToId[a.id] = match.group(1)!;
    tos.add(a);
  }
  if (tos.isEmpty) return;

  const Set<String> assetTypes = <String>{
    'stocks',
    'bonds',
    'cryptocurrency',
  };
  final List<Activity> froms = group
      .where(
        (Activity a) =>
            a.type == ActivityType.substract &&
            a.isTransmit &&
            _hasAnyType(toolTypeById, a, assetTypes) &&
            (a.name ?? '').startsWith('Sell ') &&
            !(a.name ?? '').contains('(money in)'),
      )
      .toList();

  _pairUnique(
    froms: froms,
    tos: tos,
    matches: (Activity from, Activity to) =>
        from.name == 'Sell ${assetByToId[to.id]}',
    result: result,
  );
}
