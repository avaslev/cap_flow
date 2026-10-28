import 'package:flutter/material.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:capflow/data/repository/settingsRepository.dart';
import 'package:capflow/feature/auth/logic/auth_session.dart';

/// Режимы экрана кода.
enum PinScreenMode {
  /// Установка: ввод → повтор → включение функции.
  setup,

  /// Разблокировка: сверка с сохранённым кодом.
  verify,
}

/// Экран кода: цифровая клавиатура 3×4, точки ввода, ошибка при промахе.
class PinScreen extends StatefulWidget {
  final PinScreenMode mode;
  final AuthSession session;

  const PinScreen({super.key, required this.mode, required this.session});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static const int _codeLength = 4;
  String _code = '';
  // Установка: первый ввод хранится здесь для повтора.
  String? _firstCode;
  String? _error;

  String get _title {
    if (widget.mode == PinScreenMode.verify) {
      return 'Введите код';
    }
    return _firstCode == null ? 'Придумайте код' : 'Повторите код';
  }

  void _onDigit(String digit) {
    if (_code.length >= _codeLength) return;
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == _codeLength) {
      _onFullCode();
    }
  }

  void _onBackspace() {
    if (_code.isNotEmpty) {
      setState(() => _code = _code.substring(0, _code.length - 1));
    }
  }

  Future<void> _onFullCode() async {
    if (widget.mode == PinScreenMode.verify) {
      final String saved = await SettingsRepository().getPinCode() ?? '';
      if (_code == saved) {
        widget.session.unlock();
        if (mounted) {
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        }
      } else {
        setState(() {
          _error = 'Неверный код';
          _code = '';
        });
      }
      return;
    }

    // Установка: первый ввод → подтверждение → включение функции.
    if (_firstCode == null) {
      setState(() {
        _firstCode = _code;
        _code = '';
      });
      return;
    }
    if (_code == _firstCode) {
      await widget.session.applyPinSetting(enabled: true, code: _code);
      if (mounted) {
        Toast.show(context, 'Код установлен');
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _error = 'Коды не совпадают, начните заново';
        _firstCode = null;
        _code = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      // Установку можно прервать — функция останется выключенной.
      canPop: true,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
              const SizedBox(height: 24),
              // Точки ввода.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_codeLength, (int i) {
                  final bool filled = i < _code.length;
                  return Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Клавиатура 3×4.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: <Widget>[
                    for (final List<String> row in <List<String>>[
                      <String>['1', '2', '3'],
                      <String>['4', '5', '6'],
                      <String>['7', '8', '9'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          for (final String d in row) _key(context, d),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        const SizedBox(width: 72, height: 72),
                        _key(context, '0'),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: IconButton(
                            onPressed: _onBackspace,
                            icon: Icon(
                              Icons.backspace_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(BuildContext context, String digit) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 72,
      child: InkWell(
        onTap: () => _onDigit(digit),
        borderRadius: BorderRadius.circular(36),
        child: Center(
          child: Text(
            digit,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
