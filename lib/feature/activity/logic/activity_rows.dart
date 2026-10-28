import 'package:capflow/data/models/activity.dart';

/// Строка списка «Активность».
///
/// Пара переводов (списание + зачисление, при наличии — комиссия)
/// показывается одной строкой, остальные операции — по одной.
sealed class ActivityRow {
  const ActivityRow();

  DateTime get date;

  /// Исходные записи, стоящие за строкой (нужны для итогов и фильтров).
  List<Activity> get activities;
}

final class SingleActivityRow extends ActivityRow {
  final Activity activity;

  const SingleActivityRow(this.activity);

  @override
  DateTime get date => activity.createAt;

  @override
  List<Activity> get activities => <Activity>[activity];
}

/// Смысл пары: обычный перевод, покупка или продажа инструмента.
enum TransferKind { transfer, purchase, sale }

/// Определяет смысл пары по именам её половин (их задаёт приложение).
TransferKind transferKindOf(Activity from, Activity to) {
  final String? fromName = from.name;
  final String? toName = to.name;
  if ((toName?.startsWith('Buy ') ?? false) ||
      (toName?.startsWith('Актив «') ?? false)) {
    return TransferKind.purchase;
  }
  if (fromName?.startsWith('Sell ') ?? false) {
    return TransferKind.sale;
  }
  return TransferKind.transfer;
}

final class TransferActivityRow extends ActivityRow {
  /// Половина-списание (уходит со счёта-источника).
  final Activity from;

  /// Половина-зачисление (приходит на счёт-получатель).
  final Activity to;

  /// Комиссия за перевод (расход, не является половиной пары).
  final Activity? commission;

  const TransferActivityRow({
    required this.from,
    required this.to,
    this.commission,
  });

  @override
  DateTime get date => from.createAt;

  @override
  List<Activity> get activities =>
      <Activity>[from, to, if (commission != null) commission!];

  String get transferPairId => from.transferPairId ?? '';

  TransferKind get kind => transferKindOf(from, to);

  /// Сумма в рублях: для продажи — выручка (сторона зачисления),
  /// для остальных пар — списание.
  double get rubAmount => kind == TransferKind.sale
      ? to.price * to.quantity
      : from.price * from.quantity;
}

/// Склеивает половины переводов в [TransferActivityRow].
///
/// Пара считается валидной, только если у записей одинаковый непустой
/// `transfer_pair_id` и среди них ровно одна transmit-половина на списание
/// и одна на зачисление. Иначе каждая запись остаётся отдельной строкой —
/// старые или повреждённые данные не ломают список.
///
/// Порядок строк повторяет порядок входного списка; объединённая строка
/// встаёт на место первой половины пары.
List<ActivityRow> buildActivityRows(List<Activity> activities) {
  final Map<String, List<Activity>> byPair = <String, List<Activity>>{};
  for (final Activity a in activities) {
    final String? pairId = a.transferPairId;
    if (pairId == null || pairId.isEmpty) continue;
    byPair.putIfAbsent(pairId, () => <Activity>[]).add(a);
  }

  final Map<String, TransferActivityRow> merged =
      <String, TransferActivityRow>{};
  final Set<String> consumedIds = <String>{};

  for (final MapEntry<String, List<Activity>> entry in byPair.entries) {
    final List<Activity> froms = entry.value
        .where(
          (Activity a) =>
              a.isTransmit && a.type == ActivityType.substract,
        )
        .toList();
    final List<Activity> tos = entry.value
        .where((Activity a) => a.isTransmit && a.type == ActivityType.add)
        .toList();
    if (froms.length != 1 || tos.length != 1) continue;

    final List<Activity> commissions = entry.value
        .where((Activity a) => !a.isTransmit)
        .toList();
    final Activity? commission =
        commissions.isEmpty ? null : commissions.first;

    final TransferActivityRow row = TransferActivityRow(
      from: froms.single,
      to: tos.single,
      commission: commission,
    );
    merged[entry.key] = row;
    consumedIds.addAll(row.activities.map((Activity a) => a.id));
  }

  final List<ActivityRow> rows = <ActivityRow>[];
  final Set<String> emittedPairs = <String>{};
  for (final Activity a in activities) {
    final String? pairId = a.transferPairId;
    final TransferActivityRow? pair = (pairId != null && pairId.isNotEmpty)
        ? merged[pairId]
        : null;
    if (pair != null && consumedIds.contains(a.id)) {
      if (emittedPairs.add(pairId!)) rows.add(pair);
      continue;
    }
    rows.add(SingleActivityRow(a));
  }
  return rows;
}
