import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capflow/core/utils/formatCurrency.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:capflow/data/models/scheduledTransaction.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/feature/tool_detail/data/tool_detail_repository.dart';

/// Ручной платёж по кредиту: тело уходит переводом на кредит-тул,
/// проценты списываются отдельным расходом. Планировщик не меняется.
/// Возвращает списанную сумму или null, если форма отменена.
Future<double?> showCreditPaymentSheet(
  BuildContext context, {
  required String accountId,
  required String toolId,
  required String toolName,
  required double outstanding,
}) async {
  final ToolDetailRepository repository = ToolDetailRepository();
  final Tool credit = await repository.getTool(toolId);
  final String currency = credit.ticker ?? 'RUB';
  final List<Tool> moneyTools = await repository.getAccountMoneyTools(
    accountId,
    currency: currency,
  );
  if (!context.mounted) return null;
  if (moneyTools.isEmpty) {
    Toast.show(
      context,
      'Нет денежного тула в валюте $currency для списания',
      error: true,
    );
    return null;
  }

  final List<ScheduledTransaction> scheduled =
      await ScheduledTransactionRepository().getByDepositTool(toolId);
  final List<ScheduledTransaction> pending =
      scheduled
          .where(
            (ScheduledTransaction e) => e.executedCount < e.totalExecutions,
          )
          .toList()
        ..sort(
          (ScheduledTransaction a, ScheduledTransaction b) =>
              a.nextExecutionDate.compareTo(b.nextExecutionDate),
        );

  double? scheduledPrincipal;
  double? scheduledInterest;
  for (final ScheduledTransaction event in pending) {
    if (event.type == 'expense') {
      scheduledInterest ??= _round2(event.amount);
    } else if (event.type == 'transfer') {
      scheduledPrincipal ??= _round2(event.amount);
    }
  }
  final double principal = scheduledPrincipal ?? 0;
  final double interest =
      scheduledInterest ??
      _round2(outstanding * (credit.interestRate ?? 0) / 100 / 12);

  if (!context.mounted) return null;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    clipBehavior: Clip.antiAliasWithSaveLayer,
    builder:
        (BuildContext sheetContext) => _CreditPaymentSheet(
          accountId: accountId,
          toolId: toolId,
          toolName: toolName,
          outstanding: outstanding,
          currency: currency,
          moneyTools: moneyTools,
          initialPrincipal: principal,
          initialInterest: interest,
          initialDate: DateTime.now(),
        ),
  );
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

class _CreditPaymentSheet extends StatefulWidget {
  final String accountId;
  final String toolId;
  final String toolName;
  final double outstanding;
  final String currency;
  final List<Tool> moneyTools;
  final double initialPrincipal;
  final double initialInterest;
  final DateTime initialDate;

  const _CreditPaymentSheet({
    required this.accountId,
    required this.toolId,
    required this.toolName,
    required this.outstanding,
    required this.currency,
    required this.moneyTools,
    required this.initialPrincipal,
    required this.initialInterest,
    required this.initialDate,
  });

  @override
  State<_CreditPaymentSheet> createState() => _CreditPaymentSheetState();
}

class _CreditPaymentSheetState extends State<_CreditPaymentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _principalController;
  late final TextEditingController _interestController;
  late String _moneyToolId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _principalController = TextEditingController(
      text: widget.initialPrincipal.toStringAsFixed(2),
    );
    _interestController = TextEditingController(
      text: widget.initialInterest.toStringAsFixed(2),
    );
    _moneyToolId = widget.moneyTools.first.id;
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.').trim()) ?? 0;

  double get _principal => _parse(_principalController);
  double get _interest => _parse(_interestController);
  double get _total => _round2(_principal + _interest);

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    final double principal = _round2(_principal);
    final double interest = _round2(_interest);
    if (principal + interest <= 0) {
      Toast.show(context, 'Укажите сумму платежа', error: true);
      return;
    }
    if (principal > 0 &&
        widget.outstanding > 0 &&
        principal >= widget.outstanding - 0.005) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Полное погашение'),
            content: Text(
              'Платёж погашает тело кредита полностью '
              '(${formatCurrency(widget.outstanding)}). Кредит останется '
              'открытым, события планировщика не изменятся. Продолжить?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Провести платёж'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final double paid = await ToolDetailRepository().payCreditPayment(
        creditToolId: widget.toolId,
        creditName: widget.toolName,
        accountId: widget.accountId,
        moneyToolId: _moneyToolId,
        date: _date,
        principal: principal,
        interest: interest,
      );
      if (!mounted) return;
      Navigator.pop(context, paid);
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, 'Не удалось провести платёж: $e', error: true);
      setState(() => _saving = false);
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
                  'Платёж по кредиту',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Кредит «${widget.toolName}». Текущий долг: '
                  '${formatCurrency(widget.outstanding)}. Тело уходит '
                  'переводом, проценты — отдельным расходом.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _moneyToolId,
                  decoration: InputDecoration(
                    labelText: 'Списать с (${widget.currency})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: Icon(
                      Icons.account_balance_wallet,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  items:
                      widget.moneyTools
                          .map(
                            (Tool t) => DropdownMenuItem<String>(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          )
                          .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _moneyToolId = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Дата платежа',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: Text(DateFormat('dd.MM.yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _principalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Погашение тела (${widget.currency})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: Icon(
                      Icons.savings_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  validator: (String? value) {
                    final double? parsed = double.tryParse(
                      (value ?? '').replaceAll(',', '.').trim(),
                    );
                    if (parsed == null || parsed < 0) {
                      return 'Введите неотрицательную сумму';
                    }
                    if (parsed > widget.outstanding + 0.01) {
                      return 'Тело больше остатка долга';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _interestController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Проценты (${widget.currency})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: Icon(
                      Icons.percent,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  validator: (String? value) {
                    final double? parsed = double.tryParse(
                      (value ?? '').replaceAll(',', '.').trim(),
                    );
                    if (parsed == null || parsed < 0) {
                      return 'Введите неотрицательную сумму';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Text(
                      'Итого к списанию',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatCurrency(_total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon:
                      _saving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.payments_outlined, size: 20),
                  label: Text(_saving ? 'Проведение...' : 'Провести платёж'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
