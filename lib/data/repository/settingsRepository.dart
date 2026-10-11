import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:investflow/core/db.dart';

/// Хранилище настроек приложения (key-value в БД).
class SettingsRepository {
  static const String _themeModeKey = 'themeMode';

  Future<ThemeMode> getThemeMode() async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, dynamic>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_themeModeKey],
    );
    if (rows.isEmpty) {
      return ThemeMode.system;
    }
    return switch (rows.first['value'] as String?) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final Database db = await DatabaseHelper.instance.db;
    await db.insert(
      'settings',
      {'key': _themeModeKey, 'value': mode.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
