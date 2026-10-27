import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:investflow/core/utils/transferRates.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/models/tools/tool_kind.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/activity/logic/activity_rows.dart';
import 'package:intl/intl.dart';

/// Модальное окно редактирования операции.
///
/// Обычная операция: категория, сумма, дата, комментарий.
/// Перевод: обе половины (и комиссия) правятся одной формой; имя не меняется,
/// для кросс-валюты задаются обе суммы, курс пересчитывается.
class ActivityEditSheet extends StatefulWidget {
  final Activity activity;

  /// Вторая половина перевода; null — обычная операция.
  final Activity? counterpart;

  /// Комиссия перевода (если была).
  final Activity? commission;

  const ActivityEditSheet({
    super.key,
    required this.activity,
    this.counterpart,
    this.commission,
  });

  bool get isTransferPair => counterpart != null;

  @override
  State<ActivityEditSheet> createState() => _ActivityEditSheetState();
}

class _ActivityEditSheetState extends State<ActivityEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _fromAmountController;
  late final TextEditingController _toAmountController;
  late final TextEditingController _commissionController;
  late final TextEditingController _commentController;
  late DateTime _date;
  bool _saving = false;
  bool _toolsLoaded = false;
  bool _isMoneyPair = false;
  String _fromTicker = 'RUB';
  String _toTicker = 'RUB';

  bool get _isPair => widget.isTransferPair;
  bool get _dataIsFrom => widget.activity.type == ActivityType.substract;
  Activity get _from => _dataIsFrom ? widget.activity : widget.counterpart!;
  Activity get _to => _dataIsFrom ? widget.counterpart! : widget.activity;
  bool get _isCrossCurrency => _fromTicker != _toTicker;
  TransferKind get _kind =>
      _isPair ? transferKindOf(_from, _to) : TransferKind.transfer;

  /// Покупка/продажа инструмента: единицы сторон разные (₽ и штуки).
  bool get _isInvestmentPair =>
      _isPair &&
      !_isMoneyPair &&
      (_kind == TransferKind.purchase || _kind == TransferKind.sale);

  /// Две суммы (в единицах каждой стороны) вместо одной рублёвой.
  bool get _isTwoFieldPair =>
      _isInvestmentPair || (_isMoneyPair && _isCrossCurrency);

  /// Продажу редактировать нельзя: при ней автоматически создаются
  /// доход/расход от реализации, которые пришлось бы пересчитывать.
  bool get _isLockedSale =>
      _isPair && _isInvestmentPair && _kind == TransferKind.sale;

  /// Комиссия перевода хранится в валюте источника и её можно править.
  bool get _isCommissionEditable =>
      _isMoneyPair && widget.commission != null;

  String _unitOf(Tool tool) =>
      tool.ticker ?? (tool.type == ToolType.money.name ? 'RUB' : 'ед.');

  @override
  void initState() {
    super.initState();
    final Activity a = widget.activity;
    _nameController = TextEditingController(text: a.name ?? '');
    _commentController = TextEditingController(text: a.comment ?? '');
    _amountController = TextEditingController(
      text: a.price * a.quantity == 0
          ? ''
          : (a.price * a.quantity).toStringAsFixed(2),
    );
    if (_isPair) {
      // Две стороны пары: списание и зачисление в их собственных единицах.
      _fromAmountController = TextEditingController(
        text: _trimAmount(_from.quantity),
      );
      _toAmountController = TextEditingController(
        text: _trimAmount(_to.quantity),
      );
    } else {
      _fromAmountController = TextEditingController();
      _toAmountController = TextEditingController();
    }
    _commissionController = TextEditingController(
      text: widget.commission == null
          ? ''
          : _trimAmount(widget.commission!.quantity),
    );
    _date = a.createAt;
    _loadTickers();
  }

  String _trimAmount(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _loadTickers() async {
    if (!_isPair) {
      setState(() => _toolsLoaded = true);
      return;
    }
    try {
      final Tool fromTool = await ToolRepository().get(_from.toolId);
      final Tool toTool = await ToolRepository().get(_to.toolId);
      if (!mounted) return;
      setState(() {
        _fromTicker = _unitOf(fromTool);
        _toTicker = _unitOf(toTool);
        _isMoneyPair =
            fromTool.type == ToolType.money.name &&
            toTool.type == ToolType.money.name;
        _toolsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _toolsLoaded = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  double _parseAmount(String text) =>
      double.parse(text.trim().replaceAll(',', '.'));

  /// Задаёт half стоимость в рублях, сохраняя её представление:
  /// либо value в quantity при price = 1, либо value в price при quantity = 1.
  Activity _withRubValue(Activity a, double value) {
    if (a.quantity == 1 && a.price != 1) {
      return a.copyWith(price: value);
    }
    if (a.price > 0) return a.copyWith(quantity: value / a.price);
    return a.copyWith(quantity: value, price: 1);
  }

  Future<void> _submit() async {
    if (_isLockedSale) {
      Toast.show(
        context,
        'Продажу нельзя редактировать: удалите её и создайте новую',
        error: true,
      );
      return;
    }
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final DateTime date = _date;
      final String comment = _commentController.text.trim();

      if (!_isPair) {
        final Activity a = widget.activity;
        final double amount = _parseAmount(_amountController.text);
        await ActivityRepository().update(
          a.copyWith(
            createAt: date,
            quantity: 1,
            price: amount,
            name: _nameController.text.trim(),
            comment: comment,
          ),
        );
      } else if (_isInvestmentPair) {
        // Покупка/продажа: обе стороны в своих единицах. Для покупки цена
        // за единицу пересчитывается из оплаченной суммы и количества.
        final double amountFrom = _parseAmount(_fromAmountController.text);
        final double amountTo = _parseAmount(_toAmountController.text);
        late final Activity from;
        late final Activity to;
        if (_kind == TransferKind.purchase) {
          from = _from.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountFrom,
          );
          to = _to.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountTo,
            price: amountFrom / amountTo,
          );
        } else {
          // Продажа: себестоимость списания не меняем, правим количество
          // проданного и выручку.
          from = _from.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountFrom,
          );
          to = _to.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountTo,
          );
        }
        final Activity? commission = widget.commission?.copyWith(
          createAt: date,
        );
        await ActivityRepository().updateAll(<Activity>[
          from,
          to,
          if (commission != null) commission,
        ]);
      } else if (!_isMoneyPair) {
        // Депозит/кредит: правим рублёвую стоимость пары, сохраняя форму
        // каждой половины (quantity × price = value).
        final double value = _parseAmount(_fromAmountController.text);
        final Activity from = _withRubValue(_from, value).copyWith(
          createAt: date,
          comment: comment,
        );
        final Activity to = _withRubValue(_to, value).copyWith(
          createAt: date,
          comment: comment,
        );
        final Activity? commission = widget.commission?.copyWith(
          createAt: date,
        );
        await ActivityRepository().updateAll(<Activity>[
          from,
          to,
          if (commission != null) commission,
        ]);
      } else {
        final double amountFrom = _parseAmount(_fromAmountController.text);
        final double amountTo = _isCrossCurrency
            ? _parseAmount(_toAmountController.text)
            : amountFrom;

        late Activity from;
        late Activity to;
        Activity? commission;

        if (_isCrossCurrency) {
          final TransferRate rates = await resolveTransferRates(
            fromTicker: _fromTicker,
            toTicker: _toTicker,
            amountFrom: amountFrom,
            amountTo: amountTo,
          );
          from = _from.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountFrom,
            price: rates.fromRate,
          );
          to = _to.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountTo,
            price: rates.toRate,
          );
          if (widget.commission != null) {
            commission = widget.commission!.copyWith(
              createAt: date,
              quantity: _parseCommission(),
              price: rates.fromRate,
            );
          }
        } else {
          from = _from.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountFrom,
          );
          to = _to.copyWith(
            createAt: date,
            comment: comment,
            quantity: amountTo,
          );
          if (widget.commission != null) {
            commission = widget.commission!.copyWith(
              createAt: date,
              quantity: _parseCommission(),
            );
          }
        }

        await ActivityRepository().updateAll(<Activity>[
          from,
          to,
          if (commission != null) commission,
        ]);
      }

      if (mounted) {
        Toast.show(
          context,
          _isPair
              ? switch (_kind) {
                  TransferKind.purchase => 'Покупка обновлена',
                  TransferKind.sale => 'Продажа обновлена',
                  TransferKind.transfer => 'Перевод обновлён',
                }
              : 'Операция обновлена',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Не удалось обновить операцию: $e', error: true);
        setState(() => _saving = false);
      }
    }
  }

  String? _validateAmount(String? value) {
    final double? amount = double.tryParse(
      (value ?? '').trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      return 'Введите положительную сумму';
    }
    return null;
  }

  String? _validateCommission(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final double? amount = double.tryParse(text.replaceAll(',', '.'));
    if (amount == null || amount < 0) {
      return 'Введите сумму или 0';
    }
    return null;
  }

  double _parseCommission() {
    final String text = _commissionController.text.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }

  Widget _amountField(
    TextEditingController controller,
    String label, {
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.attach_money),
      ),
      validator: _validateAmount,
    );
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
                  _isPair
                      ? switch (_kind) {
                          TransferKind.purchase => 'Редактировать покупку',
                          TransferKind.sale => 'Редактировать продажу',
                          TransferKind.transfer => 'Редактировать перевод',
                        }
                      : 'Редактировать операцию',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLockedSale) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Продажу нельзя редактировать: с ней связаны доход/расход '
                      'от реализации. Удалите продажу и создайте новую.',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_isPair) ...<Widget>[
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (String? v) => v == null || v.trim().isEmpty
                        ? 'Введите категорию'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _amountField(_amountController, 'Сумма (RUB)'),
                ] else if (!_toolsLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_isTwoFieldPair) ...<Widget>[
                  _amountField(
                    _fromAmountController,
                    'Списано ($_fromTicker)',
                    enabled: !_isLockedSale,
                  ),
                  const SizedBox(height: 12),
                  _amountField(
                    _toAmountController,
                    'Зачислено ($_toTicker)',
                    enabled: !_isLockedSale,
                  ),
                ] else if (!_isMoneyPair)
                  _amountField(
                    _fromAmountController,
                    'Сумма (RUB)',
                    enabled: !_isLockedSale,
                  )
                else
                  _amountField(
                    _fromAmountController,
                    'Сумма ($_fromTicker)',
                    enabled: !_isLockedSale,
                  ),
                if (_isCommissionEditable) ...<Widget>[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _commissionController,
                    enabled: !_isLockedSale,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Комиссия ($_fromTicker)',
                      prefixIcon: const Icon(Icons.receipt_long),
                    ),
                    validator: _validateCommission,
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: _isLockedSale ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата операции',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd.MM.yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentController,
                  enabled: !_isLockedSale,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    prefixIcon: Icon(Icons.comment),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      (_saving || (_isPair && !_toolsLoaded) || _isLockedSale)
                      ? null
                      : _submit,
                  icon: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Сохранить'),
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
