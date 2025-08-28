import 'package:bookstore/core/db.dart';
import 'package:bookstore/data/models/activity.dart';
import 'package:sqflite/sqflite.dart';

class ActivityRepository {

  Future<int> insert(Activity action) async {
    Database db = await DatabaseHelper.instance.db;
    return await db.insert('activities', action.toMap());
  }

  Future<List<Activity>> getActivityList() async {
    Database db = await DatabaseHelper.instance.db;
    final actions = await db.query('activities');
    return actions.map((actionMap) => Activity.fromMap(actionMap)).toList();
  }

  Future<List<Activity>> getActivityListByTool(String toolId) async {
    Database db = await DatabaseHelper.instance.db;
    final actions = await db.query('activities', where: 'toolId = ?', whereArgs: [toolId]);
    return actions.map((actionMap) => Activity.fromMap(actionMap)).toList();
  }

  Future<void> deleteByTool(String toolId) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete('activities', where: 'toolId = ?', whereArgs: [toolId]);
  }
}
