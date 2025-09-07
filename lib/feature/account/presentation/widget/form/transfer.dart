import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/transferState.dart';
import 'package:investflow/feature/account/logic/transferCubit.dart';
import 'package:flutter/material.dart';
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
    final List<ToolSummary> initialMoneyTools = accountData.allMoneyTools;

    return BlocProvider<TransferCubit>(
      create:
          (BuildContext context) => TransferCubit(
            currentTool:
                accountData
                    .getMoneyToolsForAccount(accountData.activeAccountId)
                    .first,
            initialMoneyTools: initialMoneyTools,
            accounts: accountData.accounts,
          ),
      child: BlocListener<TransferCubit, TransferState>(
        listener: (BuildContext context, TransferState state) {
          if (state.formStatus == FormStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transfer added successfully!')),
            );
            Navigator.pop(context); // Close the bottom sheet
          } else if (state.formStatus == FormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to add transfer: ${state.errorMessage ?? "Unknown error"}',
                ),
              ),
            );
          } else if (state.formStatus == FormStatus.validationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Please check your input.'),
              ),
            );
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      "Add Transfer",
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
                      labelText: 'From',
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
                                  tool.id != state.selectedToToolId,
                            )
                            .map<DropdownMenuItem<String>>((ToolSummary tool) {
                              return DropdownMenuItem<String>(
                                value: tool.id,
                                child: Text(
                                  '${state.accounts.where((AccountSummary account) => account.id == tool.accountId).first.name} (${formatCurrency(tool.currentValue)})',
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
                      labelText: 'To',
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
                              return DropdownMenuItem<String>(
                                value: tool.id,
                                child: Text(
                                  '${state.accounts.where((AccountSummary account) => account.id == tool.accountId).first.name} (${formatCurrency(tool.currentValue)})',
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
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: state.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (RUB equivalent)',
                      hintText: 'e.g., 5000.00',
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
                        return 'Please enter the amount';
                      }
                      final double? val = double.tryParse(value);
                      if (val == null || val <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: state.commission,
                    decoration: InputDecoration(
                      labelText: 'Commission (Optional, RUB equivalent)',
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please correct the highlighted errors.',
                                    ),
                                  ),
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                    ),
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
                          ? "Adding..."
                          : "Add Income",
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
