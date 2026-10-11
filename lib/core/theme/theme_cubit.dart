import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/data/repository/settingsRepository.dart';

/// Управляет режимом темы приложения (системная/светлая/тёмная)
/// с сохранением выбора в БД.
class ThemeCubit extends Cubit<ThemeMode> {
  final SettingsRepository _settingsRepository;

  ThemeCubit(this._settingsRepository) : super(ThemeMode.system);

  Future<void> load() async {
    emit(await _settingsRepository.getThemeMode());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settingsRepository.setThemeMode(mode);
    emit(mode);
  }
}
