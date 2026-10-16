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

  // ─── Вход по коду (PIN) ───

  /// Включена ли блокировка кодом (по умолчанию выключена).
  Future<bool> getPinEnabled() async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['pinEnabled'],
    );
    return rows.isNotEmpty && (rows.first['value'] as String?) == 'true';
  }

  Future<void> setPinEnabled(bool enabled) async {
    final Database db = await DatabaseHelper.instance.db;
    await db.insert(
      'settings',
      {'key': 'pinEnabled', 'value': enabled ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Код (4 цифры) в открытом виде — локальный замок от любопытных глаз,
  /// сама БД не защищена, хэш не добавляет безопасности.
  Future<String?> getPinCode() async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['pinCode'],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setPinCode(String code) async {
    final Database db = await DatabaseHelper.instance.db;
    await db.insert(
      'settings',
      {'key': 'pinCode', 'value': code},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearPin() async {
    await setPinEnabled(false);
    final Database db = await DatabaseHelper.instance.db;
    await db.delete('settings', where: 'key = ?', whereArgs: ['pinCode']);
  }

  /// Таймаут автоблокировки без использования, секунд: 0 — сразу.
  Future<int> getPinTimeout() async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['pinTimeout'],
    );
    if (rows.isEmpty) return 60;
    return int.tryParse((rows.first['value'] as String?) ?? '') ?? 60;
  }

  Future<void> setPinTimeout(int seconds) async {
    final Database db = await DatabaseHelper.instance.db;
    await db.insert(
      'settings',
      {'key': 'pinTimeout', 'value': seconds.toString()},
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
