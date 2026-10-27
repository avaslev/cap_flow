/// Описание доступного обновления.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    this.sha256,
  });

  /// Нормализованная версия без префикса `v` (например, `1.0.5`).
  final String version;
  final String apkUrl;
  final String notes;
  final String? sha256;

  int compareTo(String currentVersion) =>
      compareVersions(version, currentVersion);
}

/// Убирает префикс `v`/`V` и суффикс `+build`.
String normalizeVersion(String raw) {
  String value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  final int plus = value.indexOf('+');
  if (plus >= 0) {
    value = value.substring(0, plus);
  }
  return value;
}

/// Сравнение версий по числовым сегментам: `> 0`, если [a] новее [b].
int compareVersions(String a, String b) {
  final List<int> left = _segments(a);
  final List<int> right = _segments(b);
  final int length = left.length > right.length ? left.length : right.length;
  for (int i = 0; i < length; i++) {
    final int l = i < left.length ? left[i] : 0;
    final int r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

List<int> _segments(String version) {
  final String core = normalizeVersion(version).split('-').first;
  return core
      .split('.')
      .map((String part) => int.tryParse(part) ?? 0)
      .toList();
}

/// Разбор ответа GitHub `GET /releases/latest`.
UpdateInfo? parseGitHubRelease(
  Map<String, dynamic> json, {
  String apkAssetName = 'app-release.apk',
}) {
  final String version = normalizeVersion(json['tag_name'] as String? ?? '');
  if (version.isEmpty) return null;

  final List<dynamic> assets = json['assets'] as List<dynamic>? ?? <dynamic>[];
  Map<String, dynamic>? apk;
  for (final dynamic asset in assets) {
    if (asset is Map<String, dynamic> && asset['name'] == apkAssetName) {
      apk = asset;
      break;
    }
  }
  if (apk == null) {
    for (final dynamic asset in assets) {
      if (asset is Map<String, dynamic> &&
          ((asset['name'] as String?)?.endsWith('.apk') ?? false)) {
        apk = asset;
        break;
      }
    }
  }

  final String? url = apk?['browser_download_url'] as String?;
  if (url == null || url.isEmpty) return null;

  final String? digest = apk?['digest'] as String?;
  final String? sha256 =
      digest != null && digest.startsWith('sha256:')
      ? digest.substring('sha256:'.length)
      : null;

  return UpdateInfo(
    version: version,
    apkUrl: url,
    notes: (json['body'] as String?)?.trim() ?? '',
    sha256: sha256,
  );
}

/// Разбор простого JSON-манифеста (для локальной проверки).
UpdateInfo? parseUpdateManifest(Map<String, dynamic> json) {
  final String version = normalizeVersion(json['version'] as String? ?? '');
  final String? url = json['apkUrl'] as String?;
  if (version.isEmpty || url == null || url.isEmpty) return null;
  return UpdateInfo(
    version: version,
    apkUrl: url,
    notes: (json['notes'] as String?)?.trim() ?? '',
    sha256: json['sha256'] as String?,
  );
}
