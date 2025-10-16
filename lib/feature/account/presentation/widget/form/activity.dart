import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/data/activityState.dart';
import 'package:investflow/feature/account/logic/activityCubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/formatCurrency.dart';

/// A modal bottom sheet for adding income, now integrated with `bloc/cubit`.
class ActivityForm extends StatelessWidget {
  final AccountData accountData;
  final ActivityStateType activityStateType;
  final Event? event; // Новый необязательный параметр

  const ActivityForm({
    super.key,
    required this.accountData,
    required this.activityStateType,
    this.event, // Сделано необязательным
  });

  @override
  Widget build(BuildContext context) {
    // We need AccountData to initialize the Cubit with initial tools and to
    // perform the actual addActivity operation.
    final List<ToolSummary> initialMoneyTools = accountData
        .getMoneyToolsForAccount(
          null == event ? accountData.activeAccountId : event!.accountId,
        );

    return BlocProvider<ActivityCubit>(
      create:
          (BuildContext context) => ActivityCubit(
            initialMoneyTools: initialMoneyTools,
            activityType: activityStateType,
            event: event,
          ),
      child: BlocListener<ActivityCubit, ActivityState>(
        listener: (BuildContext context, ActivityState state) {
          if (state.formStatus == FormStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Activity added successfully!')),
            );
            Navigator.pop(context); // Close the bottom sheet
          } else if (state.formStatus == FormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to add activity: ${state.errorMessage ?? "Unknown error"}',
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
        child: const _ActivityFormContent(),
      ),
    );
  }
}

/// The actual content of the Add Activity form, built using `BlocBuilder`.
class _ActivityFormContent extends StatefulWidget {
  const _ActivityFormContent();

  @override
  State<_ActivityFormContent> createState() => _ActivityFormContentState();
}

class _ActivityFormContentState extends State<_ActivityFormContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // final AccountsBloc accountsBloc = context.read<AccountsBloc>();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: BlocBuilder<ActivityCubit, ActivityState>(
            builder: (BuildContext context, ActivityState state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      state.activityType == ActivityStateType.add
                          ? "Add income"
                          : "Add expense",
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: state.selectedMoneyToolId,
                    decoration: InputDecoration(
                      labelText: 'Target Money Tool',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(
                        Icons.money,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    items:
                        state.availableMoneyTools.map<
                          DropdownMenuItem<String>
                        >((ToolSummary tool) {
                          return DropdownMenuItem<String>(
                            value: tool.id,
                            child: Text(
                              '${tool.name} (${formatCurrency(tool.currentValue)})',
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      context.read<ActivityCubit>().moneyToolSelected(newValue);
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a money tool';
                      }
                      return null;
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
                            context.read<ActivityCubit>().amountChanged(value),
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
                        context.read<ActivityCubit>().dateSelected(picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: state.category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g., Salary, Gift, Refund',
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
                            .read<ActivityCubit>()
                            .categoryChanged(value),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a category';
                      }
                      return null;
                    },
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
                            context.read<ActivityCubit>().commentChanged(value),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  if (state.eventId != null)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: state.formStatus == FormStatus.loading
                                ? null // Disable button while loading
                                : () => context.read<ActivityCubit>().submitSkipEvent(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.secondaryContainer,
                              foregroundColor: colorScheme.onSecondaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: Text(
                              'Skip',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge!
                                  .copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSubmitButton(
                            context,
                            state,
                            colorScheme,
                            _formKey,
                          ),
                        ),
                      ],
                    )
                  else
                    _buildSubmitButton(
                      context,
                      state,
                      colorScheme,
                      _formKey,
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

/// Helper method to build the submit button, encapsulated for clarity.
  Widget _buildSubmitButton(
    BuildContext context,
    ActivityState state,
    ColorScheme colorScheme,
    GlobalKey<FormState> formKey,
  ) {
    return ElevatedButton.icon(
      onPressed: state.formStatus == FormStatus.loading
          ? null // Disable button while loading
          : () {
              // Trigger local form validation first
              if (formKey.currentState!.validate()) {
                context.read<ActivityCubit>().submitActivity();
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
      icon: state.formStatus == FormStatus.loading
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
            : (state.activityType == ActivityStateType.add
                ? "Add income"
                : "Add expense"),
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
