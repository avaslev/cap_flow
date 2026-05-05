import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/account/logic/investmentCubit.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:intl/intl.dart';

class AddInvestmentOperationForm extends StatelessWidget {
  final String accountId;
  final InvestmentOperationType operationType;
  final ToolType investmentType;

  const AddInvestmentOperationForm({
    super.key,
    required this.accountId,
    required this.operationType,
    required this.investmentType,
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$operation $qty $typeName $ticker!'),
              ),
            );
            Navigator.pop(context);
          } else if (state.formStatus == InvestmentFormStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ?? 'Ошибка при выполнении операции',
                ),
              ),
            );
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

class _InvestmentFormContent extends StatelessWidget {
  const _InvestmentFormContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final investmentType =
        context.read<InvestmentCubit>().state.investmentType;
    final operationType =
        context.read<InvestmentCubit>().state.operationType;

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

    // Create a controller in the enclosing scope that onSelected can access
    final tickerController = TextEditingController(
      text: context.read<InvestmentCubit>().state.selectedTicker ?? '',
    );

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: BlocBuilder<InvestmentCubit, InvestmentState>(
        builder: (context, state) {
          // Update controller when state changes externally
          final newText = state.selectedTicker ?? '';
          if (tickerController.text != newText) {
            tickerController.text = newText;
            tickerController.selection = TextSelection.fromPosition(
              TextPosition(offset: newText.length),
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
                  Autocomplete<String>(
                    initialValue:
                        TextEditingValue(text: state.selectedTicker ?? ''),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final lowerCaseQuery =
                          textEditingValue.text.toLowerCase();
                      return state.suggestions.where((option) {
                        return option.toLowerCase().contains(lowerCaseQuery);
                      });
                    },
                    onSelected: (selection) {
                      // Extract only the ticker from "TICKER - Name" format
                      final ticker = selection.contains(' - ')
                          ? selection.split(' - ').first
                          : selection;
                      context
                          .read<InvestmentCubit>()
                          .tickerChanged(ticker);
                    },
                    fieldViewBuilder: (
                      context,
                      fieldTextEditingController,
                      fieldFocusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: tickerController,
                        focusNode: fieldFocusNode,
                        decoration: InputDecoration(
                          labelText:
                              'Тикер (например, AAPL, SPY, GOV, BTC)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          prefixIcon: Icon(tickerPrefixIcon,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        onChanged: (value) {
                          final upper = value.toUpperCase();
                          if (upper != value) {
                            fieldTextEditingController.text = upper;
                            fieldTextEditingController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: upper.length),
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
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey('name_${state.selectedName ?? ''}'),
                    initialValue: state.selectedName ?? '',
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
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue:
                        state.quantity?.toString() ?? '',
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
                    initialValue: state.price?.toString() ?? '',
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
                          initialValue:
                              state.faceValue?.toString() ?? '',
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
                          initialValue:
                              state.accruedCouponIncome?.toString() ??
                                  '',
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            minimumSize:
                                const Size(double.infinity, 50),
                          ),
                          icon: Icon(buttonIcon,
                              color: colorScheme.onPrimary, size: 20),
                          label: Text(
                            buttonText,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge!
                                .copyWith(
                                  color: colorScheme.onPrimary,
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
