import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_config.dart';
import 'update_info.dart';

/// Ошибка проверки/скачивания обновления с понятным пользователю текстом.
class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Проверка релизов на GitHub и загрузка APK.
class UpdateService {
  Future<UpdateInfo?> fetchLatest() async {
    if (UpdateConfig.manifestUrl.isNotEmpty) {
      return _fetchManifest(UpdateConfig.manifestUrl);
    }
    if (!UpdateConfig.isConfigured) {
      throw UpdateException('Источник обновлений не настроен');
    }
    return _fetchGitHubRelease();
  }

  Future<UpdateInfo?> _fetchManifest(String url) async {
    final Map<String, dynamic> json = await _getJson(Uri.parse(url));
    return parseUpdateManifest(json);
  }

  Future<UpdateInfo?> _fetchGitHubRelease() async {
    final Uri uri = Uri.parse(
      'https://api.github.com/repos/${UpdateConfig.owner}/'
      '${UpdateConfig.repo}/releases/latest',
    );
    final Map<String, dynamic> json = await _getJson(
      uri,
      github: true,
    );
    return parseGitHubRelease(
      json,
      apkAssetName: UpdateConfig.apkAssetName,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, {bool github = false}) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'CapFlow-Updater',
      );
      if (github) {
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/vnd.github+json',
        );
        request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      }
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final String body = await utf8.decoder.bind(response).join();
      if (response.statusCode == HttpStatus.notFound) {
        throw UpdateException('Релизы не найдены');
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw UpdateException(
          'GitHub ограничил частоту запросов, попробуйте позже',
        );
      }
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('Сервер вернул код ${response.statusCode}');
      }
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw UpdateException('Некорректный ответ сервера');
      }
      return decoded;
    } on SocketException {
      throw UpdateException('Нет соединения с интернетом');
    } on TimeoutException {
      throw UpdateException('Превышено время ожидания');
    } on HttpException {
      throw UpdateException('Сетевая ошибка при обращении к серверу');
    } on FormatException {
      throw UpdateException('Некорректный ответ сервера');
    } on HandshakeException {
      throw UpdateException('Ошибка защищённого соединения');
    } finally {
      client.close(force: true);
    }
  }

  /// Скачивает APK во временный каталог и сверяет SHA-256, если он известен.
  Future<File> download(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final Directory dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'updates'),
    );
    if (await dir.exists()) {
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // Не мешаем обновлению из-за недописанного старого файла.
          }
        }
      }
    } else {
      await dir.create(recursive: true);
    }
    final File target = File(
      p.join(dir.path, 'investflow-${info.version}.apk'),
    );

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request = await client.getUrl(
        Uri.parse(info.apkUrl),
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'CapFlow-Updater',
      );
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException(
          'Не удалось скачать обновление (код ${response.statusCode})',
        );
      }

      final int total = response.contentLength;
      final _DigestSink digestSink = _DigestSink();
      final ByteConversionSink digestInput = sha256.startChunkedConversion(
        digestSink,
      );
      final IOSink sink = target.openWrite();
      int received = 0;

      try {
        await for (final List<int> chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          sink.add(chunk);
          digestInput.add(chunk);
          received += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
        digestInput.close();
      }

      if (info.sha256 != null && info.sha256!.isNotEmpty) {
        final String actual = digestSink.value.toString().toLowerCase();
        if (actual != info.sha256!.toLowerCase()) {
          await _tryDelete(target);
          throw UpdateException(
            'Файл обновления повреждён (контрольная сумма не совпала)',
          );
        }
      }
      return target;
    } on UpdateException {
      await _tryDelete(target);
      rethrow;
    } on SocketException {
      await _tryDelete(target);
      throw UpdateException('Нет соединения с интернетом');
    } on TimeoutException {
      await _tryDelete(target);
      throw UpdateException('Загрузка прервана по таймауту');
    } catch (_) {
      await _tryDelete(target);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _tryDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Игнорируем: файл всё равно лежит во временном каталоге.
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
