import 'package:bookstore/feature/account/data/accountDataState.dart';
import 'package:bookstore/feature/account/data/addAccountFormState.dart';
import 'package:bookstore/feature/account/logic/addAccountFormCubit.dart';
import 'package:bookstore/feature/account/logic/accountBloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Helper function to get display name for AccountType.
String _getAccountTypeDisplayName(AccountType type) {
  switch (type) {
    case AccountType.general:
      return 'General Account';
    case AccountType.brokerage:
      return 'Brokerage Account';
    case AccountType.cryptocurrency:
      return 'Cryptocurrency Account';
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
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        // Adjust padding for keyboard to prevent overflow
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
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
                  "Create New Account",
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
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
                    return 'Please enter an account name';
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
                  labelText: 'Initial Balance',
                  hintText: 'e.g., 1000.50 or -500.00',
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
                    return 'Please enter an initial balance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Account Type:',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                value: formState.selectedAccountType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  prefixIcon: Icon(
                    Icons.category,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                items:
                    AccountType.values.map<DropdownMenuItem<AccountType>>((
                      AccountType type,
                    ) {
                      return DropdownMenuItem<AccountType>(
                        value: type,
                        child: Text(_getAccountTypeDisplayName(type)),
                      );
                    }).toList(),
                onChanged: (AccountType? newValue) {
                  if (newValue != null) {
                    context
                        .read<AddAccountFormCubit>()
                        .updateSelectedAccountType(newValue);
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  'Hide Events for this Account',
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
                  'Exclude from Total Balance',
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
                'Select Card Color:',
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

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Account "$name" created successfully!'),
                      ),
                    );
                    Navigator.pop(context); // Close the bottom sheet
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(
                    double.infinity,
                    50,
                  ), // Ensure button fills width
                ),
                icon: Icon(
                  Icons.add_card,
                  color: colorScheme.onPrimary,
                  size: 20,
                ),
                label: Text(
                  "Create Account",
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
