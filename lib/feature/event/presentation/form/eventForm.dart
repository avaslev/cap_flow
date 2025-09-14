import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/logic/eventEvent.dart';
import 'package:investflow/feature/event/logic/eventState.dart';
import 'package:investflow/feature/event/logic/waletBloc.dart';

class FinancialEventFormPage extends StatefulWidget {
  final FinancialEvent? event; // Nullable for adding, non-null for editing
  final String accountId;

  const FinancialEventFormPage({super.key, this.event, required this.accountId});

  @override
  State<FinancialEventFormPage> createState() => _FinancialEventFormPageState();
}

class _FinancialEventFormPageState extends State<FinancialEventFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _categoryController; // Now used for Autocomplete
  late FocusNode _categoryFocusNode; // Required for Autocomplete when supplying a TextEditingController
  late TextEditingController _commentController;
  late FinancialEventType _selectedType;
  late DateTime _selectedDate;
  late String _selectedWalletId; // Source wallet
  late String? _selectedDestinationWalletId; // Destination wallet, nullable

  late RecurrenceType _selectedRecurrenceType;
  late DateTime? _selectedRecurrenceEndDate;
  late int? _selectedRecurrenceDayOfMonth; // For MonthlyOnDay

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _amountController = TextEditingController(text: widget.event?.amount.toStringAsFixed(2) ?? '');
    _categoryController = TextEditingController(text: widget.event?.category ?? ''); // Initialize with existing category
    _categoryFocusNode = FocusNode(); // Initialize the FocusNode
    _commentController = TextEditingController(text: widget.event?.comment ?? '');
    _selectedType = widget.event?.type ?? FinancialEventType.expense; // Default to expense
    _selectedDate = widget.event?.date ?? DateTime.now();
    _selectedWalletId = widget.event?.walletId ?? 'sdfdsf'; // Default to first wallet

    // Initialize destination wallet for transfer events, if editing
    _selectedDestinationWalletId = widget.event?.type == FinancialEventType.transfer
        ? widget.event?.destinationWalletId ?? initialWallets[0].id // Default if not set
        : null;

    // If destination wallet is null for a transfer event during creation, set it to a valid default
    if (_selectedType == FinancialEventType.transfer && _selectedDestinationWalletId == null) {
      _selectedDestinationWalletId = initialWallets.firstWhere(
            (Wallet w) => w.id != _selectedWalletId,
            orElse: () => initialWallets[0],
          ).id;
    }

    _selectedRecurrenceType = widget.event?.recurrenceType ?? RecurrenceType.none;
    _selectedRecurrenceEndDate = widget.event?.recurrenceEndDate;
    _selectedRecurrenceDayOfMonth = widget.event?.recurrenceDayOfMonth;

    // If it's a new event and MonthlyOnDay is selected, set a reasonable default day
    if (widget.event == null && _selectedRecurrenceType == RecurrenceType.monthlyOnDay && _selectedRecurrenceDayOfMonth == null) {
      _selectedRecurrenceDayOfMonth = _selectedDate.day;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose(); // Dispose the FocusNode
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Подтвердить',
      fieldLabelText: 'Дата события',
      errorFormatText: 'Неверный формат даты',
      errorInvalidText: 'Дата вне диапазона',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // If MonthlyOnDay is selected, and it was defaulting to _selectedDate.day, update it.
        // Or if it's a new event and MonthlyOnDay is active, default it.
        if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay && widget.event == null) {
          _selectedRecurrenceDayOfMonth = _selectedDate.day;
        }
      });
    }
  }

  Future<void> _selectRecurrenceEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRecurrenceEndDate ?? _selectedDate.add(const Duration(days: 1)),
      firstDate: _selectedDate.add(const Duration(days: 1)), // Must be after event date
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
        _selectedRecurrenceEndDate = picked;
      });
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final String id = widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString(); // Simple unique ID
      final FinancialEvent newEvent = FinancialEvent(
        id: id,
        name: _nameController.text,
        amount: double.parse(_amountController.text),
        type: _selectedType,
        category: _categoryController.text.trim().isEmpty ? 'Без категории' : _categoryController.text.trim(),
        date: _selectedDate,
        walletId: _selectedWalletId,
        destinationWalletId: _selectedType == FinancialEventType.transfer ? _selectedDestinationWalletId : null,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(), // Save comment
        recurrenceType: _selectedRecurrenceType,
        recurrenceEndDate: _selectedRecurrenceType == RecurrenceType.none ? null : _selectedRecurrenceEndDate,
        recurrenceDayOfMonth: _selectedRecurrenceType == RecurrenceType.monthlyOnDay ? (_selectedRecurrenceDayOfMonth ?? _selectedDate.day) : null,
      );

      if (widget.event == null) {
        // Adding new event
        context.read<FinancialEventBloc>().add(AddFinancialEvent(newEvent));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Событие "${newEvent.name}" добавлено')),
        );
      } else {
        // Editing existing event
        context.read<FinancialEventBloc>().add(EditFinancialEvent(newEvent));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Событие "${newEvent.name}" обновлено')),
        );
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique categories from loaded financial events
    final FinancialEventState eventState = context.watch<FinancialEventBloc>().state;
    List<String> allCategories = <String>[];
    if (eventState is FinancialEventLoaded) {
      allCategories = eventState.events
          .map<String>((FinancialEvent e) => e.category)
          .where((String category) => category.isNotEmpty && category != 'Без категории') // Exclude empty/default
          .toSet() // Get unique categories
          .toList();
    }

    return Container(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название события',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите название';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
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
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Тип события',
                  prefixIcon: Icon(Icons.category),
                ),
                items: FinancialEventType.values
                  .where((FinancialEventType type) => (eventState.wallets.length > 1) || type != FinancialEventType.transfer )
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
                      _selectedType = newValue;
                      // Reset destination wallet if type is not transfer
                      if (newValue != FinancialEventType.transfer) {
                        _selectedDestinationWalletId = null;
                      } else {
                        if (walletState is WalletLoaded) {
                          _selectedDestinationWalletId = (walletState.wallets.firstWhere(
                            (Wallet w) => w.id != _selectedWalletId,
                          )).id;
                        }
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
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return allCategories.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  }).take(5); // Limit suggestions to 5
                },
                onSelected: (String selection) {
                  _categoryController.text = selection;
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Use the provided textEditingController and focusNode for the TextFormField.
                  return TextFormField(
                    controller: textEditingController, // Use the controller provided by Autocomplete
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Категория (необязательно)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onFieldSubmitted: (String value) {
                      onFieldSubmitted();
                    },
                  );
                },
                // Pass our state-managed controller and focus node to Autocomplete.
                // Autocomplete will then use these for its internal TextFormField and pass them back to fieldViewBuilder.
                textEditingController: _categoryController,
                focusNode: _categoryFocusNode,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 3, // Allow multiple lines for comments
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                initialValue: walletState.wallets.first.id,
                decoration: InputDecoration(
                  labelText: _selectedType == FinancialEventType.transfer ? 'Кошелек-отправитель' : 'Кошелек',
                  prefixIcon: const Icon(Icons.wallet),
                ),
                items: walletState.wallets.map<DropdownMenuItem<String>>((Wallet wallet) {
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
              onChanged: walletState.wallets.length > 1
              ? (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedWalletId = newValue;
                      // Ensure destination wallet is not the same as source if it's a transfer
                      if (_selectedType == FinancialEventType.transfer && _selectedDestinationWalletId == newValue) {
                        _selectedDestinationWalletId = (walletState.wallets.firstWhere(
                              (Wallet w) => w.id != newValue,
                        )).id;
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
              if (_selectedType == FinancialEventType.transfer ) ...<Widget>[
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  initialValue: walletState.wallets.last.id,
                  decoration: const InputDecoration(
                    labelText: 'Кошелек-получатель',
                    prefixIcon: Icon(Icons.send_to_mobile),
                  ),
                  items: walletState.wallets
                      .where((Wallet wallet) => wallet.id != _selectedWalletId) // Cannot transfer to same wallet
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
                        _selectedDestinationWalletId = newValue;
                      });
                    }
                  },
                  validator: (String? value) {
                    if (value == null) {
                      return 'Пожалуйста, выберите кошелек-получатель';
                    }
                    if (value == _selectedWalletId) {
                      return 'Кошелек-получатель не может быть тем же, что и кошелек-отправитель';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16.0),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата события',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  baseStyle: Theme.of(context).textTheme.titleMedium,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Icon(Icons.edit_calendar),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<RecurrenceType>(
                value: _selectedRecurrenceType,
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
                      _selectedRecurrenceType = newValue;
                      // Reset end date and day of month if recurrence is none
                      if (_selectedRecurrenceType == RecurrenceType.none) {
                        _selectedRecurrenceEndDate = null;
                        _selectedRecurrenceDayOfMonth = null;
                      } else if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay && _selectedRecurrenceDayOfMonth == null) {
                        _selectedRecurrenceDayOfMonth = _selectedDate.day; // Default to event's day
                      }
                    });
                  }
                },
              ),
              if (_selectedRecurrenceType != RecurrenceType.none) ...<Widget>[
                const SizedBox(height: 16.0),
                InkWell(
                  onTap: () => _selectRecurrenceEndDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата окончания повторения (необязательно)',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                    baseStyle: Theme.of(context).textTheme.titleMedium,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _selectedRecurrenceEndDate == null
                              ? 'Никогда'
                              : DateFormat('dd.MM.yyyy').format(_selectedRecurrenceEndDate!),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Icon(Icons.edit_calendar),
                      ],
                    ),
                  ),
                ),
              ],
              if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay) ...<Widget>[
                const SizedBox(height: 16.0),
                DropdownButtonFormField<int>(
                  value: _selectedRecurrenceDayOfMonth ?? _selectedDate.day, // Default to event date's day
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
                      _selectedRecurrenceDayOfMonth = newValue;
                    });
                  },
                  validator: (int? value) {
                    if (_selectedRecurrenceType == RecurrenceType.monthlyOnDay && value == null) {
                      return 'Пожалуйста, выберите день месяца';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 32.0),
              ElevatedButton.icon(
                onPressed: _saveEvent,
                icon: const Icon(Icons.save),
                label: Text(widget.event == null ? 'Сохранить событие' : 'Обновить событие'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
