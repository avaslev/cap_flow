import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Map<int, String> migrationScripts = {
  1: '''CREATE TABLE activities (
    id       TEXT (36) PRIMARY KEY NOT NULL,
    toolId   TEXT      NOT NULL,
    type     TEXT      NOT NULL,
    createAt INTEGER   NOT NULL,
    quantity NUMERIC   NOT NULL,
    price    NUMERIC   NOT NULL,
    currency TEXT      NOT NULL,
    isTransmit INTEGER NOT NULL,
    name     TEXT,
    comment  TEXT
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
    quantity           NUMERIC   NOT NULL,
    price              NUMERIC   NOT NULL,
    ticker             TEXT,
    startDate          INTEGER,
    endDate            INTEGER,
    payType            TEXT,
    interestRate       NUMERIC,
    paymentDayOfMonth  INTEGER,
    faceValue          NUMERIC
)''',
};

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._instance();
  static Database? _database;

  DatabaseHelper._instance();

  Future<Database> get db async {
    _database ??= await initDb();
    return _database!;
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
