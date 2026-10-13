import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:investflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/currencyRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:uuid/uuid.dart';

/// Форма добавления money-тула в выбранной валюте.
///
/// Курс — ручной ввод с автоподстановкой последнего из справочника;
/// RUB-эквивалент = сумма × курс попадает в баланс и Total.
class MoneyForm extends StatefulWidget {
  final AccountData accountData;
  final String accountId;

  const MoneyForm({
    super.key,
    required this.accountData,
    required this.accountId,
  });

  @override
  State<MoneyForm> createState() => _MoneyFormState();
}

class _MoneyFormState extends State<MoneyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  final CurrencyRepository _currencyRepository = CurrencyRepository();
  List<Map<String, Object?>> _currencies = <Map<String, Object?>>[];
  String _selectedCurrency = 'RUB';
  bool _loadingCurrencies = true;

  late final List<ToolSummary> _moneyTools = widget.accountData
      .getMoneyToolsForAccount(widget.accountId);
  bool _deduct = false;
  late String? _selectedSourceToolId = _moneyTools.isNotEmpty
      ? _moneyTools.first.id
      : null;
  bool _saving = false;

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  double get _rate =>
      double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0;

  double get _rubEquivalent => _amount * _rate;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _initDefaultTool();
  }
  Future<void> _initDefaultTool() async {
    final ToolSummary? preferred = await selectDefaultMoneyTool(_moneyTools);
    if (mounted && preferred != null) {
      setState(() => _selectedSourceToolId = preferred.id);
    }
  }


  Future<void> _loadCurrencies() async {
    final List<Map<String, Object?>> list = await _currencyRepository
        .getList();
    if (!mounted) return;
    setState(() {
      _currencies = list;
      _loadingCurrencies = false;
    });
    await _loadRate();
  }

  Future<void> _loadRate() async {
    final double rate = await _currencyRepository.getRate(_selectedCurrency);
    if (!mounted) return;
    setState(() => _rateController.text = rate.toStringAsFixed(4));
  }

  Future<void> _onCurrencyChanged(String? code) async {
    if (code == null || code == _selectedCurrency) return;
    setState(() => _selectedCurrency = code);
    await _loadRate();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_loadingCurrencies) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Добавить деньги',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Валюта',
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                  items: _currencies
                      .map(
                        (Map<String, Object?> c) => DropdownMenuItem<String>(
                          value: c['code'] as String,
                          child: Text(
                            '${c['code']} — ${c['name']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (String? v) => _onCurrencyChanged(v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Сумма в валюте',
                    suffixText: _selectedCurrency,
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  validator: (String? v) {
                    final double? amount = double.tryParse(v ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Введите положительную сумму';
                    }
                    // Уникальность валюты: один money-тул на валюту.
                    final bool exists = widget.accountData
                        .getMoneyToolsForAccount(widget.accountId)
                        .any((ToolSummary t) => t.ticker == _selectedCurrency);
                    if (exists) {
                      return 'Тул в этой валюте уже есть — пополните его';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Курс к RUB',
                    prefixIcon: Icon(Icons.currency_exchange),
                    helperText:
                        'RUB-эквивалент: ${_rubEquivalent.toStringAsFixed(2)} ₽',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (String? v) {
                    final double? rate = double.tryParse(v ?? '');
                    if (rate == null || rate <= 0) {
                      return 'Введите положительный курс';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Списание с money-тула — опционально.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Обменять с money-тула'),
                  subtitle: const Text(
                    'Выключено = просто объявляемая сумма',
                  ),
                  value: _deduct,
                  onChanged: (bool value) => setState(() => _deduct = value),
                ),
                if (_deduct) ...<Widget>[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSourceToolId,
                    decoration: const InputDecoration(
                      labelText: 'Списать с (деньги)',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: _moneyTools
                        .map(
                          (ToolSummary t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(
                              '${t.name} (${t.currentValue.toStringAsFixed(2)} ₽)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) =>
                        setState(() => _selectedSourceToolId = v),
                    validator: (String? v) =>
                        v == null || v.isEmpty ? 'Выберите тул' : null,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.account_balance_wallet),
                  label: Text(_saving ? 'Добавление...' : 'Добавить деньги'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final ToolSummary? sourceTool = _deduct
        ? _moneyTools
              .where((ToolSummary t) => t.id == _selectedSourceToolId)
              .firstOrNull
        : null;
    if (_deduct && sourceTool == null) return;

    // Название тула = название валюты из справочника.
    final String name = _currencies
        .where((Map<String, Object?> c) => c['code'] == _selectedCurrency)
        .map((Map<String, Object?> c) => c['name'] as String)
        .firstOrNull ?? _selectedCurrency;
    final double amount = _amount;
    final double rate = _rate;

    setState(() => _saving = true);
    try {
      final String moneyToolId = const Uuid().v7();

      final Tool moneyTool = Tool(
        id: moneyToolId,
        accountId: widget.accountId,
        name: name,
        type: ToolType.money.name,
        ticker: _selectedCurrency,
      );
      await ToolRepository().insert(moneyTool);

      final DateTime now = DateTime.now();
      final String openName = 'Открытие «$name»';

      // Внутренний обмен: RUB-эквивалент списывается с money-тула-источника.
      if (sourceTool != null) {
        final double rubEquivalent = amount * rate;
        await ActivityRepository().insert(
          Activity(
            id: const Uuid().v7(),
            toolId: sourceTool.id,
            type: ActivityType.substract,
            createAt: now,
            quantity: rubEquivalent,
            price: 1,
            currency: Currency.RUB,
            isTransmit: true,
            name: openName,
          ),
        );
      }

      // Новый тул: quantity = сумма в валюте, price = курс к RUB
      // (replay даёт RUB-эквивалент). Внутреннее перемещение — не доход.
      await ActivityRepository().insert(
        Activity(
          id: const Uuid().v7(),
          toolId: moneyToolId,
          type: ActivityType.add,
          createAt: now,
          quantity: amount,
          price: rate,
          currency: Currency.RUB,
          isTransmit: true,
          name: openName,
        ),
      );

      // Immediate in-memory state (a full refresh happens on sheet close).
      widget.accountData.addMoneyTool(
        accountId: widget.accountId,
        name: name,
        toolId: moneyToolId,
        currencyTicker: _selectedCurrency,
        quantity: amount,
        rate: rate,
        withdrawalToolName: sourceTool?.name,
      );

      if (mounted) {
        Toast.show(context, 'Тул «$name» добавлен');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Не удалось добавить тул: $e', error: true);
        setState(() => _saving = false);
      }
    }
  }
}
