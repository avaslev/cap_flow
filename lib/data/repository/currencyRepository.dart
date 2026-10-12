import 'package:investflow/core/db.dart';
import 'package:investflow/data/repository/settingsRepository.dart';
import 'package:sqflite/sqflite.dart';

/// Справочник валют и курсов к дефолтной валюте.
/// Последний введённый курс при операции сохраняется здесь же.
class CurrencyRepository {
  Future<List<Map<String, Object?>>> getList() async {
    final Database db = await DatabaseHelper.instance.db;
    return db.query('currencies', orderBy: 'code');
  }

  Future<String> getName(String code) async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'currencies',
      where: 'code = ?',
      whereArgs: [code],
    );
    return rows.isNotEmpty ? (rows.first['name'] as String) : code;
  }

  /// Последний курс валюты к дефолтной. Если курса нет — 0
  /// (форма потребует ручного ввода).
  Future<double> getRate(String code) async {
    final Database db = await DatabaseHelper.instance.db;
    final List<Map<String, Object?>> rows = await db.query(
      'currency_rates',
      where: 'code = ?',
      whereArgs: [code],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['rate'] as num?)?.toDouble() ?? 0;
  }

  /// Дефолтная валюта (из settings), по умолчанию RUB.
  Future<String> getDefaultCurrency() async {
    return SettingsRepository().getDefaultCurrency();
  }

  Future<void> setDefaultCurrency(String code) async {
    await SettingsRepository().setDefaultCurrency(code);
  }

  /// Сохранить последний курс валюты.
  Future<void> setRate(String code, double rate) async {
    final Database db = await DatabaseHelper.instance.db;
    await db.insert(
      'currency_rates',
      {'code': code, 'rate': rate},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
