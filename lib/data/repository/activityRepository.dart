import 'dart:async';

import 'package:investflow/core/db.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:sqflite/sqflite.dart';

class ActivityRepository {
  /// Изменения, о которых должен узнать открытый список операций
  /// (например, восстановление после Undo уже после закрытия деталей).
  static final StreamController<void> _changed =
      StreamController<void>.broadcast();
  static Stream<void> get changes => _changed.stream;

  static void _notifyChanged() {
    if (!_changed.isClosed) _changed.add(null);
  }

  Future<int> insert(Activity action) async {
    Database db = await DatabaseHelper.instance.db;
    final int id = await db.insert('activities', action.toMap());
    _notifyChanged();
    return id;
  }

  Future<Activity> getById(String id) async {
    Database db = await DatabaseHelper.instance.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) {
      throw Exception('Активность не найдена: $id');
    }
    return Activity.fromMap(maps.first);
  }

  Future<void> delete(String id) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> update(Activity action) async {
    Database db = await DatabaseHelper.instance.db;
    await db.update(
      'activities',
      action.toMap(),
      where: 'id = ?',
      whereArgs: [action.id],
    );
  }

  Future<List<Activity>> getActivityList() async {
    Database db = await DatabaseHelper.instance.db;
    final actions = await db.query('activities');
    return actions.map((actionMap) => Activity.fromMap(actionMap)).toList();
  }

  Future<List<Activity>> getActivityListByTool(String toolId) async {
    Database db = await DatabaseHelper.instance.db;
    final actions = await db.query('activities', where: 'tool_id = ?', whereArgs: [toolId]);
    return actions.map((actionMap) => Activity.fromMap(actionMap)).toList();
  }

  /// Все записи с общим id пары: две половины перевода и комиссия.
  Future<List<Activity>> getByTransferPairId(String pairId) async {
    Database db = await DatabaseHelper.instance.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'transfer_pair_id = ?',
      whereArgs: [pairId],
    );
    return maps.map((Map<String, dynamic> map) => Activity.fromMap(map)).toList();
  }

  /// Атомарно вставляет несколько активностей (например, отмена удаления пары).
  Future<void> insertAll(List<Activity> actions) async {
    if (actions.isEmpty) return;
    Database db = await DatabaseHelper.instance.db;
    await db.transaction((Transaction txn) async {
      for (final Activity action in actions) {
        await txn.insert('activities', action.toMap());
      }
    });
    _notifyChanged();
  }

  /// Атомарно обновляет несколько активностей (например, обе половины перевода).
  Future<void> updateAll(List<Activity> actions) async {
    if (actions.isEmpty) return;
    Database db = await DatabaseHelper.instance.db;
    await db.transaction((Transaction txn) async {
      for (final Activity action in actions) {
        await txn.update(
          'activities',
          action.toMap(),
          where: 'id = ?',
          whereArgs: [action.id],
        );
      }
    });
  }

  Future<void> deleteByTool(String toolId) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete('activities', where: 'tool_id = ?', whereArgs: [toolId]);
  }

  /// Удаляет обе половины перевода по общему id пары.
  Future<void> deleteByTransferPairId(String pairId) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete(
      'activities',
      where: 'transfer_pair_id = ?',
      whereArgs: [pairId],
    );
  }

  /// Удаляет записи по id (пара + связанные НКД/реализованный результат).
  Future<void> deleteAll(List<String> ids) async {
    if (ids.isEmpty) return;
    Database db = await DatabaseHelper.instance.db;
    final String placeholders = List<String>.filled(ids.length, '?').join(', ');
    await db.delete(
      'activities',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Связанные с покупкой/продажей нетранзитные записи в тот же момент:
  /// НКД по деньгам и маркер реализованной прибыли/убытка по инструменту.
  Future<List<Activity>> getPairExtras({
    required String assetToolId,
    required String moneyToolId,
    required DateTime at,
  }) async {
    Database db = await DatabaseHelper.instance.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where:
          "is_transmit = 0 AND create_at = ? "
          "AND (transfer_pair_id IS NULL OR transfer_pair_id = '') "
          "AND ((tool_id = ? AND quantity = 0) "
          "OR (tool_id = ? AND name LIKE ?))",
      whereArgs: <Object?>[
        at.millisecondsSinceEpoch,
        assetToolId,
        moneyToolId,
        'НКД for %',
      ],
    );
    return maps.map((Map<String, dynamic> map) => Activity.fromMap(map)).toList();
  }

  /// Обнуляет ссылки event_id на удалённые плановые события
  /// (иначе остаются висячие id).
  Future<void> clearEventIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    Database db = await DatabaseHelper.instance.db;
    final String placeholders = List<String>.filled(eventIds.length, '?').join(', ');
    await db.rawUpdate(
      'UPDATE activities SET event_id = NULL WHERE event_id IN ($placeholders)',
      eventIds,
    );
  }
}
