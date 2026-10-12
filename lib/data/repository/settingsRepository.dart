import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:investflow/core/db.dart';

/// Хранилище настроек приложения (key-value в БД).
class SettingsRepository {
  static const String _themeModeKey = 'themeMode';

  static const String _defaultCurrencyKey = 'defaultCurrency';

  /// Дефолтная валюта (код: RUB/USD/EUR/CNY). По умолчанию RUB, курс = 1.
  Future<String> getDefaultCurrency() async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_defaultCurrencyKey],
    );
    if (rows.isEmpty) return 'RUB';
    return (rows.first['value'] as String?) ?? 'RUB';
  }

  Future<void> setDefaultCurrency(String code) async {
    final Database db = await DatabaseHelper.instance.db;
    await db.insert(
      'settings',
      {'key': _defaultCurrencyKey, 'value': code},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
