import 'package:bookstore/core/db.dart';
import 'package:bookstore/data/models/tool.dart';
import 'package:sqflite/sqflite.dart';

class Toolrepository {

  Future<int> insert(Tool tool) async {
    Database db = await DatabaseHelper.instance.db;
    return await db.insert('tools', tool.toMap());
  }

  Future<Tool> get(String id) async {
    Database db = await DatabaseHelper.instance.db;
    print((await db.query(
      'tools',
      where: 'id = ?',
      whereArgs: [id]
    )).first);
    return Tool.fromMap((await db.query(
      'tools',
      where: 'id = ?',
      whereArgs: [id]
    )).first);
  }

  Future<List<Tool>> geList() async {
    Database db = await DatabaseHelper.instance.db;
    final tools = await db.query('tools');
    return tools.map((actionMap) => Tool.fromMap(actionMap)).toList();
  }

  Future<void> delete(String id) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete('tools', where: 'id = ?', whereArgs: [id]);
  }
}
