import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:investflow/core/app.dart';
import 'package:investflow/core/db.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/core/theme/theme_cubit.dart';
import 'package:investflow/data/repository/settingsRepository.dart';
import 'package:investflow/feature/auth/presentation/pin_screen.dart';
import 'package:investflow/feature/auth/logic/auth_session.dart';
import 'package:investflow/data/repository/currencyRepository.dart';

/// Экран настроек: каркас разделов (внешний вид, данные, о приложении).
/// Переключение темы — рабочее (светлая/тёмная/системная, сохраняется в БД).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, Object?>> _currencies = const <Map<String, Object?>>[];
  String? _defaultCurrency;
  bool _loadingCurrency = true;

  bool _pinEnabled = false;
  int _pinTimeout = 60;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final SettingsRepository repo = SettingsRepository();
    final bool enabled = await repo.getPinEnabled();
    final int timeout = await repo.getPinTimeout();
    if (mounted) {
      setState(() {
        _pinEnabled = enabled;
        _pinTimeout = timeout;
      });
    }
  }

  /// Включение: открыть установку кода; выключение: стереть код.
  Future<void> _togglePin(bool value) async {
    final AuthSession session = AuthSession.of(this.context);
    if (value) {
      await Navigator.of(this.context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) => PinScreen(
            mode: PinScreenMode.setup,
            session: session,
          ),
        ),
      );
      // Код уже применён на экране PIN — перечитываем для тумблера.
      await _loadPin();
      return;
    }
    await session.applyPinSetting(enabled: false);
    await _loadPin();
  }

  Future<void> _pickPinTimeout() async {
    final int? picked = await showModalBottomSheet<int>(
      context: this.context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Блокировать через',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...<int, String>{
              0: 'Сразу',
              60: '1 минуту',
              300: '5 минут',
            }.entries.map<Widget>(
              (MapEntry<int, String> e) => ListTile(
                leading: Icon(
                  _pinTimeout == e.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(e.value),
                onTap: () => Navigator.pop(sheetContext, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      await SettingsRepository().setPinTimeout(picked);
      if (mounted) {
        setState(() => _pinTimeout = picked);
      }
    }
  }

  String get _pinTimeoutLabel => switch (_pinTimeout) {
    0 => 'Сразу',
    60 => '1 минута',
    300 => '5 минут',
    _ => '$_pinTimeout сек',
  };

  Future<void> _loadCurrencies() async {
    final CurrencyRepository currencyRepository = CurrencyRepository();
    final List<Map<String, Object?>> list = await currencyRepository.getList();
    final String defaultCurrency = await currencyRepository
        .getDefaultCurrency();
    if (!mounted) return;
    setState(() {
      _currencies = list;
      _defaultCurrency = defaultCurrency;
      _loadingCurrency = false;
    });
  }

  Future<void> _setDefaultCurrency(String code) async {
    await CurrencyRepository().setDefaultCurrency(code);
    if (mounted) {
      setState(() => _defaultCurrency = code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ─── Внешний вид ───
          _sectionHeader(context, 'Внешний вид'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.palette_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Тема',
                        style: Theme.of(context).textTheme.titleSmall!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (BuildContext context, ThemeMode themeMode) {
                      return SegmentedButton<ThemeMode>(
                        segments: const <ButtonSegment<ThemeMode>>[
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('Системная'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Светлая'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Тёмная'),
                          ),
                        ],
                        selected: <ThemeMode>{themeMode},
                        onSelectionChanged: (Set<ThemeMode> selection) {
                          context.read<ThemeCubit>().setThemeMode(
                            selection.first,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Валюта ───
          _sectionHeader(context, 'Валюта'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _loadingCurrency
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _defaultCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Дефолтная валюта (курс = 1)',
                        prefixIcon: Icon(Icons.currency_exchange),
                      ),
                      items: _currencies
                          .map(
                            (Map<String, Object?> c) =>
                                DropdownMenuItem<String>(
                                  value: c['code'] as String,
                                  child: Text(
                                    '${c['code']} — ${c['name']}',
                                  ),
                                ),
                          )
                          .toList(),
                      onChanged: (String? code) {
                        if (code != null) {
                          _setDefaultCurrency(code);
                        }
                      },
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Данные ───
          _sectionHeader(context, 'Данные'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    Icons.backup_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Создать резервную копию'),
                  subtitle: const Text('Сохранить все данные в файл'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _createBackup(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.restore_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Восстановить из копии'),
                  subtitle: const Text('Загрузить данные из файла'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _restoreBackup(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Безопасность ───
          _sectionHeader(context, 'Безопасность'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Вход по коду'),
                  subtitle: const Text(
                    'Запрашивать 4-значный код при открытии',
                  ),
                  value: _pinEnabled,
                  onChanged: (bool value) => _togglePin(value),
                ),
                if (_pinEnabled) ...<Widget>[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Блокировать без использования'),
                    subtitle: Text('Через: $_pinTimeoutLabel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickPinTimeout(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── О приложении ───
          _sectionHeader(context, 'О приложении'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
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
                          'InvestFlow',
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Версия 1.0.0',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall!.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Создать резервную копию: база целиком сохраняется в файл через
  /// системный диалог «Сохранить как…» (Download, Documents и т.д.).
  Future<void> _createBackup(BuildContext context) async {
    try {
      final DatabaseHelper dbHelper = DatabaseHelper.instance;
      // Чекпоинт WAL, чтобы снять полную копию.
      await dbHelper.backupTo(
        join(await getDatabasesPath(), 'backups', 'investflow_last.db'),
      );
      final Uint8List bytes = await File(await dbHelper.dbPath).readAsBytes();
      final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final Uri? saved = await FilePicker.saveFile(
        fileName: 'investflow_$stamp.db',
        bytes: bytes,
        dialogTitle: 'Сохранить резервную копию',
      );
      if (!context.mounted) return;
      Toast.show(context, saved != null ? 'Копия сохранена' : 'Сохранение отменено',);
    } catch (e) {
      if (context.mounted) {
        Toast.show(context, 'Не удалось создать копию: $e', error: true);
      }
    }
  }

  /// Восстановить базу из файла копии с подтверждением и перезапуском.
  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final PlatformFile? picked = await FilePicker.pickFile(
        type: FileType.any,
      );
      final String? sourcePath = picked?.path;
      if (sourcePath == null || !context.mounted) return;

      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Восстановить из копии?'),
          content: const Text(
            'Все текущие данные будут заменены содержимым файла копии. '
            'Приложение перезапустится автоматически.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 40),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await DatabaseHelper.instance.restoreFrom(sourcePath);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Готово'),
          content: const Text('Данные успешно восстановлены из копии.'),
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 40),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
      // Полный перезапуск UI: новые bloc'ы читают восстановленную базу.
      InvestApp.restartSignal.value++;
    } catch (e) {
      if (context.mounted) {
        Toast.show(context, 'Не удалось восстановить копию: $e', error: true);
      }
    }
  }
}
