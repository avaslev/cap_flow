import 'package:capflow/feature/account/data/accountDataState.dart';
import 'package:capflow/feature/account/data/addAccountFormState.dart';
import 'package:capflow/feature/account/logic/addAccountFormCubit.dart';
import 'package:capflow/feature/account/logic/accountBloc.dart';
import 'package:flutter/material.dart';
import 'package:capflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Helper function to get display name for AccountType.
String _getAccountTypeDisplayName(AccountType type) {
  switch (type) {
    case AccountType.general:
      return 'Обычный';
    case AccountType.brokerage:
      return 'Брокерский';
    case AccountType.cryptocurrency:
      return 'Криптовалютный';
  }
}

/// A modal bottom sheet for creating a new account.
class AddAccountForm extends StatefulWidget {
  const AddAccountForm({super.key});

  @override
  State<AddAccountForm> createState() => _AddAccountFormState();
}

class _AddAccountFormState extends State<AddAccountForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // Controllers initialized with current cubit state and update cubit on change
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  final List<Map<String, Object>> _availableColors =
      const <Map<String, Object>>[
        {'name': 'Vibrant Blue', 'value': 0xff007BFF},
        {'name': 'Strong Green', 'value': 0xff28A745},
        {'name': 'Deep Yellow', 'value': 0xffFFC107},
        {'name': 'Cyan', 'value': 0xff17A2B8},
        {'name': 'Orange', 'value': 0xffFD7E14},
        {'name': 'Indigo', 'value': 0xff6610F2},
        {'name': 'Deep Purple', 'value': 0xff6A0DAD}, // Total balance color
        {'name': 'Pink', 'value': 0xffE83E8C},
        {'name': 'Red', 'value': 0xffDC3545},
        {'name': 'Light Blue', 'value': 0xff38BDF8},
        {'name': 'Brown', 'value': 0xff8D6E63},
        {'name': 'Blue Grey', 'value': 0xff607D8B},
      ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with the current state from the cubit
    // This is important because the cubit's default state is used for initial values.
    final AddAccountFormState initialState =
        context.read<AddAccountFormCubit>().state;
    _nameController = TextEditingController(text: initialState.name);
    _balanceController = TextEditingController(text: initialState.balanceText);

    // Listen to changes from controllers and update cubit state
    _nameController.addListener(_onNameChanged);
    _balanceController.addListener(_onBalanceChanged);
  }

  void _onNameChanged() {
    context.read<AddAccountFormCubit>().updateName(_nameController.text);
  }

  void _onBalanceChanged() {
    context.read<AddAccountFormCubit>().updateBalanceText(
      _balanceController.text,
    );
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _balanceController.removeListener(_onBalanceChanged);
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// Выбор типа счёта нижней шторкой (вместо DropdownButtonFormField).
  Future<void> _pickAccountType(
    BuildContext context,
    AddAccountFormState formState,
  ) async {
    FocusScope.of(context).unfocus();
    final AccountType? picked = await showModalBottomSheet<AccountType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Тип счёта',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...AccountType.values.map<Widget>((AccountType type) {
              final bool selected = type == formState.selectedAccountType;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(_getAccountTypeDisplayName(type)),
                onTap: () => Navigator.pop(sheetContext, type),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) {
      context.read<AddAccountFormCubit>().updateSelectedAccountType(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // Access AccountsBloc from the current context, which should now have it provided
    // in the MultiBlocProvider from the AccountHomePage's _showAddAccountSheet.
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    // Watch the cubit state to rebuild UI when form values change
    final AddAccountFormState formState =
        context.watch<AddAccountFormCubit>().state;

    return Container(
      // Нижний отступ фиксированный: при открытии/закрытии клавиатуры
      // шторка не меняет высоту — выпадающий список AccountType остаётся
      // на своём месте. Форма скроллится, поле имени сверху видно всегда.
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: 16.0,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Новый счёт',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Название счёта',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(
                    Icons.account_balance_wallet,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название счёта';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Начальный баланс',
                  hintText: 'например, 1000.50 или -500.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(
                    Icons.currency_ruble,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите начальный баланс';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Введите корректное число';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Тип счёта:',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Выбор типа через нижнюю шторку: оверлей-меню Dropdown
              // неустойчиво к смене высоты шторки (клавиатура/скролл).
              TextFormField(
                readOnly: true,
                controller: TextEditingController(
                  text: _getAccountTypeDisplayName(
                    formState.selectedAccountType,
                  ),
                ),
                decoration: InputDecoration(
                  labelText: 'Тип',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(
                    Icons.category,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                onTap: () => _pickAccountType(context, formState),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  'Скрыть события счёта',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                value: formState.hideEvents,
                onChanged: (bool value) {
                  context.read<AddAccountFormCubit>().updateHideEvents(value);
                },
                secondary: Icon(
                  formState.hideEvents
                      ? Icons.notifications_off
                      : Icons.notifications,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(
                  'Исключить из общего баланса',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                value: formState.excludeFromTotal,
                onChanged: (bool value) {
                  context.read<AddAccountFormCubit>().updateExcludeFromTotal(
                    value,
                  );
                },
                secondary: Icon(
                  formState.excludeFromTotal
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Цвет карточки:',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    _availableColors.map<Widget>((
                      Map<String, Object> colorMap,
                    ) {
                      final int colorValue = colorMap['value']! as int;
                      final bool isSelected =
                          formState.selectedColorValue == colorValue;
                      return GestureDetector(
                        onTap: () {
                          context
                              .read<AddAccountFormCubit>()
                              .updateSelectedColorValue(colorValue);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border:
                                isSelected
                                    ? Border.all(
                                      color: colorScheme.primary,
                                      width: 3,
                                    )
                                    : null,
                          ),
                          child:
                              isSelected
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Get final values from the cubit state
                    final String name = formState.name;
                    final double initialBalance = double.parse(
                      formState.balanceText,
                    );

                    accountBloc.add(
                      AddAccountEvent(
                        AccountSummary(
                          name: name,
                          balance: initialBalance,
                          dailyChangeAmount: 0,
                          dailyChangePercentage: 0,
                          colorValue: formState.selectedColorValue,
                          type: formState.selectedAccountType,
                          hideEvents: formState.hideEvents,
                          excludeFromTotal: formState.excludeFromTotal,
                        ),
                      ),
                    );

                    Toast.show(context, 'Счёт «$name» создан');
                    Navigator.pop(context); // Close the bottom sheet
                  }
                },
                icon: Icon(
                  Icons.add_card,
                  color: colorScheme.onPrimary,
                  size: 20,
                ),
                label: Text(
                  'Создать счёт',
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
