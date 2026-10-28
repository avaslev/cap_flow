import 'package:flutter/material.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:capflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:intl/intl.dart';
import 'package:capflow/data/models/activity.dart';
import 'package:capflow/data/models/scheduledTransaction.dart';
import 'package:capflow/data/models/tool.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';
import 'package:capflow/data/repository/activityRepository.dart';
import 'package:capflow/data/repository/scheduledTransactionRepository.dart';
import 'package:capflow/data/repository/toolRepository.dart';
import 'dart:math' as math;
import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/feature/tools/domain/credit_schedule.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

/// Modal bottom sheet for taking a credit: the loan amount is transferred to
/// a money tool of the account, and a credit tool (negative liability) is
/// created.
class CreditForm extends StatefulWidget {
  final AccountData accountData;
  final String accountId;

  const CreditForm({
    super.key,
    required this.accountData,
    required this.accountId,
  });

  @override
  State<CreditForm> createState() => _CreditFormState();
}

class _CreditFormState extends State<CreditForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _termController = TextEditingController();
  final TextEditingController _paymentDayController = TextEditingController();

  late final List<ToolSummary> _moneyTools = widget.accountData
      .getMoneyToolsForAccount(widget.accountId);
  late String _selectedMoneyToolId = _moneyTools.isNotEmpty
      ? _moneyTools.first.id
      : '';
  CreditPaymentType _paymentType = CreditPaymentType.annuity;
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _termController.dispose();
    _paymentDayController.dispose();
    super.dispose();
  }

  ToolSummary? get _selectedMoneyTool {
    for (final ToolSummary t in _moneyTools) {
      if (t.id == _selectedMoneyToolId) {
        return t;
      }
    }
    return null;
  }

  double get _monthlyPaymentPreview {
    final double loan =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final double rate =
        double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0;
    final int term = int.tryParse(_termController.text) ?? 0;
    if (loan <= 0 || term <= 0) {
      return 0;
    }
    double payment;
    if (_paymentType == CreditPaymentType.differentiated) {
      // Первый (максимальный) платёж дифференцированной схемы.
      payment = loan / term + loan * (rate / 100 / 12);
    } else {
      try {
        payment = annuityMonthlyPayment(
          loanAmount: loan,
          annualRate: rate,
          termMonths: term,
        );
      } catch (_) {
        payment = 0;
      }
    }
    // Round to kopecks — no long decimal tails in the planner.
    return (payment * 100).roundToDouble() / 100;
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ToolSummary? moneyTool = _selectedMoneyTool;
    if (moneyTool == null || _saving) return;

    final String name = _nameController.text.trim();
    final double amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );
    final double rate = double.tryParse(
      _rateController.text.replaceAll(',', '.'),
    )!;
    final int termMonths = int.parse(_termController.text);
    final int paymentDay =
        int.tryParse(_paymentDayController.text) ?? _startDate.day;

    // Защита от дублей: активный кредит с тем же именем уже есть?
    final bool duplicate = widget.accountData
        .getToolsForAccount(widget.accountId)
        .any((ToolSummary t) =>
            t.type == ToolType.credit &&
            !t.isClosed &&
            t.name.toLowerCase() == name.toLowerCase());
    if (duplicate) {
      setState(() => _saving = false);
      Toast.show(context, 'Кредит с названием «$name» уже есть на счёте');
      return;
    }

    setState(() => _saving = true);
    try {
      final String creditToolId = const Uuid().v7();

      final Tool creditTool = Tool(
        id: creditToolId,
        accountId: widget.accountId,
        name: name,
        type: ToolType.credit.name,
        startDate: _startDate,
        payType: _paymentType.name,
        interestRate: rate,
        paymentDayOfMonth: paymentDay,
        termMonths: termMonths,
      );
      await ToolRepository().insert(creditTool);

      // Общий id пары: кредит → деньги — одна строка перевода.
      final String transferPairId = const Uuid().v7();

      // Выдача кредита — внутреннее перемещение, не доход:
      // деньги приходуют на money-тул.
      await ActivityRepository().insert(
        Activity(
          id: const Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.add,
          createAt: _startDate,
          quantity: amount,
          price: 1,
          currency: Currency.RUB,
          isTransmit: true,
          name: 'Получение кредита «$name»',
          transferPairId: transferPairId,
        ),
      );
      // Обязательство: кредит-тул уходит в минус (replay: 0 − amount).
      await ActivityRepository().insert(
        Activity(
          id: const Uuid().v7(),
          toolId: creditToolId,
          type: ActivityType.substract,
          createAt: _startDate,
          quantity: amount,
          price: 1,
          currency: Currency.RUB,
          isTransmit: true,
          name: 'Получение кредита «$name»',
          transferPairId: transferPairId,
        ),
      );

      // Immediate in-memory state (a full refresh happens on sheet close).
      widget.accountData.addCredit(
        accountId: widget.accountId,
        name: name,
        amount: amount,
        interestRate: rate,
        loanStartDate: _startDate,
        loanTermMonths: termMonths,
        paymentDayOfMonth: paymentDay,
        creditPaymentType: _paymentType,
        transferToMoneyToolName: moneyTool.name,
      );

      // K3: авто-записи планировщика — две записи (прозрачная история):
      // 1) РАСХОД — проценты банку;
      // 2) ПЕРЕВОД — money-тул → кредит-тул (гашение тела).
      final int payDay = math.max(1, math.min(paymentDay, 28));
      final DateTime firstPayment = DateTime(
        _startDate.year,
        _startDate.month,
        payDay,
      ).isAfter(_startDate)
          ? DateTime(_startDate.year, _startDate.month, payDay)
          : DateTime(_startDate.year, _startDate.month + 1, payDay);
      final DateTime scheduleEnd = DateTime(
        _startDate.year,
        _startDate.month + termMonths,
        payDay,
      );
      final double monthlyRate = rate / 100 / 12;
      final double interestPart =
          ((amount * monthlyRate) * 100).roundToDouble() / 100;
      final double principalPart =
          ((_monthlyPaymentPreview - interestPart) * 100).roundToDouble() /
          100;

      await ScheduledTransactionRepository().add(
        ScheduledTransaction(
          id: const Uuid().v7(),
          accountId: widget.accountId,
          name: 'Проценты по кредиту «$name»',
          amount: interestPart,
          type: 'expense',
          category: 'Проценты по кредиту',
          date: _startDate,
          walletId: moneyTool.id,
          recurrenceType: 'monthlyOnDay',
          recurrenceEndDate: scheduleEnd,
          recurrenceDayOfMonth: payDay,
          nextExecutionDate: firstPayment,
          totalExecutions: termMonths,
          executedCount: 0,
          depositToolId: creditToolId,
        ),
      );
      await ScheduledTransactionRepository().add(
        ScheduledTransaction(
          id: const Uuid().v7(),
          accountId: widget.accountId,
          name: 'Погашение тела кредита «$name»',
          amount: principalPart,
          type: 'transfer',
          category: 'Погашение тела кредита',
          date: _startDate,
          walletId: moneyTool.id,
          destinationWalletId: creditToolId,
          recurrenceType: 'monthlyOnDay',
          recurrenceEndDate: scheduleEnd,
          recurrenceDayOfMonth: payDay,
          nextExecutionDate: firstPayment,
          totalExecutions: termMonths,
          executedCount: 0,
          depositToolId: creditToolId,
        ),
      );

      if (mounted) {
        Toast.show(context, 'Кредит «$name» добавлен');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Не удалось добавить кредит: $e', error: true);
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
    if (_moneyTools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.account_balance_wallet_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'На счёте нет денежного тула — зачислить кредит некуда.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
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
                  'Добавить кредит',
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
                    labelText: 'Название кредита',
                    prefixIcon: Icon(Icons.credit_score),
                  ),
                  validator: (String? v) =>
                      v == null || v.trim().isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedMoneyToolId,
                  decoration: const InputDecoration(
                    labelText: 'Зачислить на (деньги)',
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
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Сумма кредита (RUB)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (String? v) {
                    final double? amount = double.tryParse(v ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Введите положительную сумму';
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ставка, % годовых',
                    prefixIcon: Icon(Icons.percent),
                  ),
                  validator: (String? v) {
                    final double? rate = double.tryParse(v ?? '');
                    if (rate == null || rate < 0) {
                      return 'Введите корректную ставку';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termController,
                  keyboardType: const TextInputType.numberWithOptions(),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Срок, месяцев',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  validator: (String? v) {
                    final int? term = int.tryParse(v ?? '');
                    if (term == null || term <= 0) {
                      return 'Введите срок в месяцах';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CreditPaymentType>(
                  value: _paymentType,
                  decoration: const InputDecoration(
                    labelText: 'Тип платежей',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: CreditPaymentType.values
                      .map(
                        (CreditPaymentType t) =>
                            DropdownMenuItem<CreditPaymentType>(
                              value: t,
                              child: Text(
                                t == CreditPaymentType.annuity
                                    ? 'Аннуитетный'
                                    : 'Дифференцированный',
                              ),
                            ),
                      )
                      .toList(),
                  onChanged: (CreditPaymentType? v) => setState(() {
                    _paymentType = v ?? CreditPaymentType.annuity;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paymentDayController,
                  keyboardType: const TextInputType.numberWithOptions(),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'День платежа (1-28)',
                    prefixIcon: Icon(Icons.event),
                  ),
                  validator: (String? v) {
                    final int? day = int.tryParse(v ?? '');
                    if (day == null || day < 1 || day > 28) {
                      return 'День от 1 до 28';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickStartDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата начала',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd.MM.yyyy').format(_startDate)),
                  ),
                ),
                const SizedBox(height: 16),
                if (_monthlyPaymentPreview > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Ежемесячный платёж: '
                      '${_monthlyPaymentPreview.toStringAsFixed(2)} ₽',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
                      : const Icon(Icons.credit_score),
                  label: Text(_saving ? 'Добавление...' : 'Добавить кредит'),
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
