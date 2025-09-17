import 'package:investflow/core/db.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:sqflite/sqflite.dart';

class CategoryRepository {

  /// Returns distinct activity‑categories, joining the `tools` table.
  ///
  /// * `accountId` – filters on `activities.accountId`.
  /// * `toolId`   – filters on `tools.id` (joined via `activities.toolId`).
  /// * If both are `null` the method returns every category present in
  ///   `activities`.
  Future<List<String>> getList(String? accountId, String? toolId) async {
    final Database db = await DatabaseHelper.instance.db;

    // Build the WHERE clause.
    final List<String> whereParts = [];
    final List<dynamic> whereArgs = [];

    if (accountId != null) {
      whereParts.add('tools.accountId = ?');
      whereArgs.add(accountId);
    }

    if (toolId != null) {
      whereParts.add('tools.id = ?');
      whereArgs.add(toolId);
    }

    // Assemble the raw SQL with an INNER JOIN to tools.
    final String sql = '''
      SELECT DISTINCT activities.name
      FROM activities
      LEFT JOIN tools ON activities.toolId = tools.id
      WHERE activities.name IS NOT NULL ${whereParts.isNotEmpty ? 'AND ${whereParts.join(' AND ')}' : ''}
    ''';

    // Execute the query.
    final List<Map<String, Object?>> rows = await db.rawQuery(sql, whereArgs);

    return rows.map((row) => row['name'] as String).toList();
  }
}
