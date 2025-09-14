import 'package:investflow/core/db.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:sqflite/sqflite.dart';

class ScheduledTransactionRepository {
  Future<int> add(ScheduledTransaction scheduledTransaction) async {
    Database db = await DatabaseHelper.instance.db;
    return await db.insert(
      'scheduled_transactions',
      scheduledTransaction.toMap(),
    );
  }

  Future<int> update(ScheduledTransaction scheduledTransaction) async {
    Database db = await DatabaseHelper.instance.db;
    return await db.update(
      'scheduled_transactions',
      scheduledTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [scheduledTransaction.id],
    );
  }

  Future<List<ScheduledTransaction>> getByAccount(String accountId) async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'scheduled_transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return rows.map((e) => ScheduledTransaction.fromMap(e)).toList();
  }

  Future<void> delete(String id) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete(
      'scheduled_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
