import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/core/utils/calculateNextOccurrence.dart';
import 'package:investflow/feature/event/data/event.dart';
import 'package:investflow/feature/event/data/wallet.dart';
import 'package:investflow/feature/event/logic/eventBloc.dart';
import 'package:investflow/feature/event/logic/eventEvent.dart';
import 'package:investflow/feature/event/logic/eventCubit.dart';
import 'package:investflow/feature/event/logic/eventState.dart';

class FinancialEventForm extends StatelessWidget {
  final String accountId;
  final FinancialEvent? event;
  final ScrollController? scrollController;

  const FinancialEventForm({
    super.key,
    this.event,
    required this.accountId,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FinancialEventCubit>(
      create:
          (BuildContext context) =>
              FinancialEventCubit(accountId: accountId, event: event),
      child: BlocListener<FinancialEventCubit, FinancialEventEditState>(
        listener: (BuildContext context, FinancialEventEditState state) {
          if (state.formStatus == FormStatus.success) {
            Toast.show(context, 'Событие сохранено');
            Navigator.pop(context);
          } else if (state.formStatus == FormStatus.failure) {
            Toast.show(context, 'Не удалось сохранить событие', error: true);
          } else if (state.formStatus == FormStatus.validationError) {
            Toast.show(context, 'Проверьте заполнение полей. ${state.errorMessage ?? ''}');
          }
        },
        child: _FinancialEventFormContent(
          scrollController: scrollController,
          isEditing: event != null,
        ),
      ),
    );
  }
}

/// The actual content of the Add Activity form, built using `BlocBuilder`.
class _FinancialEventFormContent extends StatefulWidget {
  final ScrollController? scrollController;
  final bool isEditing;

  const _FinancialEventFormContent({
    this.scrollController,
    this.isEditing = false,
  });

  @override
  State<_FinancialEventFormContent> createState() =>
      _FinancialEventFormContentState();
}

class _FinancialEventFormContentState
    extends State<_FinancialEventFormContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final FinancialEvent _originalEvent;

  @override
  void initState() {
    super.initState();
    _originalEvent = context.read<FinancialEventCubit>().state.event;
    // Default wallet for new events — once, instead of a side effect in build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final FinancialEventEditState state = context
          .read<FinancialEventCubit>()
          .state;
      if (state.event.walletId.isEmpty) {
        final FinancialEventLoaded? blocState =
            context.read<FinancialEventBloc>().state
                as FinancialEventLoaded?;
        if (blocState != null && blocState.wallets.isNotEmpty) {
          context
              .read<FinancialEventCubit>()
              .walletChanged(blocState.wallets.first.id);
        }
      }
    });
  }

  /// True when the user changed anything compared to the original event.
  bool _hasUnsavedChanges(FinancialEventEditState state) {
    final FinancialEvent original = _originalEvent;
    final FinancialEvent current = state.event;
    if (original.id.isEmpty) {
      // New event: any meaningful input counts as unsaved progress.
      return current.name.isNotEmpty ||
          current.amount > 0 ||
          current.category.isNotEmpty ||
          (current.comment != null && current.comment!.isNotEmpty) ||
          current.walletId.isNotEmpty ||
          current.destinationWalletId != null ||
          current.recurrenceType != RecurrenceType.none;
    }
    return current.name != original.name ||
        current.amount != original.amount ||
        current.type != original.type ||
        current.category != original.category ||
        current.comment != original.comment ||
        current.date != original.date ||
        current.walletId != original.walletId ||
        current.destinationWalletId != original.destinationWalletId ||
        current.recurrenceType != original.recurrenceType ||
        current.recurrenceEndDate != original.recurrenceEndDate ||
        current.recurrenceDayOfMonth != original.recurrenceDayOfMonth;
  }

  /// Asks the user before discarding unsaved input.
  Future<void> _confirmDiscard() async {
    final FinancialEventEditState state = context
        .read<FinancialEventCubit>()
        .state;
    if (!_hasUnsavedChanges(state)) {
      Navigator.of(context).pop();
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Закрыть без сохранения?'),
          content: const Text(
            'Вы изменили данные события. Закрыть без сохранения?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Продолжить редактирование'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  VoidCallback _buildSavePressed(
    BuildContext context,
    FinancialEventEditState editState,
    GlobalKey<FormState> formKey,
  ) {
    return () {
      if (formKey.currentState!.validate()) {
        context.read<FinancialEventCubit>().submit();
      } else {
        Toast.show(context, 'Проверьте заполнение полей.');
      }
    };
  }

  Future<void> _selectRecurrenceEndDate(
    BuildContext context,
    FinancialEventEditState editState,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          editState.event.recurrenceEndDate ??
          editState.event.date.add(const Duration(days: 1)),
      firstDate: editState.event.date.add(const Duration(days: 1)),
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
    final FinancialEventLoaded eventsState =
        context.watch<FinancialEventBloc>().state as FinancialEventLoaded;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20.0),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              widget.isEditing
                  ? 'Редактирование события'
                  : 'Новое событие',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          BlocBuilder<FinancialEventCubit, FinancialEventEditState>(
            builder: (BuildContext context, FinancialEventEditState editState) {
              return Form(
                key: _formKey,
                child: BlocBuilder<FinancialEventCubit, FinancialEventEditState>(
                  builder: (
                    BuildContext context,
                    FinancialEventEditState editState,
                  ) {
                    return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextFormField(
                            initialValue: editState.event.name,
                            decoration: const InputDecoration(
                              labelText: 'Название события',
                              prefixIcon: Icon(Icons.label),
                            ),
                            onChanged:
                                (String value) => context
                                    .read<FinancialEventCubit>()
                                    .nameChanged(value),
                            validator: (String? value) {
                              if (value == null || value.isEmpty) {
                                return 'Пожалуйста, введите название';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          TextFormField(
                            initialValue:
                                editState.event.amount > 0
                                    ? editState.event.amount.toString()
                                    : '',
                            decoration: const InputDecoration(
                              labelText: 'Сумма (RUB)',
                              prefixIcon: Icon(Icons.attach_money),
                              errorText: null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: false,
                            ),
                            onChanged:
                                (String value) => context
                                    .read<FinancialEventCubit>()
                                    .amountChanged(value),
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
                          SegmentedButton<FinancialEventType>(
                            segments:
                                FinancialEventType.values
                                    .where(
                                      (FinancialEventType type) =>
                                          (eventsState.wallets.length > 1) ||
                                          type != FinancialEventType.transfer,
                                    )
                                    .map(
                                      (FinancialEventType type) =>
                                          ButtonSegment<FinancialEventType>(
                                            value: type,
                                            icon: Icon(type.icon),
                                            label: Text(type.displayName),
                                          ),
                                    )
                                    .toList(),
                            selected: <FinancialEventType>{
                              editState.event.type,
                            },
                            showSelectedIcon: false,
                            onSelectionChanged: (
                              Set<FinancialEventType> selection,
                            ) {
                              final FinancialEventType newValue =
                                  selection.first;
                              setState(() {
                                context
                                    .read<FinancialEventCubit>()
                                    .typeChanged(newValue);
                                // Reset destination wallet if type is not transfer
                                if (newValue != FinancialEventType.transfer) {
                                  context
                                      .read<FinancialEventCubit>()
                                      .destinationWalletChanged(null);
                                } else {
                                  context
                                      .read<FinancialEventCubit>()
                                      .destinationWalletChanged(
                                        (eventsState.wallets.firstWhere(
                                          (Wallet w) =>
                                              w.id != editState.event.walletId,
                                        )).id,
                                      );
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16.0),
                          Autocomplete<String>(
                            initialValue: TextEditingValue(
                              text: editState.event.category,
                            ),
                            optionsBuilder: (
                              TextEditingValue textEditingValue,
                            ) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return eventsState.categories
                                  .where((String option) {
                                    return option.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    );
                                  })
                                  .take(5); // Limit suggestions to 5
                            },

                            onSelected: (String selection) {
                              context
                                  .read<FinancialEventCubit>()
                                  .categoryChanged(selection);
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
                                onChanged: (String text) {
                                  context
                                      .read<FinancialEventCubit>()
                                      .categoryChanged(text);
                                },
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
                            onChanged:
                                (String value) => context
                                    .read<FinancialEventCubit>()
                                    .commentChanged(value),
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                          ),
                          const SizedBox(height: 16.0),
                          DropdownButtonFormField<String>(
                            initialValue:
                                editState.event.walletId.isEmpty
                                    ? eventsState.wallets.first.id
                                    : editState.event.walletId,
                            decoration: InputDecoration(
                              labelText:
                                  editState.event.type ==
                                          FinancialEventType.transfer
                                      ? 'Кошелек-отправитель'
                                      : 'Кошелек',
                            ),
                            items:
                                eventsState.wallets.map<
                                  DropdownMenuItem<String>
                                >((Wallet wallet) {
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
                            onChanged:
                                eventsState.wallets.length > 1
                                    ? (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          context
                                              .read<FinancialEventCubit>()
                                              .walletChanged(newValue);
                                          // Reset destination wallet if type is not transfer
                                          if (editState.event.type ==
                                                  FinancialEventType.transfer &&
                                              editState
                                                      .event
                                                      .destinationWalletId ==
                                                  newValue) {
                                            context
                                                .read<FinancialEventCubit>()
                                                .destinationWalletChanged(
                                                  (eventsState.wallets
                                                      .firstWhere(
                                                        (Wallet w) =>
                                                            w.id !=
                                                            editState
                                                                .event
                                                                .walletId,
                                                      )).id,
                                                );
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
                          if (editState.event.type ==
                              FinancialEventType.transfer) ...<Widget>[
                            const SizedBox(height: 16.0),
                            DropdownButtonFormField<String>(
                              initialValue: eventsState.wallets.last.id,
                              decoration: const InputDecoration(
                                labelText: 'Кошелек-получатель',
                              ),
                              items:
                                  eventsState.wallets
                                      .where(
                                        (Wallet wallet) =>
                                            wallet.id !=
                                            editState.event.walletId,
                                      ) // Cannot transfer to same wallet
                                      .map<DropdownMenuItem<String>>((
                                        Wallet wallet,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: wallet.id,
                                          child: Row(
                                            children: <Widget>[
                                              Icon(
                                                wallet.icon,
                                                color: wallet.color,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(wallet.name),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    context
                                        .read<FinancialEventCubit>()
                                        .destinationWalletChanged(newValue);
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
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: editState.event.date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null &&
                                  picked != editState.event.date) {
                                context.read<FinancialEventCubit>().dateChanged(
                                  picked,
                                );
                                if (picked.isBefore(DateTime.now()) &&
                                    !widget.isEditing &&
                                    mounted) {
                                  Toast.show(context, 'Внимание: выбрана прошедшая дата.',);
                                }
                              }
                            },
                            child: InputDecorator(
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
                              child: Text(
                                DateFormat(
                                  'dd.MM.yyyy',
                                ).format(editState.event.date),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          DropdownButtonFormField<RecurrenceType>(
                            initialValue: editState.event.recurrenceType,
                            decoration: InputDecoration(
                              labelText: 'Повторение',
                              prefixIcon: const Icon(Icons.repeat),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              constraints: const BoxConstraints(
                                maxWidth: double.infinity,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            isExpanded: true,
                            items:
                                RecurrenceType.values
                                    .map<DropdownMenuItem<RecurrenceType>>((
                                      RecurrenceType type,
                                    ) {
                                      return DropdownMenuItem<RecurrenceType>(
                                        value: type,
                                        child: Text(
                                          type.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    })
                                    .toList(),
                            onChanged: (RecurrenceType? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  context
                                      .read<FinancialEventCubit>()
                                      .recurrenceTypeChanged(newValue);
                                  if (editState.event.recurrenceType ==
                                      RecurrenceType.none) {
                                    context
                                        .read<FinancialEventCubit>()
                                        .recurrenceEndDateChanged(null);
                                    context
                                        .read<FinancialEventCubit>()
                                        .recurrenceDayOfMonthChanged(null);
                                  } else if (editState.event.recurrenceType ==
                                          RecurrenceType.monthlyOnDay &&
                                      editState.event.recurrenceDayOfMonth ==
                                          null) {
                                    context
                                        .read<FinancialEventCubit>()
                                        .recurrenceDayOfMonthChanged(
                                          editState.event.date.day,
                                        );
                                  }
                                });
                              }
                            },
                          ),

                          if (editState.event.recurrenceType !=
                              RecurrenceType.none) ...<Widget>[
                            const SizedBox(height: 8.0),
                            Builder(
                              builder: (BuildContext context) {
                                final DateTime? preview =
                                    calculateNextOccurrence(
                                      initialDate: editState.event.date,
                                      recurrenceType:
                                          editState.event.recurrenceType.name,
                                      recurrenceEndDate:
                                          editState.event.recurrenceEndDate,
                                      recurrenceDayOfMonth:
                                          editState.event.recurrenceDayOfMonth,
                                      now: DateTime.now(),
                                    );
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    preview == null
                                        ? 'Повторение завершено'
                                        : 'Следующее: ${DateFormat('dd.MM.yyyy').format(preview)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8.0),
                            InkWell(
                              onTap:
                                  () => _selectRecurrenceEndDate(
                                    context,
                                    editState,
                                  ),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText:
                                      'Дата окончания повторения (необязательно)',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                baseStyle:
                                    Theme.of(context).textTheme.titleMedium,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      editState.event.recurrenceEndDate == null
                                          ? 'Никогда'
                                          : DateFormat('dd.MM.yyyy').format(
                                            editState.event.recurrenceEndDate!,
                                          ),
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (editState.event.recurrenceType ==
                              RecurrenceType.monthlyOnDay) ...<Widget>[
                            const SizedBox(height: 16.0),
                            DropdownButtonFormField<int>(
                              initialValue:
                                  editState.event.recurrenceDayOfMonth ??
                                  editState
                                      .event
                                      .date
                                      .day, // Default to event date's day
                              decoration: const InputDecoration(
                                labelText: 'День месяца для повторения',
                                prefixIcon: Icon(Icons.calendar_view_day),
                              ),
                              items:
                                  List<int>.generate(
                                    31,
                                    (int i) => i + 1,
                                  ).map<DropdownMenuItem<int>>((int day) {
                                    return DropdownMenuItem<int>(
                                      value: day,
                                      child: Text('День $day'),
                                    );
                                  }).toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  context
                                      .read<FinancialEventCubit>()
                                      .recurrenceDayOfMonthChanged(newValue);
                                });
                              },
                              validator: (int? value) {
                                if (editState.event.recurrenceType ==
                                        RecurrenceType.monthlyOnDay &&
                                    value == null) {
                                  return 'Пожалуйста, выберите день месяца';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: <Widget>[
                              if (widget.isEditing) ...<Widget>[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        editState.formStatus ==
                                            FormStatus.loading
                                        ? null
                                        : () async {
                                            final bool? confirmed =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (
                                                    BuildContext dialogContext,
                                                  ) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                        'Удаление события',
                                                      ),
                                                      content: const Text(
                                                        'Удалить это событие навсегда?',
                                                      ),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false),
                                                          child: const Text(
                                                            'Отмена',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true),
                                                          child: const Text(
                                                            'Удалить',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                            if (confirmed == true &&
                                                context.mounted) {
                                              context
                                                  .read<FinancialEventBloc>()
                                                  .add(
                                                    DeleteFinancialEvent(
                                                      editState.event.id,
                                                    ),
                                                  );
                                              Navigator.pop(context);
                                            }
                                          },
                                    // Разрушающее действие: error/onError,
                                    // геометрия из темы.
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                      foregroundColor: colorScheme.onError,
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    // Цвет текста наследует onError кнопки.
                                    label: const Text('Удалить'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _buildSavePressed(context, editState, _formKey),
                                  icon: editState.formStatus == FormStatus.loading
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
                                        ? 'Сохранение...'
                                        : widget.isEditing
                                            ? 'Сохранить'
                                            : 'Добавить',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge!
                                        .copyWith(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
}
