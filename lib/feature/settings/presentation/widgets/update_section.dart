import 'dart:io';

import 'package:flutter/material.dart';
import 'package:capflow/core/updater/apk_installer.dart';
import 'package:capflow/core/updater/update_info.dart';
import 'package:capflow/core/updater/update_service.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Карточка «О приложении»: версия и ручная проверка обновлений.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  final UpdateService _service = UpdateService();

  PackageInfo? _packageInfo;
  bool _checking = false;
  bool _downloading = false;
  bool _upToDate = false;
  double? _progress;
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _check() async {
    if (_checking || _downloading) return;
    setState(() {
      _checking = true;
      _upToDate = false;
    });
    try {
      final UpdateInfo? info = await _service.fetchLatest();
      if (!mounted) return;
      final PackageInfo packageInfo =
          _packageInfo ?? await PackageInfo.fromPlatform();
      final String current = packageInfo.version;
      if (info != null && info.compareTo(current) > 0) {
        setState(() => _update = info);
      } else {
        setState(() {
          _update = null;
          _upToDate = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Toast.show(
        context,
        'Не удалось проверить обновления: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _startUpdate() async {
    final UpdateInfo info = _update!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Обновить до ${info.version}?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Text(
              info.notes.isEmpty
                  ? 'Список изменений не указан.'
                  : info.notes,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (!await ApkInstaller.canInstall()) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Разрешите установку'),
          content: const Text(
            'Чтобы обновить приложение, разрешите ему установку '
            'неизвестных приложений в системных настройках. '
            'После этого вернитесь и нажмите «Обновить» снова.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ApkInstaller.openInstallSettings();
              },
              child: const Text('Открыть настройки'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _downloading = true;
      _progress = null;
    });
    try {
      final File file = await _service.download(
        info,
        onProgress: (double value) {
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );
      if (!mounted) return;
      await ApkInstaller.install(file.path);
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Не удалось обновить: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final PackageInfo? info = _packageInfo;
    final String versionLabel = info == null
        ? 'Версия …'
        : 'Версия ${info.version} (${info.buildNumber})';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CapFlow',
                        style: Theme.of(context).textTheme.titleSmall!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        versionLabel,
                        style: Theme.of(context).textTheme.bodySmall!
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_update != null) ...<Widget>[
              const SizedBox(height: 12),
              Chip(
                avatar: Icon(
                  Icons.new_releases_outlined,
                  size: 18,
                  color: colorScheme.onTertiaryContainer,
                ),
                label: Text('Доступна версия ${_update!.version}'),
                labelStyle: TextStyle(
                  color: colorScheme.onTertiaryContainer,
                ),
                backgroundColor: colorScheme.tertiaryContainer,
                side: BorderSide.none,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _downloading ? null : _startUpdate,
                  icon: const Icon(Icons.system_update),
                  label: Text('Обновить до ${_update!.version}'),
                ),
              ),
            ],
            if (_upToDate) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'У вас последняя версия',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (_checking) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_downloading) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _progress == null
                    ? 'Загрузка…'
                    : 'Загрузка ${(_progress! * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (Platform.isAndroid) ...<Widget>[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _checking || _downloading ? null : _check,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Проверить обновления'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
