import 'package:flutter_test/flutter_test.dart';
import 'package:investflow/core/updater/update_info.dart';

void main() {
  group('normalizeVersion', () {
    test('убирает префикс v и суффикс сборки', () {
      expect(normalizeVersion('v1.2.3'), '1.2.3');
      expect(normalizeVersion('V1.2.3+7'), '1.2.3');
      expect(normalizeVersion(' 1.2 '), '1.2');
    });
  });

  group('compareVersions', () {
    test('сравнивает по сегментам', () {
      expect(compareVersions('1.0.5', '1.0.4'), greaterThan(0));
      expect(compareVersions('1.0.4', '1.0.5'), lessThan(0));
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('v2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('игнорирует суффикс prerelease', () {
      expect(compareVersions('1.0.1-beta', '1.0.1'), 0);
    });
  });

  group('parseGitHubRelease', () {
    Map<String, dynamic> release({
      String tag = 'v1.0.5',
      List<Map<String, dynamic>>? assets,
    }) {
      return <String, dynamic>{
        'tag_name': tag,
        'body': '  Что нового: тест  ',
        'assets': assets ??
            <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'app-release.apk',
                'browser_download_url':
                    'https://example.com/app-release.apk',
                'digest': 'sha256:ABC123',
              },
              <String, dynamic>{
                'name': 'notes.txt',
                'browser_download_url': 'https://example.com/notes.txt',
              },
            ],
      };
    }

    test('берёт релизный APK и digest', () {
      final UpdateInfo? info = parseGitHubRelease(release());
      expect(info, isNotNull);
      expect(info!.version, '1.0.5');
      expect(info.apkUrl, 'https://example.com/app-release.apk');
      expect(info.notes, 'Что нового: тест');
      expect(info.sha256, 'ABC123');
    });

    test('падает обратно на любой .apk', () {
      final UpdateInfo? info = parseGitHubRelease(
        release(assets: <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'custom.apk',
            'browser_download_url': 'https://example.com/custom.apk',
          },
        ]),
      );
      expect(info?.apkUrl, 'https://example.com/custom.apk');
      expect(info?.sha256, isNull);
    });

    test('возвращает null без тега или APK', () {
      expect(parseGitHubRelease(release(tag: '')), isNull);
      expect(
        parseGitHubRelease(
          release(assets: <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'notes.txt',
              'browser_download_url': 'https://example.com/notes.txt',
            },
          ]),
        ),
        isNull,
      );
    });

    test('сравнение через UpdateInfo', () {
      final UpdateInfo info = parseGitHubRelease(release())!;
      expect(info.compareTo('1.0.4'), greaterThan(0));
      expect(info.compareTo('1.0.5'), 0);
      expect(info.compareTo('1.0.6'), lessThan(0));
    });
  });

  group('parseUpdateManifest', () {
    test('разбирает локальный манифест', () {
      final UpdateInfo? info = parseUpdateManifest(<String, dynamic>{
        'version': 'v1.0.5',
        'apkUrl': 'http://10.0.2.2:8080/app-release.apk',
        'notes': 'test',
        'sha256': 'ff00',
      });
      expect(info?.version, '1.0.5');
      expect(info?.apkUrl, 'http://10.0.2.2:8080/app-release.apk');
      expect(info?.notes, 'test');
      expect(info?.sha256, 'ff00');
    });

    test('возвращает null без обязательных полей', () {
      expect(parseUpdateManifest(<String, dynamic>{}), isNull);
      expect(
        parseUpdateManifest(<String, dynamic>{'version': '1.0.5'}),
        isNull,
      );
    });
  });
}
