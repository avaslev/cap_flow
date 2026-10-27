import 'dart:io';

import 'package:flutter/services.dart';

/// Запуск системного установщика APK на Android.
class ApkInstaller {
  const ApkInstaller._();

  static const MethodChannel _channel = MethodChannel('investflow/updater');

  /// Разрешена ли установка из этого приложения (Android 8+).
  static Future<bool> canInstall() async {
    if (!Platform.isAndroid) return false;
    final bool? result = await _channel.invokeMethod<bool>('canInstall');
    return result ?? false;
  }

  /// Открывает системные настройки «Установка неизвестных приложений».
  static Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  /// Открывает системный установщик для скачанного APK.
  static Future<void> install(String path) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Установка APK поддерживается только на Android');
    }
    await _channel.invokeMethod<void>(
      'install',
      <String, String>{'path': path},
    );
  }
}
