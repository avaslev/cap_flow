import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/account/logic/investmentCubit.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:intl/intl.dart';

class AddInvestmentOperationForm extends StatelessWidget {
  final String accountId;
  final InvestmentOperationType operationType;
  final ToolType investmentType;
  /// Пресет с детального экрана: тикер и название не вводятся.
  final String? presetTicker;
  final String? presetName;

  const AddInvestmentOperationForm({
    super.key,
    required this.accountId,
    required this.operationType,
    required this.investmentType,
    this.presetTicker,
    this.presetName,
  });

  @override
  Widget build(BuildContext context) {
    final accountsBloc = context.read<AccountsBloc>();

    return BlocProvider<InvestmentCubit>(
      create: (context) => InvestmentCubit(
        accountData: accountsBloc.accountData,
        accountId: accountId,
        operationType: operationType,
        investmentType: investmentType,
        accountsBloc: accountsBloc,
        presetTicker: presetTicker,
        presetName: presetName,
      ),
      child: BlocListener<InvestmentCubit, InvestmentState>(
        listener: (context, state) {
          if (state.formStatus == InvestmentFormStatus.success) {
            final operation = operationType == InvestmentOperationType.buy
                ? 'Куплено'
                : 'Продано';
            final typeName = _investmentTypeName(investmentType);
            final ticker = state.selectedTicker ?? '';
            final qty = state.quantity ?? 0;
            Toast.show(context, '$operation $qty $typeName $ticker!');
            Navigator.pop(context);
          } else if (state.formStatus == InvestmentFormStatus.failure) {
            Toast.show(context, state.errorMessage ?? 'Ошибка при выполнении операции', error: true);
          }
        },
        child: const _InvestmentFormContent(),
      ),
    );
  }

  String _investmentTypeName(ToolType type) {
    switch (type) {
      case ToolType.stocks:
        return 'акций';
      case ToolType.bonds:
        return 'облигаций';
      case ToolType.cryptocurrency:
        return 'криптовалюты';
      default:
        return 'инвестиций';
    }
  }
}

class _InvestmentFormContent extends StatefulWidget {
  const _InvestmentFormContent();

  @override
  State<_InvestmentFormContent> createState() => _InvestmentFormContentState();
}

class _InvestmentFormContentState extends State<_InvestmentFormContent> {
  final TextEditingController _tickerCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _faceValueCtrl = TextEditingController();
  final TextEditingController _nkdCtrl = TextEditingController();
  final FocusNode _tickerFocus = FocusNode();
  /// Подсказки показываются только после изменения текста в поле:
  /// простое выделение/фокус список не открывает.
  bool _tickerDirty = false;

  @override
  void initState() {
    super.initState();
    _tickerCtrl.text =
        context.read<InvestmentCubit>().state.selectedTicker ?? '';
    _nameCtrl.text = context.read<InvestmentCubit>().state.selectedName ?? '';
    // Перестроение при смене фокуса: выпадающий список подсказок
    // закрывается, когда поле тикера теряет фокус.
    _tickerFocus.addListener(_onTickerFocusChanged);
  }

  void _onTickerFocusChanged() {
    if (mounted) {
      if (!_tickerFocus.hasFocus) {
        _tickerDirty = false;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _faceValueCtrl.dispose();
    _nkdCtrl.dispose();
    _tickerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final InvestmentCubit cubit = context.read<InvestmentCubit>();
    final investmentType = cubit.state.investmentType;
    final operationType = cubit.state.operationType;

    final investmentTypeName = _investmentTypeName(investmentType);
    final title = operationType == InvestmentOperationType.buy
        ? "Купить $investmentTypeName"
        : "Продать $investmentTypeName";
    final buttonText =
        operationType == InvestmentOperationType.buy ? "Купить" : "Продать";
    final buttonIcon = operationType == InvestmentOperationType.buy
        ? Icons.add_shopping_cart
        : Icons.sell;
    final buttonColor = operationType == InvestmentOperationType.buy
        ? colorScheme.primary
        : colorScheme.error;

    IconData tickerPrefixIcon;
    switch (investmentType) {
      case ToolType.stocks:
        tickerPrefixIcon = Icons.trending_up;
        break;
      case ToolType.bonds:
        tickerPrefixIcon = Icons.receipt_long;
        break;
      case ToolType.cryptocurrency:
        tickerPrefixIcon = Icons.currency_bitcoin;
        break;
      default:
        tickerPrefixIcon = Icons.currency_exchange;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: BlocBuilder<InvestmentCubit, InvestmentState>(
        builder: (context, state) {
          // Пресет с детального экрана: тикер и название не вводятся.
          final bool hideIdentity =
              context.read<InvestmentCubit>().presetTicker != null;
          // Контроллеры синхронизируются только при внешнем изменении
          // (выбор подсказки), набор текста не конфликтует.
          final String tickerText = state.selectedTicker ?? '';
          if (_tickerCtrl.text != tickerText) {
            _tickerCtrl.text = tickerText;
            _tickerCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: tickerText.length),
            );
          }
          final String nameText = state.selectedName ?? '';
          if (_nameCtrl.text != nameText) {
            _nameCtrl.text = nameText;
            _nameCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: nameText.length),
            );
          }
          final String priceText = state.price?.toString() ?? '';
          if (_priceCtrl.text != priceText) {
            _priceCtrl.text = priceText;
            _priceCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: priceText.length),
            );
          }
          final double? parsedQty = double.tryParse(
            _quantityCtrl.text.replaceAll(',', '.'),
          );
          if (state.quantity != parsedQty) {
            final String qtyText = state.quantity?.toString() ?? '';
            _quantityCtrl.value = TextEditingValue(
              text: qtyText,
              selection: TextSelection.collapsed(offset: qtyText.length),
            );
          }
          // Номинал и НКД: обновляются из провайдера при выборе облигации.
          final double? parsedFace = double.tryParse(
            _faceValueCtrl.text.replaceAll(',', '.'),
          );
          if (state.faceValue != parsedFace) {
            final String faceText = state.faceValue?.toString() ?? '';
            _faceValueCtrl.value = TextEditingValue(
              text: faceText,
              selection: TextSelection.collapsed(offset: faceText.length),
            );
          }
          final double? parsedNkd = double.tryParse(
            _nkdCtrl.text.replaceAll(',', '.'),
          );
          if (state.accruedCouponIncome != parsedNkd) {
            final String nkdText = state.accruedCouponIncome?.toString() ?? '';
            _nkdCtrl.value = TextEditingValue(
              text: nkdText,
              selection: TextSelection.collapsed(offset: nkdText.length),
            );
          }

          return Form(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ),
                  if (!hideIdentity) ...<Widget>[
                    TextFormField(
                      controller: _tickerCtrl,
                      focusNode: _tickerFocus,
                      decoration: InputDecoration(
                        labelText: 'Тикер или название (SBER, Сбербанк…)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        prefixIcon: Icon(tickerPrefixIcon,
                            color: colorScheme.onSurfaceVariant),
                        // Индикатор запроса к внешнему источнику.
                        suffixIcon: state.isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _tickerDirty = true;
                        final upper = value.toUpperCase();
                        if (upper != value) {
                          _tickerCtrl.value = TextEditingValue(
                            text: upper,
                            selection: TextSelection.collapsed(
                              offset: upper.length,
                            ),
                          );
                        }
                        context
                            .read<InvestmentCubit>()
                            .tickerChanged(upper);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Пожалуйста, введите тикер';
                        }
                        return null;
                      },
                    ),
                    // Выпадающий список — только после изменения тикера.
                    if (state.suggestions.isNotEmpty &&
                        _tickerFocus.hasFocus &&
                        _tickerDirty)
                      Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(top: 4),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: state.suggestions
                              .take(8)
                              .map<Widget>(
                                (String option) => ListTile(
                                  dense: true,
                                  title: Text(
                                    option,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  onTap: () {
                                    // Полная строка "TICKER - Name · курс":
                                    // cubit извлечёт тикер, название и курс.
                                    context
                                        .read<InvestmentCubit>()
                                        .tickerChanged(option);
                                    _tickerDirty = false;
                                    _tickerFocus.unfocus();
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Название $investmentTypeName',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.label,
                          color: colorScheme.onSurfaceVariant),
                    ),
                      onChanged: (value) {
                        context.read<InvestmentCubit>().nameChanged(value);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Пожалуйста, введите название';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Количество (шт.)',
                      hintText: 'например, 10.5',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.numbers,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    onChanged: (value) {
                      context
                          .read<InvestmentCubit>()
                          .quantityChanged(value);
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Пожалуйста, введите количество';
                      }
                      final val = double.tryParse(value);
                      if (val == null || val <= 0) {
                        return 'Пожалуйста, введите корректное число';
                      }
                      if (operationType == InvestmentOperationType.sell) {
                        final accountData =
                            context.read<AccountsBloc>().accountData;
                        final existing = accountData
                            .getToolsForAccount(context
                                .read<InvestmentCubit>()
                                .state
                                .accountId ??
                            '')
                            .cast<ToolSummary?>()
                            .firstWhere(
                              (tool) =>
                                  tool != null &&
                                  tool.ticker ==
                                      (state.selectedTicker ?? '')
                                          .toUpperCase() &&
                                  tool.type == investmentType,
                              orElse: () => null,
                            );
                        if (existing != null && val > existing.quantity) {
                          return 'Недостаточно ${investmentTypeName.toLowerCase()} для продажи. Доступно: ${existing.quantity}';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Цена за единицу (RUB)',
                      hintText: 'например, 150.75',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.money,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    onChanged: (value) {
                      context.read<InvestmentCubit>().priceChanged(value);
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Пожалуйста, введите цену за единицу';
                      }
                      final val = double.tryParse(value);
                      if (val == null || val <= 0) {
                        return 'Пожалуйста, введите корректное число';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (investmentType == ToolType.bonds &&
                      operationType == InvestmentOperationType.buy)
                    Column(
                      children: [
                        TextFormField(
                          controller: _faceValueCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Номинал облигации',
                            hintText: 'например, 1000.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            prefixIcon: Icon(Icons.badge,
                                color: colorScheme.onSurfaceVariant),
                          ),
                          onChanged: (value) {
                            context
                                .read<InvestmentCubit>()
                                .faceValueChanged(value);
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Пожалуйста, введите номинал';
                            }
                            final val = double.tryParse(value);
                            if (val == null || val <= 0) {
                              return 'Пожалуйста, введите корректное число';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  if (investmentType == ToolType.bonds)
                    Column(
                      children: [
                        TextFormField(
                          controller: _nkdCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'НКД (RUB)',
                            hintText: 'например, 12.50',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            prefixIcon: Icon(
                                Icons.account_balance_wallet,
                                color: colorScheme.onSurfaceVariant),
                          ),
                          onChanged: (value) {
                            context
                                .read<InvestmentCubit>()
                                .accruedCouponIncomeChanged(value);
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Пожалуйста, введите НКД';
                            }
                            final val = double.tryParse(value);
                            if (val == null || val < 0) {
                              return 'Пожалуйста, введите корректное число';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  TextFormField(
                    initialValue: state.commission?.toString() ?? '',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Комиссия (необязательно, RUB)',
                      hintText: 'например, 5.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.money_off,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    onChanged: (value) {
                      context
                          .read<InvestmentCubit>()
                          .commissionChanged(value);
                    },
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final val = double.tryParse(value);
                        if (val == null || val < 0) {
                          return 'Пожалуйста, введите корректное число';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd')
                          .format(state.selectedDate),
                    ),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Дата операции',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.calendar_today,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: state.selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        context
                            .read<InvestmentCubit>()
                            .dateSelected(picked);
                      }
                    },
                    validator: (value) {
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  state.formStatus == InvestmentFormStatus.loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: buttonColor,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () {
                            context
                                .read<InvestmentCubit>()
                                .submit();
                          },
                          // Покупка — тема (primary); продажа — error.
                          style: buttonColor == colorScheme.error
                              ? ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                  foregroundColor: colorScheme.onError,
                                )
                              : null,
                          icon: Icon(buttonIcon,
                              color: buttonColor == colorScheme.error
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                              size: 20),
                          label: Text(
                            buttonText,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge!
                                .copyWith(
                                  color: buttonColor == colorScheme.error
                                      ? colorScheme.onError
                                      : colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _investmentTypeName(ToolType type) {
    switch (type) {
      case ToolType.stocks:
        return 'Акции';
      case ToolType.bonds:
        return 'Облигации';
      case ToolType.cryptocurrency:
        return 'Криптовалюту';
      default:
        return 'Инвестиция';
    }
  }
}
