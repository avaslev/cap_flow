import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/core/utils/selectDefaultMoneyTool.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/feature/tools/domain/tool_valuation.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:uuid/uuid.dart';

/// Modal bottom sheet for opening a deposit: principal is deducted from a
/// money tool of the account and a deposit tool is created.
class DepositForm extends StatefulWidget {
  final AccountData accountData;
  final String accountId;

  const DepositForm({
    super.key,
    required this.accountData,
    required this.accountId,
  });

  @override
  State<DepositForm> createState() => _DepositFormState();
}

class _DepositFormState extends State<DepositForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  late final List<ToolSummary> _moneyTools = widget.accountData
      .getMoneyToolsForAccount(widget.accountId);
  late String _selectedMoneyToolId = _moneyTools.isNotEmpty
      ? _moneyTools.first.id
      : '';
  PayoutType _payoutType = PayoutType.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate; // null → бессрочный депозит («никогда»)
  bool _saving = false;

  bool get _hasEndDate => _endDate != null;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
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

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial = isStart ? _startDate : (_endDate ?? DateTime.now().add(const Duration(days: 365)));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_hasEndDate && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 365));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  /// Payout options: «в конце срока» exists only for term deposits.
  List<PayoutType> get _payoutOptions =>
      _hasEndDate
          ? PayoutType.values
          : PayoutType.values.where((PayoutType t) => t != PayoutType.atEndOfTerm).toList();

  /// Planner record for deposit interest, built from the deposit settings.
  /// 
  /// - Ежемесячно (капитализация) → проценты приходуют на тул депозита;
  /// - Ежемесячно на счёт списания → на money-тул;
  /// - В конце срока → разовое начисление на money-тул в дату окончания.
  ScheduledTransaction _buildInterestSchedule({
    required String depositId,
    required String moneyToolId,
  }) {
    final double principal =
        double.parse(_amountController.text.replaceAll(',', '.'));
    final double rate =
        double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0;
    final double monthlyInterest =
        ((principal * rate / 1200) * 100).roundToDouble() / 100;
    // For «в конце срока» the payout is the FULL term interest, not a
    // monthly one: principal × rate × days/365 (via the valuation strategy).
    final double payoutAmount = _payoutType == PayoutType.atEndOfTerm
        ? ((depositValue(
                    principal: principal,
                    annualRate: rate,
                    startDate: _startDate,
                    endDate: _endDate,
                    asOf: _endDate ?? DateTime.now(),
                  ) -
                  principal) *
              100)
            .roundToDouble() /
            100
        : monthlyInterest;
    final String targetWalletId = switch (_payoutType) {
      PayoutType.monthly => depositId,
      PayoutType.monthlyToWithdrawalAccount => moneyToolId,
      PayoutType.atEndOfTerm => moneyToolId,
    };

    String recurrenceType;
    DateTime firstPayout;
    DateTime? recurrenceEndDate;
    int? recurrenceDayOfMonth;
    int totalExecutions = 0;

    final int day = math.max(1, math.min(_startDate.day, 28));
    if (_payoutType == PayoutType.atEndOfTerm) {
      recurrenceType = 'none';
      firstPayout = _endDate!;
      totalExecutions = 1;
    } else {
      recurrenceType = 'monthlyOnDay';
      recurrenceDayOfMonth = day;
      recurrenceEndDate = _hasEndDate ? _endDate : null;
      // First payout: one period after opening.
      int y = _startDate.year;
      int m = _startDate.month + 1;
      if (m > 12) {
        m = 1;
        y += 1;
      }
      firstPayout = DateTime(y, m, math.min(day, 28));
      // Count payouts until the end of term.
      if (_hasEndDate) {
        DateTime cursor = firstPayout;
        while (cursor.isBefore(_endDate!)) {
          totalExecutions += 1;
          m = cursor.month + 1;
          y = cursor.year;
          if (m > 12) {
            m = 1;
            y += 1;
          }
          cursor = DateTime(y, m, math.min(day, 28));
        }
      }
    }

    return ScheduledTransaction(
      id: const Uuid().v7(),
      accountId: widget.accountId,
      name: 'Проценты по депозиту «${_nameController.text.trim()}»',
      amount: payoutAmount,
      type: 'income',
      category: 'Проценты по депозиту',
      date: _startDate,
      walletId: targetWalletId,
      recurrenceType: recurrenceType,
      recurrenceEndDate: recurrenceEndDate,
      recurrenceDayOfMonth: recurrenceDayOfMonth,
      nextExecutionDate: firstPayout,
      totalExecutions: totalExecutions,
      executedCount: 0,
      depositToolId: depositId,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ToolSummary? moneyTool = _selectedMoneyTool;
    if (moneyTool == null || _saving) return;

    final String name = _nameController.text.trim();
    final double principal = double.parse(_amountController.text.replaceAll(',', '.'));
    final double rate = double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0;
    if (_payoutType == PayoutType.atEndOfTerm && !_hasEndDate) {
      Toast.show(context, 'Для выплаты «в конце срока» укажите дату окончания.');
      setState(() => _saving = false);
      return;
    }

    setState(() => _saving = true);
    try {
      final String depositId = const Uuid().v7();

      final Tool depositTool = Tool(
        id: depositId,
        accountId: widget.accountId,
        name: name,
        type: ToolType.deposit.name,
        startDate: _startDate,
        endDate: _endDate,
        payType: _payoutType.name,
        interestRate: rate,
      );
      await ToolRepository().insert(depositTool);

      // Money leaves the source cash tool (replay keeps it consistent).
      await ActivityRepository().insert(
        Activity(
          id: const Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: _startDate,
          quantity: principal,
          price: 1,
          currency: Currency.RUB,
          // Внутреннее перемещение (деньги → депозит), не расход.
          isTransmit: true,
          name: 'Открытие депозита «$name»',
        ),
      );
      // Principal lands on the deposit tool.
      await ActivityRepository().insert(
        Activity(
          id: const Uuid().v7(),
          toolId: depositTool.id,
          type: ActivityType.add,
          createAt: _startDate,
          quantity: 1,
          price: principal,
          currency: Currency.RUB,
          // Внутреннее перемещение — не доход.
          isTransmit: true,
          name: 'Открытие депозита',
        ),
      );

      // Immediate in-memory state (a full refresh happens on sheet close).
      widget.accountData.addDeposit(
        accountId: widget.accountId,
        name: name,
        toolId: depositId,
        quantity: principal,
        annualYield: rate,
        startDate: _startDate,
        endDate: _endDate,
        payoutType: _payoutType,
        withdrawalToolName: moneyTool.name,
      );

      // Auto-create the planner record: interest accrual per deposit settings.
      await ScheduledTransactionRepository().add(
        _buildInterestSchedule(depositId: depositId, moneyToolId: moneyTool.id),
      );

      if (mounted) {
        Toast.show(context, 'Депозит «$name» открыт');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Не удалось открыть депозит: $e', error: true);
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
              'На счёте нет денежного тула — открывать депозит некуда.',
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
                  'Открыть депозит',
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
                    labelText: 'Название депозита',
                    prefixIcon: Icon(Icons.savings),
                  ),
                  validator: (String? v) =>
                      v == null || v.trim().isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
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
                            '${t.name} (${formatCurrency(t.currentValue)})',
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
                  decoration: const InputDecoration(
                    labelText: 'Сумма (RUB)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (String? v) {
                    final double? amount = double.tryParse(v ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Введите положительную сумму';
                    }
                    final ToolSummary? moneyTool = _selectedMoneyTool;
                    if (moneyTool != null &&
                        amount > moneyTool.currentValue) {
                      return 'Недостаточно средств: ${formatCurrency(moneyTool.currentValue)}';
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
                InkWell(
                  onTap: () => _pickDate(isStart: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата начала',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd.MM.yyyy').format(_startDate)),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Указать дату окончания'),
                  subtitle: Text(
                    _hasEndDate ? 'Срочный депозит' : 'Бессрочный — «никогда»',
                  ),
                  value: _hasEndDate,
                  onChanged: (bool value) {
                    setState(() {
                      if (value) {
                        _endDate = DateTime.now().add(const Duration(days: 365));
                      } else {
                        _endDate = null;
                        if (_payoutType == PayoutType.atEndOfTerm) {
                          _payoutType = PayoutType.monthly;
                        }
                      }
                    });
                  },
                ),
                if (_hasEndDate) ...<Widget>[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _pickDate(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата конца срока',
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text(DateFormat('dd.MM.yyyy').format(_endDate!)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<PayoutType>(
                  value: _payoutOptions.contains(_payoutType)
                      ? _payoutType
                      : _payoutOptions.first,
                  decoration: const InputDecoration(
                    labelText: 'Выплата процентов',
                    prefixIcon: Icon(Icons.payments),
                  ),
                  items: _payoutOptions
                      .map(
                        (PayoutType t) => DropdownMenuItem<PayoutType>(
                          value: t,
                          child: Text(switch (t) {
                            PayoutType.atEndOfTerm => 'В конце срока',
                            PayoutType.monthly => 'Ежемесячно (капитализация)',
                            PayoutType.monthlyToWithdrawalAccount =>
                              'Ежемесячно на счёт списания',
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: (PayoutType? v) =>
                      setState(() => _payoutType = v ?? PayoutType.monthly),
                ),
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
                      : const Icon(Icons.savings),
                  label: Text(_saving ? 'Открытие...' : 'Открыть депозит'),
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
