import 'package:investflow/core/db.dart';
import 'package:investflow/data/models/account.dart';
import 'package:sqflite/sqflite.dart';

class AccountRepository {

  Future<int> insert(Account action) async {
    Database db = await DatabaseHelper.instance.db;
    return await db.insert('accounts', action.toMap());
  }

  Future<Account> get(String id) async {
    Database db = await DatabaseHelper.instance.db;
    return Account.fromMap((await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id]
    )).first);
  }

  Future<List<Account>> geList() async {
    Database db = await DatabaseHelper.instance.db;
    final actions = await db.query('accounts', orderBy: 'id');
    return actions.map((actionMap) => Account.fromMap(actionMap)).toList();
  }

  Future<void> changeHideEvents(String id, bool value) async {
    Database db = await DatabaseHelper.instance.db;
    await db.update('accounts', {'hideEvents': value.toString()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> changeExcludeFromTotal(String id, bool value) async {
    Database db = await DatabaseHelper.instance.db;
    await db.update('accounts', {'excludeFromTotal': value.toString()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }
}
