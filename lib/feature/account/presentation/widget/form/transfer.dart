import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/transferState.dart';
import 'package:investflow/feature/account/logic/transferCubit.dart';
import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/formatCurrency.dart';

/// A modal bottom sheet for adding income, now integrated with `bloc/cubit`.
class TransferForm extends StatelessWidget {
  final AccountData accountData;

  const TransferForm({super.key, required this.accountData});

  @override
  Widget build(BuildContext context) {
    // We need AccountData to initialize the Cubit with initial tools and to
    // perform the actual addIncome operation.
    // Закрытые тула (isClosed) не участвуют в переводах.
    final List<ToolSummary> initialMoneyTools = accountData.allMoneyTools
        .where((ToolSummary tool) => !tool.isClosed)
        .toList();
    // Деньги активного счёта; если их нет (активный — total или архивный) —
    // берём первый доступный money-тул, чтобы не падать на `.first`.
    final List<ToolSummary> activeMoneyTools = accountData
        .getMoneyToolsForAccount(accountData.activeAccountId);
    final ToolSummary? currentTool = activeMoneyTools.isNotEmpty
        ? activeMoneyTools.first
        : (initialMoneyTools.isNotEmpty ? initialMoneyTools.first : null);
    if (currentTool == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider<TransferCubit>(
      create:
          (BuildContext context) => TransferCubit(
            currentTool: currentTool,
            initialMoneyTools: initialMoneyTools,
            accounts: accountData.accounts,
          ),
      child: BlocListener<TransferCubit, TransferState>(
        listener: (BuildContext context, TransferState state) {
          if (state.formStatus == FormStatus.success) {
            Toast.show(context, 'Перевод добавлен');
            Navigator.pop(context); // Close the bottom sheet
          } else if (state.formStatus == FormStatus.failure) {
            Toast.show(context, 'Не удалось добавить перевод: ${state.errorMessage ?? "Ошибка"}', error: true);
          } else if (state.formStatus == FormStatus.validationError) {
            Toast.show(context, state.errorMessage ?? 'Проверьте заполнение полей.');
          }
        },
        child: _TransferFormContent(),
      ),
    );
  }
}

/// The actual content of the Add Income form, built using `BlocBuilder`.
class _TransferFormContent extends StatefulWidget {
  @override
  State<_TransferFormContent> createState() => _TransferFormContentState();
}

class _TransferFormContentState extends State<_TransferFormContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _receivedCtrl = TextEditingController();

  /// «Получено» синхронизируется из состояния после кадра: пересчёт
  /// из «Будет списано» подставляется автоматически, ручной ввод
  /// не конфликтует (состояние равно тексту во время набора).
  void _syncCtrls(TransferState state) {
    if (_receivedCtrl.text != state.amountTo) {
      final String v = state.amountTo;
      _receivedCtrl.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
    }
  }

  String _fmtRate(double v) {
    String s = v.toStringAsFixed(4);
    while (s.endsWith('0') && s.contains('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s.endsWith('.') ? '${s}0' : s;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _receivedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: BlocBuilder<TransferCubit, TransferState>(
            builder: (BuildContext context, TransferState state) {
              final String fromTicker = state.fromTicker ?? 'RUB';
              final String toTicker = state.toTicker ?? 'RUB';
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _syncCtrls(state),
              );
              // Инфо: курс обмена из введённых сумм, в обе стороны.
              final String rateInfo = () {
                final double? spent = double.tryParse(state.amount);
                final double? received = double.tryParse(state.amountTo);
                if (spent == null ||
                    received == null ||
                    spent <= 0 ||
                    received <= 0) {
                  return '';
                }
                final double r = spent / received;
                return 'Курс: ${_fmtRate(r)} $fromTicker за 1 $toTicker'
                    ' · ${_fmtRate(received / spent)} $toTicker за 1 $fromTicker';
              }();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      "Перевод",
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: state.selectedFromToolId,
                    decoration: InputDecoration(
                      labelText: 'Откуда',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.money),
                    ),
                    items:
                        state.availableMoneyTools
                            .where(
                              (ToolSummary tool) =>
                                  tool.id != state.selectedToToolId,
                            )
                            .map<DropdownMenuItem<String>>((ToolSummary tool) {
                              final String accountName =
                                  state.accounts
                                      .where(
                                        (AccountSummary account) =>
                                            account.id == tool.accountId,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  '—';
                              return DropdownMenuItem<String>(
                                value: tool.id,
                                child: Text(
                                  '$accountName · ${tool.name} (${formatCurrency(tool.currentValue)})',
                                ),
                              );
                            })
                            .toList(),
                    onChanged: (String? newValue) {
                      context.read<TransferCubit>().moneyFromToolSelected(
                        newValue,
                      );
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a money tool';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: state.selectedToToolId,
                    decoration: InputDecoration(
                      labelText: 'Куда',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(
                        Icons.money,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    items:
                        state.availableMoneyTools
                            .where(
                              (ToolSummary tool) =>
                                  tool.id != state.selectedFromToolId,
                            )
                            .map<DropdownMenuItem<String>>((ToolSummary tool) {
                              final String accountName =
                                  state.accounts
                                      .where(
                                        (AccountSummary account) =>
                                            account.id == tool.accountId,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  '—';
                              return DropdownMenuItem<String>(
                                value: tool.id,
                                child: Text(
                                  '$accountName · ${tool.name} (${formatCurrency(tool.currentValue)})',
                                ),
                              );
                            })
                            .toList(),
                    onChanged: (String? newValue) {
                      context.read<TransferCubit>().moneyToToolSelected(
                        newValue,
                      );
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a money tool';
                      }
                      if (value == state.selectedFromToolId) {
                        return 'Please select another money tool';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd').format(state.selectedDate),
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date of Operation',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: state.selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != state.selectedDate) {
                        context.read<TransferCubit>().dateSelected(picked);
                      }
                    },
                  ),
                  if (!state.isCrossCurrency) ...<Widget>[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Сумма ($fromTicker)',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged:
                          (String value) =>
                              context.read<TransferCubit>().amountChanged(value),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Укажите сумму';
                        }
                        final double? val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return 'Введите положительное число';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (state.isCrossCurrency) ...<Widget>[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Будет списано ($fromTicker)',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged:
                          (String value) =>
                              context.read<TransferCubit>().amountChanged(value),
                      validator: (String? value) {
                        final double? val = double.tryParse(value ?? '');
                        if (val == null || val <= 0) {
                          return 'Введите положительное число';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _receivedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Получено ($toTicker)',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        prefixIcon: Icon(
                          Icons.savings,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged:
                          (String value) => context
                              .read<TransferCubit>()
                              .amountToChanged(value),
                      validator: (String? value) {
                        final double? val = double.tryParse(value ?? '');
                        if (val == null || val <= 0) {
                          return 'Введите положительное число';
                        }
                        return null;
                      },
                    ),
                    if (rateInfo.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        rateInfo,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: state.commission,
                    decoration: InputDecoration(
                      labelText: 'Комиссия (в валюте источника, опц.)',
                      hintText: 'e.g., 5.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(
                        Icons.category,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onChanged:
                        (String value) => context
                            .read<TransferCubit>()
                            .commissionChanged(value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: state.comment,
                    decoration: InputDecoration(
                      labelText: 'Comment (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(
                        Icons.comment,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onChanged:
                        (String value) =>
                            context.read<TransferCubit>().commentChanged(value),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed:
                        state.formStatus == FormStatus.loading
                            ? null // Disable button while loading
                            : () {
                              // Trigger local form validation first
                              if (_formKey.currentState!.validate()) {
                                context.read<TransferCubit>().submitIncome();
                              } else {
                                Toast.show(context, 'Please correct the highlighted errors.', error: true);
                              }
                            },
                    icon:
                        state.formStatus == FormStatus.loading
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                            : Icon(
                              Icons.add_circle_outline,
                              color: colorScheme.onPrimary,
                              size: 20,
                            ),
                    label: Text(
                      state.formStatus == FormStatus.loading
                          ? "Добавление..."
                          : "Добавить перевод",
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
