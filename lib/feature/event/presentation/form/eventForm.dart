import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/logic/eventCubit.dart';
import 'package:investflow/feature/event/logic/eventState.dart';

class FinancialEventForm extends StatelessWidget {
  final String accountId;
  final FinancialEvent? event;

  const FinancialEventForm({super.key, this.event, required this.accountId});

  @override
  Widget build(BuildContext context) {
    // We need AccountData to initialize the Cubit with initial tools and to
    // perform the actual addActivity operation.
    // final List<ToolSummary> initialMoneyTools = accountData
    //     .getMoneyToolsForAccount(accountData.activeAccountId);

    return BlocProvider<FinancialEventCubit>(
      create:
          (BuildContext context) => FinancialEventCubit(accountId: accountId, event: event),
      child: BlocListener<FinancialEventCubit, FinancialEventEditState>(
        listener: (BuildContext context, FinancialEventEditState state) {
          if (state.formStatus == FormStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event added successfully!')),
            );
            Navigator.pop(context); // Close the bottom sheet
          } else if (state.formStatus == FormStatus.failure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to add event')));
          } else if (state.formStatus == FormStatus.validationError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Please check your input. ${state.errorMessage}')));
          }
        },
        child: const _FinancialEventFormContent(),
      ),
    );
  }
}

/// The actual content of the Add Activity form, built using `BlocBuilder`.
class _FinancialEventFormContent extends StatefulWidget {
  const _FinancialEventFormContent();

  @override
  State<_FinancialEventFormContent> createState() =>
      _FinancialEventFormmContentState();
}

class _FinancialEventFormmContentState
    extends State<_FinancialEventFormContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Future<void> _selectRecurrenceEndDate(BuildContext context, FinancialEventEditState editState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: editState.event.recurrenceEndDate ?? editState.event.date.add(const Duration(days: 1)),
      firstDate: editState.event.date.add(const Duration(days: 1)), // Must be after event date
      lastDate: DateTime(2101),
      helpText: 'Выберите дату окончания',
      cancelText: 'Отмена',
      confirmText: 'Подтвердить',
      fieldLabelText: 'Дата окончания повторения',
      errorFormatText: 'Неверный формат даты',
      errorInvalidText: 'Дата вне диапазона',
    );
    if (picked != null) {
      setState(() {
        context.read<FinancialEventCubit>().recurrenceEndDateChanged(picked);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final FinancialEventLoaded eventsState = context.watch<FinancialEventBloc>().state as FinancialEventLoaded;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: BlocBuilder<FinancialEventCubit, FinancialEventEditState>(
            builder: (BuildContext context, FinancialEventEditState editState) {
              if (editState.event.walletId.isEmpty) {
                context.read<FinancialEventCubit>().walletChanged(eventsState.wallets.first.id);
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text( "Event",
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextFormField(
                    initialValue: editState.event.name,
                    decoration: const InputDecoration(
                      labelText: 'Название события',
                      prefixIcon: Icon(Icons.label),
                    ),
                    onChanged: (String value) => context.read<FinancialEventCubit>().nameChanged(value),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите название';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    initialValue: editState.event.amount > 0 ? editState.event.amount.toString() : '',
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      prefixIcon: Icon(Icons.attach_money),
                      errorText: null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    onChanged: (String value) => context.read<FinancialEventCubit>().amountChanged(value),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите сумму';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Некорректный формат суммы';
                      }
                      if (double.parse(value) <= 0) {
                        return 'Сумма должна быть положительной';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<FinancialEventType>(
                    initialValue: editState.event.type,
                    decoration: const InputDecoration(
                      labelText: 'Тип события',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: FinancialEventType.values
                      .where((FinancialEventType type) => (eventsState.wallets.length > 1) || type != FinancialEventType.transfer )
                      .map<DropdownMenuItem<FinancialEventType>>((FinancialEventType type) {
                      return DropdownMenuItem<FinancialEventType>(
                        value: type,
                        child: Row(
                          children: <Widget>[
                            Icon(type.icon, color: type.color),
                            const SizedBox(width: 10),
                            Text(type.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (FinancialEventType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          context.read<FinancialEventCubit>().typeChanged(newValue);
                          // Reset destination wallet if type is not transfer
                          if (newValue != FinancialEventType.transfer) {
                            context.read<FinancialEventCubit>().destinationWalletChanged(null);
                          } else {
                            context.read<FinancialEventCubit>().destinationWalletChanged((eventsState.wallets.firstWhere(
                              (Wallet w) => w.id != editState.event.walletId,
                            )).id);
                          }
                        });
                      }
                    },
                    validator: (FinancialEventType? value) {
                      if (value == null) {
                        return 'Пожалуйста, выберите тип';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: editState.event.category),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return eventsState.categories.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      }).take(5); // Limit suggestions to 5
                    },
                    onSelected: (String selection) {
                      context.read<FinancialEventCubit>().categoryChanged(selection);
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController textEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                          prefixIcon: Icon(Icons.tag),
                        ),
                        onFieldSubmitted: (String value) {
                          onFieldSubmitted();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    initialValue: editState.event.comment,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                      prefixIcon: Icon(Icons.comment),
                    ),
                    onChanged: (String value) => context.read<FinancialEventCubit>().commentChanged(value),
                    maxLines: 3, // Allow multiple lines for comments
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    initialValue: editState.event.walletId.isEmpty ? eventsState.wallets.first.id : editState.event.walletId,
                    decoration: InputDecoration(
                      labelText: editState.event.type == FinancialEventType.transfer ? 'Кошелек-отправитель' : 'Кошелек',
                      prefixIcon: const Icon(Icons.wallet),
                    ),
                    items: eventsState.wallets.map<DropdownMenuItem<String>>((Wallet wallet) {
                      return DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Row(
                          children: <Widget>[
                            Icon(wallet.icon, color: wallet.color),
                            const SizedBox(width: 10),
                            Text(wallet.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: eventsState.wallets.length > 1
                      ? (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            context.read<FinancialEventCubit>().walletChanged(newValue);
                            // Reset destination wallet if type is not transfer
                            if (editState.event.type == FinancialEventType.transfer && editState.event.destinationWalletId == newValue) {
                              context.read<FinancialEventCubit>().destinationWalletChanged((eventsState.wallets.firstWhere(
                                (Wallet w) => w.id != editState.event.walletId,
                              )).id);
                            }
                          });
                        }
                      }
                      : null, // Disable if only one wallet
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, выберите кошелек';
                      }
                      return null;
                    },
                    // autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  if (editState.event.type == FinancialEventType.transfer ) ...<Widget>[
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      initialValue: eventsState.wallets.last.id,
                      decoration: const InputDecoration(
                        labelText: 'Кошелек-получатель',
                        prefixIcon: Icon(Icons.send_to_mobile),
                      ),
                      items: eventsState.wallets
                          .where((Wallet wallet) => wallet.id != editState.event.walletId) // Cannot transfer to same wallet
                          .map<DropdownMenuItem<String>>((Wallet wallet) {
                        return DropdownMenuItem<String>(
                          value: wallet.id,
                          child: Row(
                            children: <Widget>[
                              Icon(wallet.icon, color: wallet.color),
                              const SizedBox(width: 10),
                              Text(wallet.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            context.read<FinancialEventCubit>().destinationWalletChanged(newValue);
                          });
                        }
                      },
                      validator: (String? value) {
                        if (value == null) {
                          return 'Пожалуйста, выберите кошелек-получатель';
                        }
                        if (value == editState.event.walletId) {
                          return 'Кошелек-получатель не может быть тем же, что и кошелек-отправитель';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd').format(editState.event.date),
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Дата события',
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
                        initialDate: editState.event.date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != editState.event.date) {
                        context.read<FinancialEventCubit>().dateChanged(picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<RecurrenceType>(
                    initialValue: editState.event.recurrenceType,
                    decoration: const InputDecoration(
                      labelText: 'Повторение',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: RecurrenceType.values.map<DropdownMenuItem<RecurrenceType>>((RecurrenceType type) {
                      return DropdownMenuItem<RecurrenceType>(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (RecurrenceType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          context.read<FinancialEventCubit>().recurrenceTypeChanged(newValue);
                          // Reset end date and day of month if recurrence is none
                          if (editState.event.recurrenceType == RecurrenceType.none) {
                            context.read<FinancialEventCubit>().recurrenceEndDateChanged(null);
                            context.read<FinancialEventCubit>().recurrenceDayOfMonthChanged(null);
                          } else if (editState.event.recurrenceType == RecurrenceType.monthlyOnDay && editState.event.recurrenceDayOfMonth == null) {
                            context.read<FinancialEventCubit>().recurrenceDayOfMonthChanged(editState.event.date.day);
                          }
                        });
                      }
                    },
                  ),
                  if (editState.event.recurrenceType != RecurrenceType.none) ...<Widget>[
                    const SizedBox(height: 16.0),
                    InkWell(
                      onTap: () => _selectRecurrenceEndDate(context, editState),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Дата окончания повторения (необязательно)',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        baseStyle: Theme.of(context).textTheme.titleMedium,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              editState.event.recurrenceEndDate == null
                                  ? 'Никогда'
                                  : DateFormat('dd.MM.yyyy').format(editState.event.recurrenceEndDate!),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (editState.event.recurrenceType == RecurrenceType.monthlyOnDay) ...<Widget>[
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<int>(
                      initialValue: editState.event.recurrenceDayOfMonth ?? editState.event.date.day, // Default to event date's day
                      decoration: const InputDecoration(
                        labelText: 'День месяца для повторения',
                        prefixIcon: Icon(Icons.calendar_view_day),
                      ),
                      items: List<int>.generate(31, (int i) => i + 1).map<DropdownMenuItem<int>>((int day) {
                        return DropdownMenuItem<int>(
                          value: day,
                          child: Text('День $day'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        setState(() {
                          context.read<FinancialEventCubit>().recurrenceDayOfMonthChanged(newValue);
                        });
                      },
                      validator: (int? value) {
                        if (editState.event.recurrenceType == RecurrenceType.monthlyOnDay && value == null) {
                          return 'Пожалуйста, выберите день месяца';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed:
                        editState.formStatus == FormStatus.loading
                            ? null // Disable button while loading
                            : () {
                              // Trigger local form validation first
                              if (_formKey.currentState!.validate()) {
                                context.read<FinancialEventCubit>().submit();
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
                    icon:
                        editState.formStatus == FormStatus.loading
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
                      editState.formStatus == FormStatus.loading
                          ? "Saving..."
                          : "Save",
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
