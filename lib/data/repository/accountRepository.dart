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
    // Архивные (isArchived = 1) не попадают в основной список.
    // total (sortOrder 0) всегда первым, затем по sortOrder.
    final actions = await db.query(
      'accounts',
      where: 'isArchived = 0',
      orderBy: 'sortOrder, id',
    );
    return actions.map((actionMap) => Account.fromMap(actionMap)).toList();
  }

  /// Только скрытые (архивные) счета — для раздела «Архив».
  Future<List<Account>> getArchivedList() async {
    Database db = await DatabaseHelper.instance.db;
    final actions = await db.query(
      'accounts',
      where: 'isArchived = 1',
      orderBy: 'name',
    );
    return actions.map((actionMap) => Account.fromMap(actionMap)).toList();
  }

  /// Скрыть счёт (обратимо): помечает isArchived.
  Future<void> archive(String id) async {
    Database db = await DatabaseHelper.instance.db;
    await db.update('accounts', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Вернуть счёт из архива.
  Future<void> unarchive(String id) async {
    Database db = await DatabaseHelper.instance.db;
    await db.update('accounts', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> changeSortOrder(String id, int sortOrder) async {
    Database db = await DatabaseHelper.instance.db;
    await db.update('accounts', {'sortOrder': sortOrder}, where: 'id = ?', whereArgs: [id]);
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
