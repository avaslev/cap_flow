/// Настройки источника обновлений.
///
/// По умолчанию — публичный репозиторий GitHub с релизами APK.
/// Можно переопределить при сборке:
/// `--dart-define=UPDATE_REPO_OWNER=... --dart-define=UPDATE_REPO_NAME=...`
/// `--dart-define=UPDATE_MANIFEST_URL=...` (для локальной проверки).
class UpdateConfig {
  const UpdateConfig._();

  static const String owner = String.fromEnvironment(
    'UPDATE_REPO_OWNER',
    defaultValue: 'avaslev',
  );

  static const String repo = String.fromEnvironment(
    'UPDATE_REPO_NAME',
    defaultValue: 'cap_flow',
  );

  /// Прямая ссылка на JSON-манифест (переопределяет GitHub API).
  /// Ожидаемый формат: {version, apkUrl, notes, sha256?}.
  static const String manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
  );

  static const String apkAssetName = 'app-release.apk';

  static bool get isConfigured =>
      manifestUrl.isNotEmpty || (owner.isNotEmpty && repo.isNotEmpty);
}
