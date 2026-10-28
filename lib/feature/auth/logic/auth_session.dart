// Copyright 2021, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:capflow/data/repository/settingsRepository.dart';

/// Сессия приложения: вход и блокировка кодом (PIN).
class AuthSession extends ChangeNotifier {
  bool _signedIn = true;

  bool get signedIn => _signedIn;

  /// Функция входа по коду включена в настройках.
  bool _pinEnabled = false;
  bool get pinEnabled => _pinEnabled;

  /// Приложение заблокировано — требуется ввод кода.
  bool _pinLocked = false;
  bool get pinLocked => _pinLocked;

  /// Загрузить состояние PIN при старте приложения:
  /// включённая функция блокирует холодный старт сразу.
  Future<void> loadPinState() async {
    final SettingsRepository repo = SettingsRepository();
    _pinEnabled = await repo.getPinEnabled();
    if (_pinEnabled) {
      _pinLocked = true;
    }
    notifyListeners();
  }

  /// Включить функцию с кодом (после успешной установки на экране PIN)
  /// либо выключить (код стирается). Синхронизирует флаг для роутера.
  Future<void> applyPinSetting({required bool enabled, String? code}) async {
    final SettingsRepository repo = SettingsRepository();
    if (enabled && code != null) {
      await repo.setPinCode(code);
      await repo.setPinEnabled(true);
      _pinEnabled = true;
      // Сессия считается активной до следующего ухода в фон.
    } else {
      await repo.clearPin();
      _pinEnabled = false;
      _pinLocked = false;
    }
    notifyListeners();
  }

  void lock() {
    if (_pinEnabled && !_pinLocked) {
      _pinLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    if (_pinLocked) {
      _pinLocked = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Sign out.
    _signedIn = false;
    notifyListeners();
  }

  Future<bool> signIn(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Sign in. Allow any password.
    _signedIn = true;
    notifyListeners();
    return _signedIn;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthSession && other._signedIn == _signedIn;

  @override
  int get hashCode => _signedIn.hashCode;

  static AuthSession of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AuthSessionScope>()!
          .notifier!;
}

class AuthSessionScope extends InheritedNotifier<AuthSession> {
  const AuthSessionScope({
    required super.notifier,
    required super.child,
    super.key,
  });
}
