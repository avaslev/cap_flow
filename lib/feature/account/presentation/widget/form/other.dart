import 'package:flutter/material.dart';
import 'package:investflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:uuid/uuid.dart';

/// Modal bottom sheet for adding a manually valued asset («прочее»):
/// real estate, car, gold — anything with a hand-set value.
class OtherForm extends StatefulWidget {
  final AccountData accountData;
  final String accountId;

  const OtherForm({
    super.key,
    required this.accountData,
    required this.accountId,
  });

  @override
  State<OtherForm> createState() => _OtherFormState();
}

class _OtherFormState extends State<OtherForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  late final List<ToolSummary> _moneyTools = widget.accountData
      .getMoneyToolsForAccount(widget.accountId);

  bool _deduct = false; // списать стоимость с money-тула
  late String? _selectedMoneyToolId = _moneyTools.isNotEmpty
      ? _moneyTools.first.id
      : null;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final String name = _nameController.text.trim();
    final double value = double.parse(
      _valueController.text.replaceAll(',', '.'),
    );
    // Списание: только если источник выбран.
    ToolSummary? moneyTool;
    if (_deduct) {
      for (final ToolSummary t in _moneyTools) {
        if (t.id == _selectedMoneyToolId) {
          moneyTool = t;
          break;
        }
      }
      if (moneyTool == null) return;
    }

    setState(() => _saving = true);
    try {
      final String otherToolId = const Uuid().v7();

      final Tool otherTool = Tool(
        id: otherToolId,
        accountId: widget.accountId,
        name: name,
        type: ToolType.other.name,
      );
      await ToolRepository().insert(otherTool);

      final DateTime now = DateTime.now();
      final String openName = 'Актив «$name»';

      // Внутреннее перемещение при покупке актива (если указан источник).
      if (moneyTool != null) {
        await ActivityRepository().insert(
          Activity(
            id: const Uuid().v7(),
            toolId: moneyTool.id,
            type: ActivityType.substract,
            createAt: now,
            quantity: value,
            price: 1,
            currency: Currency.RUB,
            isTransmit: true,
            name: 'Покупка актива «$name»',
          ),
        );
      }

      // Стоимость актива: quantity × price = value (replay-friendly).
      await ActivityRepository().insert(
        Activity(
          id: const Uuid().v7(),
          toolId: otherToolId,
          type: ActivityType.add,
          createAt: now,
          quantity: 1,
          price: value,
          currency: Currency.RUB,
          isTransmit: false,
          name: openName,
        ),
      );

      // Immediate in-memory state (a full refresh happens on sheet close).
      widget.accountData.addOtherTool(
        accountId: widget.accountId,
        name: name,
        toolId: otherToolId,
        amount: value,
        withdrawalToolName: moneyTool?.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Актив «$name» добавлен')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить актив: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initDefaultTool();
  }

  Future<void> _initDefaultTool() async {
    final ToolSummary? preferred = await selectDefaultMoneyTool(_moneyTools);
    if (mounted && preferred != null) {
      setState(() => _selectedMoneyToolId = preferred.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

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
                  'Добавить прочее',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Название актива',
                    prefixIcon: Icon(Icons.category),
                  ),
                  validator: (String? v) =>
                      v == null || v.trim().isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Общая стоимость (RUB)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (String? v) {
                    final double? value = double.tryParse(v ?? '');
                    if (value == null || value <= 0) {
                      return 'Введите положительную стоимость';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Списание с money-тула — опционально.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Списать стоимость с money-тула'),
                  subtitle: const Text(
                    'Выключено = актив уже в собственности',
                  ),
                  value: _deduct,
                  onChanged: (bool value) => setState(() => _deduct = value),
                ),
                if (_deduct) ...<Widget>[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMoneyToolId,
                    decoration: const InputDecoration(
                      labelText: 'Списать с (деньги)',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: _moneyTools
                        .map(
                          (ToolSummary t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(
                              '${t.name} (${t.currentValue.toStringAsFixed(2)})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) =>
                        setState(() => _selectedMoneyToolId = v ?? ''),
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
                      : const Icon(Icons.category),
                  label: Text(_saving ? 'Добавление...' : 'Добавить актив'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
