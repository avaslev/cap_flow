import 'package:investflow/core/db.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:sqflite/sqflite.dart';

class ActivityRepository {

  Future<int> insert(Activity action) async {
    Database db = await DatabaseHelper.instance.db;
    return await db.insert('activities', action.toMap());
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
