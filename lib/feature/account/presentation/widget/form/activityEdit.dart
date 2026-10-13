import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:intl/intl.dart';

/// Модальное окно редактирования операции:
/// категория, сумма, дата, комментарий (тул и тип не меняются).
class ActivityEditSheet extends StatefulWidget {
  final Activity activity;

  const ActivityEditSheet({super.key, required this.activity});

  @override
  State<ActivityEditSheet> createState() => _ActivityEditSheetState();
}

class _ActivityEditSheetState extends State<ActivityEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Activity a = widget.activity;
    _nameController = TextEditingController(text: a.name ?? '');
    _commentController = TextEditingController(text: a.comment ?? '');
    _amountController = TextEditingController(
      text: a.price * a.quantity == 0 ? '' : (a.price * a.quantity).toStringAsFixed(2),
    );

    _date = a.createAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
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
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final Activity a = widget.activity;
    final String name = _nameController.text.trim();
    final double amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );

    setState(() => _saving = true);
    try {
      final Activity updated = Activity(
        id: a.id,
        toolId: a.toolId,
        type: a.type,
        createAt: _date,
        quantity: 1,
        price: amount,
        currency: a.currency,
        isTransmit: a.isTransmit,
        name: name,
        comment: _commentController.text.trim(),
        eventId: a.eventId,
        interestAmount: a.interestAmount,
        principalAmount: a.principalAmount,
      );
      await ActivityRepository().update(updated);

      if (mounted) {
        Toast.show(context, 'Операция обновлена');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Не удалось обновить операцию: $e', error: true);
        setState(() => _saving = false);
      }
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
                  'Редактировать операцию',
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
                    labelText: 'Категория',
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (String? v) =>
                      v == null || v.trim().isEmpty ? 'Введите категорию' : null,
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
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
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
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    prefixIcon: Icon(Icons.comment),
                  ),
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
