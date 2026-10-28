import 'package:flutter/material.dart';
import 'package:capflow/core/utils/formatCurrency.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:capflow/feature/tool_detail/data/tool_detail_repository.dart';

/// Форма продажи актива «прочее». Пользователь указывает цену продажи,
/// из неё считается реализованная прибыль/убыток (цена − себестоимость),
/// после чего актив скрывается. Возвращает реализованный результат (со
/// знаком) или null, если продажа отменена.
Future<double?> showOtherSellSheet(
  BuildContext context, {
  required String accountId,
  required String toolId,
  required String toolName,
  required double currentValue,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    clipBehavior: Clip.antiAliasWithSaveLayer,
    builder: (BuildContext sheetContext) => _OtherSellSheet(
      accountId: accountId,
      toolId: toolId,
      toolName: toolName,
      currentValue: currentValue,
    ),
  );
}

class _OtherSellSheet extends StatefulWidget {
  final String accountId;
  final String toolId;
  final String toolName;
  final double currentValue;

  const _OtherSellSheet({
    required this.accountId,
    required this.toolId,
    required this.toolName,
    required this.currentValue,
  });

  @override
  State<_OtherSellSheet> createState() => _OtherSellSheetState();
}

class _OtherSellSheetState extends State<_OtherSellSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentValue.abs().toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final double price = double.parse(
      _priceController.text.replaceAll(',', '.').trim(),
    );
    setState(() => _saving = true);
    try {
      final double realized = await ToolDetailRepository().sellOtherTool(
        toolId: widget.toolId,
        toolName: widget.toolName,
        accountId: widget.accountId,
        salePrice: price,
      );
      if (!mounted) return;
      Navigator.pop(context, realized);
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, 'Не удалось продать актив: $e', error: true);
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
                  'Продажа актива',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Актив «${widget.toolName}». Текущая стоимость: '
                  '${formatCurrency(widget.currentValue.abs())}. Укажите '
                  'стоимость продажи — разница со стоимостью заведения '
                  'станет доходом или убытком.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Стоимость продажи (RUB)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  validator: (String? v) {
                    final double? value = double.tryParse(
                      (v ?? '').replaceAll(',', '.').trim(),
                    );
                    if (value == null || value <= 0) {
                      return 'Введите положительную стоимость';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sell_outlined, size: 20),
                  label: const Text('Продать'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
