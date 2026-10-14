import 'package:investflow/core/db.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
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

  Future<ScheduledTransaction> getById(String id) async {
    Database db = await DatabaseHelper.instance.db;
    final rows = await db.query(
      'scheduled_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.map((e) => ScheduledTransaction.fromMap(e)).toList().first;
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

  /// Возвращает все запланированные транзакции, которые должны быть
  /// выполнены не позже [toDate].
  ///
  /// Условие выбора:
  ///   • next_execution_date ≤ toDate
  ///   • executed_count < total_executions (ещё есть запланированные запуски)
  ///   • если указана recurrence_end_date, то next_execution_date
  ///     также должна быть ≤ recurrence_end_date
  Future<List<ScheduledTransaction>> getExecutableEvents(DateTime toDate) async {
    final db = await DatabaseHelper.instance.db;

    // Приводим дату к миллисекундам, так как в БД даты хранятся как INTEGER.
    final int toMs = toDate.millisecondsSinceEpoch;

    final rows = await db.query(
      'scheduled_transactions',
      where: '''
        next_execution_date <= ?
        AND (
          (executed_count < total_executions)
          OR (recurrence_type != 'none' AND recurrence_end_date IS NULL)
        )
      ''',
      whereArgs: [toMs],
    );

    // Преобразуем полученные карты в модели.
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

  /// Removes planner records linked to a deposit (interest schedules).
  Future<List<ScheduledTransaction>> getByDepositTool(String toolId) async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'scheduled_transactions',
      where: 'deposit_tool_id = ?',
      whereArgs: [toolId],
    );
    return rows.map(ScheduledTransaction.fromMap).toList();
  }

  Future<void> deleteByDepositTool(String depositToolId) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete(
      'scheduled_transactions',
      where: 'deposit_tool_id = ?',
      whereArgs: [depositToolId],
    );
  }

  Future<void> deleteByAccount(String accountId) async {
    Database db = await DatabaseHelper.instance.db;
    await db.delete(
      'scheduled_transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }
}
