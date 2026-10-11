// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:investflow/core/db.dart';
import 'package:investflow/core/theme/theme_cubit.dart';
import 'package:investflow/data/repository/settingsRepository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'core/app.dart';

void main() async {
  // Русская локаль для DateFormat (названия месяцев и т.п.).
  await initializeDateFormatting('ru');
  setupWindow();
  await DatabaseHelper.instance.initDb();

  // Тема: загружаем сохранённый режим до запуска приложения.
  final ThemeCubit themeCubit = ThemeCubit(SettingsRepository());
  await themeCubit.load();

  runApp(InvestApp(themeCubit: themeCubit));
}

const double windowWidth = 1400;
const double windowHeight = 1200;

// project structure https://codexrush.com/blog/the-ideal-flutter-folder-structure-codexrush/

void setupWindow() {
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    setWindowTitle('Navigation and routing');
    setWindowMinSize(const Size(windowWidth, windowHeight));
    setWindowMaxSize(const Size(windowWidth, windowHeight));
    getCurrentScreen().then((screen) {
      setWindowFrame(
        Rect.fromCenter(
          center: screen!.frame.center,
          width: windowWidth,
          height: windowHeight,
        ),
      );
    });
  }
}
