import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io' show Directory, File;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Map<int, String> migrationScripts = {
  1: '''CREATE TABLE activities (
    id          TEXT (36) PRIMARY KEY NOT NULL,
    tool_id     TEXT      NOT NULL,
    type        TEXT      NOT NULL,
    create_at   INTEGER   NOT NULL,
    quantity     NUMERIC   NOT NULL,
    price       NUMERIC   NOT NULL,
    currency    TEXT      NOT NULL,
    is_transmit INTEGER   NOT NULL,
    name        TEXT,
    comment     TEXT,
    event_id    TEXT 
)''',
  2: '''CREATE TABLE accounts (
    id               TEXT (36) PRIMARY KEY NOT NULL,
    name             TEXT      NOT NULL,
    colorValue       INTEGER   NOT NULL,
    type             NUMERIC   NOT NULL,
    hideEvents       TEXT      NOT NULL,
    excludeFromTotal TEXT      NOT NULL
)''',
  3: '''CREATE TABLE tools (
    id                 TEXT (36) PRIMARY KEY NOT NULL,
    name               TEXT      NOT NULL,
    accountId          TEXT      NOT NULL,
    type               TEXT      NOT NULL,
    ticker             TEXT,
    startDate          INTEGER,
    endDate            INTEGER,
    payType            TEXT,
    interestRate       NUMERIC,
    paymentDayOfMonth  INTEGER,
    faceValue          NUMERIC
)''',
  4: '''CREATE TABLE IF NOT EXISTS scheduled_transactions (
    id                TEXT    PRIMARY KEY,          -- UUID
    account_id        TEXT    NOT NULL,            -- ссылка на аккаунт
    name              TEXT    NOT NULL,
    amount            REAL    NOT NULL,
    type              TEXT    NOT NULL,            -- income | expense | transfer
    category          TEXT    NOT NULL,
    date              INTEGER NOT NULL,            -- epoch‑ms
    wallet_id         TEXT    NOT NULL,
    destination_wallet_id TEXT,                     -- nullable, только для переводов
    comment           TEXT,                        -- nullable
    recurrence_type   TEXT    NOT NULL,            -- none | weekly | monthly | annually | monthlyOnDay
    recurrence_end_date INTEGER,                    -- nullable, epoch‑ms
    recurrence_day_of_month INTEGER,                -- nullable
    -- Поля, отвечающие за планирование выполнения
    next_execution_date     INTEGER NOT NULL,            -- epoch‑ms, дата следующего запуска
    total_executions        INTEGER NOT NULL,            -- общее количество запланированных запусков
    executed_count          INTEGER NOT NULL            -- сколько уже выполнено
)''',
  5: '''ALTER TABLE tools ADD COLUMN termMonths INTEGER''',
  6: '''ALTER TABLE activities ADD COLUMN interestAmount NUMERIC''',
  7: '''ALTER TABLE activities ADD COLUMN principalAmount NUMERIC''',
  8: '''ALTER TABLE tools ADD COLUMN isClosed INTEGER NOT NULL DEFAULT 0''',
  9: '''ALTER TABLE scheduled_transactions ADD COLUMN deposit_tool_id TEXT''',
  10: '''ALTER TABLE tools ADD COLUMN unit TEXT''',
  11: '''ALTER TABLE accounts ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0''',
  12: '''CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
)''',
  13: '''CREATE TABLE IF NOT EXISTS currencies (
    code TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL
)''',
  14: '''INSERT INTO currencies (code, name) VALUES
    ('RUB', 'Рубль'),
    ('USD', 'Доллар США'),
    ('EUR', 'Евро'),
    ('CNY', 'Юань')''',
  15: '''CREATE TABLE IF NOT EXISTS currency_rates (
    code TEXT PRIMARY KEY NOT NULL,
    rate REAL NOT NULL
)''',
  16: '''INSERT INTO currency_rates (code, rate) VALUES ('RUB', 1.0)''',
};

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._instance();
  static Database? _database;

  DatabaseHelper._instance();

  Future<Database> get db async {
    _database ??= await initDb();
    return _database!;
  }

  /// Полный путь к файлу базы данных.
  Future<String> get dbPath async =>
      join(await getDatabasesPath(), 'database.db');

  /// Создать резервную копию: файл базы целиком в указанный путь.
  /// Возвращает путь к копии.
  Future<String> backupTo(String targetPath) async {
    final Database database = await db;
    // Сбросить WAL на диск, чтобы копия была полной.
    await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await Directory(dirname(targetPath)).create(recursive: true);
    await File(await dbPath).copy(targetPath);
    return targetPath;
  }

  /// Восстановить базу из файла копии: закрывает соединение и
  /// подменяет файл базы. Требует перезапуска приложения.
  Future<void> restoreFrom(String sourcePath) async {
    final String target = await dbPath;
    await _database?.close();
    _database = null;
    final File sidecarWal = File('$target-wal');
    final File sidecarShm = File('$target-shm');
    if (await sidecarWal.exists()) await sidecarWal.delete();
    if (await sidecarShm.exists()) await sidecarShm.delete();
    await File(sourcePath).copy(target);
  }

  Future<Database> initDb() async {
    // Use sqflite on MacOS/iOS/Android.
    if (kIsWeb) {
      // Use web implementation on the web.
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      // Use ffi on Linux and Windows.
      if (Platform.isLinux || Platform.isWindows) {
        databaseFactory = databaseFactoryFfi;
        sqfliteFfiInit();
      }
    }
    // count the number of scripts to define the version of the database
    int nbrMigrationScripts = migrationScripts.length;
    var db = await openDatabase(
      join(await getDatabasesPath(), "database.db"),
      version: nbrMigrationScripts,
      // if the database does not exist, onCreate executes all the sql requests of the "migrationScripts" map
      onCreate: (db, version) async {
        for (int i = 1; i <= nbrMigrationScripts; i++) {
          await db.execute(migrationScripts[i]!);
        }
      },

      /// if the database exists but the version of the database is different
      /// from the version defined in parameter, onUpgrade will execute all sql requests greater than the old version
      onUpgrade: (db, oldVersion, newVersion) async {
        for (int i = oldVersion + 1; i <= newVersion; i++) {
          await db.execute(migrationScripts[i]!);
        }
      },
    );
    return db;
  }
}
