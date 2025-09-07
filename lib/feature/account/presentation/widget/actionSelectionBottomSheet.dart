import 'package:bookstore/feature/account/data/accountDataState.dart';
import 'package:bookstore/feature/account/data/activityState.dart';
import 'package:bookstore/feature/account/logic/accountBloc.dart';
import 'package:bookstore/feature/account/presentation/widget/form/activity.dart';
import 'package:bookstore/feature/account/presentation/widget/form/transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// A modal bottom sheet for selecting a financial action.
class ActionSelectionBottomSheet extends StatelessWidget {
  const ActionSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountsBloc accountBloc = BlocProvider.of<AccountsBloc>(context);
    return BlocBuilder<AccountsBloc, AccountsState>(
      builder: (context, state) {
        if (state is! AccountsDataState) {
          return const CircularProgressIndicator();
        }
        final accountData = state.accountData;
        final String activeAccountId = accountData.activeAccountId;
        final AccountSummary? activeAccount = accountData.getAccountById(
          accountData.activeAccountId,
        );
        final bool isGeneralAccount =
            activeAccount != null && activeAccount.type == AccountType.general;
        final bool isBrokerageAccount =
            activeAccount != null &&
            activeAccount.type == AccountType.brokerage;
        final bool isCryptocurrencyAccount = // NEW
            activeAccount != null &&
            activeAccount.type == AccountType.cryptocurrency;
        final bool hasMoneyTools =
            accountData
                .getMoneyToolsForAccount(accountData.activeAccountId)
                .isNotEmpty;

        _onTap(StatelessWidget form) {
          Navigator.pop(context); // Close the bottom sheet
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (BuildContext context) => form,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
            ),
            clipBehavior: Clip.antiAliasWithSaveLayer,
          ).then((void value) {
            accountBloc.add(AccountsTransitionEvent());
          });
        }

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "Choose Action",
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.arrow_upward,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    "Доход (Income)",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _onTap(ActivityForm(accountData: accountData, activityStateType: ActivityStateType.add,)),
                ),
                ListTile(
                  leading: Icon(
                    Icons.arrow_downward,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    "Расход (Expense)",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _onTap(ActivityForm(accountData: accountData, activityStateType: ActivityStateType.substract,)),
                ),
                if (hasMoneyTools) // Conditionally show Transfer action
                  ListTile(
                    leading: Icon(
                      Icons.swap_horiz,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Перевод (Transfer)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _onTap(TransferForm(accountData: accountData)),
                  ),
                if (isGeneralAccount) // Only show for general accounts
                  ListTile(
                    leading: Icon(
                      Icons.savings,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Добавить депозит", // Add Deposit
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddDepositForm for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                if (isGeneralAccount) // Only show for general accounts
                  ListTile(
                    leading: Icon(
                      Icons.credit_score,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Добавить кредит (Add Credit)", // New: Add Credit
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text('AddCreditForm for $activeAccountId'),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                if (isGeneralAccount) // Only show for general accounts
                  ListTile(
                    leading: Icon(
                      Icons.category,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      "Добавить инструмент (Прочее)", // Add Other Tool
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddOtherToolForm for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                if (isBrokerageAccount) ...<Widget>[
                  // New: Actions for Brokerage accounts
                  ListTile(
                    leading: Icon(
                      Icons.add_shopping_cart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить Акции (Buy Stocks)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Buy Stocks) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.sell,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать Акции (Sell Stocks)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Sell Stocks) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                  // New: ETF Actions
                  ListTile(
                    leading: Icon(
                      Icons.add_chart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить ETF (Buy ETF)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Buy ETF) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.trending_down,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать ETF (Sell ETF)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Sell ETF) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                  // New: Bond Actions
                  ListTile(
                    leading: Icon(
                      Icons.attach_money,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить Облигации (Buy Bonds)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Buy Bonds) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.money_off_csred,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать Облигации (Sell Bonds)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Sell Bonds) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                ],
                // NEW: Cryptocurrency Actions
                if (isCryptocurrencyAccount) ...<Widget>[
                  ListTile(
                    leading: Icon(
                      Icons.currency_bitcoin,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      "Купить Криптовалюту (Buy Crypto)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Buy Crypto) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.currency_yen, // Using yen for selling crypto
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      "Продать Криптовалюту (Sell Crypto)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (BuildContext context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Center(
                              child: Text(
                                'AddInvestmentOperationForm (Sell Crypto) for $activeAccountId',
                              ),
                            ),
                          );
                        },
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.0),
                          ),
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(
                    Icons.list_alt,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    "Посмотреть активности по счету",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('View account activities selected'),
                      ),
                    );
                    // TODO: Implement navigation to All Events screen (or specific account events)
                  },
                ),
                const SizedBox(height: 8.0), // Some bottom padding
              ],
            ),
          ),
        );
      },
    );
  }
}

// /// A modal bottom sheet for adding a new 'other' tool.
// class AddOtherToolForm extends StatefulWidget {
//   final String accountId;

//   const AddOtherToolForm({super.key, required this.accountId});

//   @override
//   State<AddOtherToolForm> createState() => _AddOtherToolFormState();
// }

// class _AddOtherToolFormState extends State<AddOtherToolForm> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _amountController = TextEditingController();

//   String? _selectedWithdrawalToolName;

//   @override
//   void initState() {
//     super.initState();
//     // Pre-select the first available money tool if any exist
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final AccountData accountData =
//           Provider.of<AccountData>(context, listen: false);
//       final List<Tool> moneyTools =
//           accountData.getMoneyToolsForAccount(widget.accountId);
//       if (moneyTools.isNotEmpty) {
//         setState(() {
//           _selectedWithdrawalToolName = moneyTools.first.name;
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _amountController.dispose();
//     super.dispose();
//   }

//   void _addOtherTool() {
//     if (_formKey.currentState!.validate()) {
//       final String name = _nameController.text.trim();
//       final double amount = double.parse(_amountController.text);

//       if (_selectedWithdrawalToolName == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please select a withdrawal money tool.')),
//         );
//         return;
//       }

//       Provider.of<AccountData>(context, listen: false).addOtherTool(
//         accountId: widget.accountId,
//         name: name,
//         amount: amount,
//         withdrawalToolName: _selectedWithdrawalToolName!,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Other tool "$name" added successfully!')),
//       );
//       Navigator.pop(context); // Close the bottom sheet
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;
//     final AccountData accountData = Provider.of<AccountData>(context);
//     final List<Tool> moneyTools =
//         accountData.getMoneyToolsForAccount(widget.accountId);

//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 16.0),
//                 child: Text(
//                   "Add New Other Tool",
//                   style: Theme.of(context).textTheme.headlineSmall!.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: colorScheme.onSurface,
//                       ),
//                 ),
//               ),
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(
//                   labelText: 'Tool Name',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.label,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter a name for the tool';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: _selectedWithdrawalToolName,
//                 decoration: InputDecoration(
//                   labelText: 'Withdrawal Account (Money Tool)',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.money, color: colorScheme.onSurfaceVariant),
//                 ),
//                 items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
//                   return DropdownMenuItem<String>(
//                     value: tool.name,
//                     child:
//                         Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
//                   );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedWithdrawalToolName = newValue;
//                   });
//                 },
//                 validator: (String? value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please select a withdrawal money tool';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _amountController,
//                 keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true, signed: false),
//                 decoration: InputDecoration(
//                   labelText: 'Amount (Quantity for this tool)',
//                   hintText: 'e.g., 50.00',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.numbers, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter the amount';
//                   }
//                   final double? val = double.tryParse(value);
//                   if (val == null || val <= 0) {
//                     return 'Please enter a valid positive number';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton.icon(
//                 onPressed: _addOtherTool,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: colorScheme.primary,
//                   foregroundColor: colorScheme.onPrimary,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   minimumSize:
//                       const Size(double.infinity, 50), // Ensure button fills width
//                 ),
//                 icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
//                 label: Text(
//                   "Add Other Tool",
//                   style: Theme.of(context).textTheme.labelLarge!.copyWith(
//                         color: colorScheme.onPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// A modal bottom sheet for adding income.
// class AddIncomeForm extends StatefulWidget {
//   final String accountId;

//   const AddIncomeForm({super.key, required this.accountId});

//   @override
//   State<AddIncomeForm> createState() => _AddIncomeFormState();
// }

// class _AddIncomeFormState extends State<AddIncomeForm> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _amountController = TextEditingController();
//   final TextEditingController _categoryController = TextEditingController();
//   final TextEditingController _commentController = TextEditingController();
//   final TextEditingController _dateController = TextEditingController();

//   DateTime? _selectedDate;
//   String? _selectedMoneyToolName; // To hold the selected money tool

//   @override
//   void initState() {
//     super.initState();
//     _selectedDate = DateTime.now();
//     _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

//     // // Pre-select the first available money tool for the active account
//     // WidgetsBinding.instance.addPostFrameCallback((_) {
//     //   final AccountData accountData =
//     //       Provider.of<AccountData>(context, listen: false);
//     //   final List<Tool> moneyTools =
//     //       accountData.getMoneyToolsForAccount(widget.accountId);
//     //   if (moneyTools.isNotEmpty) {
//     //     setState(() {
//     //       _selectedMoneyToolName = moneyTools.first.name;
//     //     });
//     //   }
//     // });
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _categoryController.dispose();
//     _commentController.dispose();
//     _dateController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate!,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//         _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
//       });
//     }
//   }

//   void _addIncome() {
//     if (_formKey.currentState!.validate()) {
//       final String category = _categoryController.text.trim();
//       final double amount = double.parse(_amountController.text);
//       final String? comment = _commentController.text.trim().isEmpty
//           ? null
//           : _commentController.text.trim();

//       if (_selectedDate == null || _selectedMoneyToolName == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please fill all required fields.')),
//         );
//         return;
//       }

//       // Provider.of<AccountData>(context, listen: false).addIncome(
//       //   accountId: widget.accountId,
//       //   toolName: _selectedMoneyToolName!,
//       //   amount: amount,
//       //   date: _selectedDate!,
//       //   category: category,
//       //   comment: comment,
//       // );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Income added successfully!')),
//       );
//       Navigator.pop(context); // Close the bottom sheet
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;
//     // final AccountData accountData = Provider.of<AccountData>(context);
//     // final List<Tool> moneyTools =
//     //     accountData.getMoneyToolsForAccount(widget.accountId);

//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 16.0),
//                 child: Text(
//                   "Add Income",
//                   style: Theme.of(context).textTheme.headlineSmall!.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: colorScheme.onSurface,
//                       ),
//                 ),
//               ),
//               DropdownButtonFormField<String>(
//                 value: _selectedMoneyToolName,
//                 decoration: InputDecoration(
//                   labelText: 'Target Money Tool',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.money, color: colorScheme.onSurfaceVariant),
//                 ),
//                 items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
//                   return DropdownMenuItem<String>(
//                     value: tool.name,
//                     child:
//                         Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
//                   );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedMoneyToolName = newValue;
//                   });
//                 },
//                 validator: (String? value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please select a money tool';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _amountController,
//                 keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true, signed: false),
//                 decoration: InputDecoration(
//                   labelText: 'Amount (RUB equivalent)',
//                   hintText: 'e.g., 5000.00',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.attach_money,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter the amount';
//                   }
//                   final double? val = double.tryParse(value);
//                   if (val == null || val <= 0) {
//                     return 'Please enter a valid positive number';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _dateController,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                   labelText: 'Date of Operation',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.calendar_today,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 onTap: () => _selectDate(context),
//                 validator: (String? value) {
//                   if (_selectedDate == null) {
//                     return 'Please select a date';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _categoryController,
//                 decoration: InputDecoration(
//                   labelText: 'Category',
//                   hintText: 'e.g., Salary, Gift, Refund',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.category, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter a category';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _commentController,
//                 decoration: InputDecoration(
//                   labelText: 'Comment (Optional)',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.comment, color: colorScheme.onSurfaceVariant),
//                 ),
//                 maxLines: 2,
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton.icon(
//                 onPressed: _addIncome,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: colorScheme.primary,
//                   foregroundColor: colorScheme.onPrimary,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   minimumSize: const Size(double.infinity, 50),
//                 ),
//                 icon: Icon(Icons.add_circle_outline,
//                     color: colorScheme.onPrimary, size: 20),
//                 label: Text(
//                   "Add Income",
//                   style: Theme.of(context).textTheme.labelLarge!.copyWith(
//                         color: colorScheme.onPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// A modal bottom sheet for adding expense.
// class AddExpenseForm extends StatefulWidget {
//   final String accountId;

//   const AddExpenseForm({super.key, required this.accountId});

//   @override
//   State<AddExpenseForm> createState() => _AddExpenseFormState();
// }

// class _AddExpenseFormState extends State<AddExpenseForm> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _amountController = TextEditingController();
//   final TextEditingController _categoryController = TextEditingController();
//   final TextEditingController _commentController = TextEditingController();
//   final TextEditingController _dateController = TextEditingController();

//   DateTime? _selectedDate;
//   String? _selectedMoneyToolName; // To hold the selected money tool

//   @override
//   void initState() {
//     super.initState();
//     _selectedDate = DateTime.now();
//     _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

//     // Pre-select the first available money tool for the active account
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final AccountData accountData =
//           Provider.of<AccountData>(context, listen: false);
//       final List<Tool> moneyTools =
//           accountData.getMoneyToolsForAccount(widget.accountId);
//       if (moneyTools.isNotEmpty) {
//         setState(() {
//           _selectedMoneyToolName = moneyTools.first.name;
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _categoryController.dispose();
//     _commentController.dispose();
//     _dateController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate!,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//         _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
//       });
//     }
//   }

//   void _addExpense() {
//     if (_formKey.currentState!.validate()) {
//       final String category = _categoryController.text.trim();
//       final double amount = double.parse(_amountController.text);
//       final String? comment = _commentController.text.trim().isEmpty
//           ? null
//           : _commentController.text.trim();

//       if (_selectedDate == null || _selectedMoneyToolName == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please fill all required fields.')),
//         );
//         return;
//       }

//       Provider.of<AccountData>(context, listen: false).addExpense(
//         accountId: widget.accountId,
//         toolName: _selectedMoneyToolName!,
//         amount: amount,
//         date: _selectedDate!,
//         category: category,
//         comment: comment,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Expense added successfully!')),
//       );
//       Navigator.pop(context); // Close the bottom sheet
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;
//     final AccountData accountData = Provider.of<AccountData>(context);
//     final List<Tool> moneyTools =
//         accountData.getMoneyToolsForAccount(widget.accountId);

//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 16.0),
//                 child: Text(
//                   "Add Expense",
//                   style: Theme.of(context).textTheme.headlineSmall!.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: colorScheme.onSurface,
//                       ),
//                 ),
//               ),
//               DropdownButtonFormField<String>(
//                 value: _selectedMoneyToolName,
//                 decoration: InputDecoration(
//                   labelText: 'Source Money Tool',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.money, color: colorScheme.onSurfaceVariant),
//                 ),
//                 items: moneyTools.map<DropdownMenuItem<String>>((Tool tool) {
//                   return DropdownMenuItem<String>(
//                     value: tool.name,
//                     child:
//                         Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
//                   );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedMoneyToolName = newValue;
//                   });
//                 },
//                 validator: (String? value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please select a money tool';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _amountController,
//                 keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true, signed: false),
//                 decoration: InputDecoration(
//                   labelText: 'Amount (RUB equivalent)',
//                   hintText: 'e.g., 50.00',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.money_off, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter the amount';
//                   }
//                   final double? val = double.tryParse(value);
//                   if (val == null || val <= 0) {
//                     return 'Please enter a valid positive number';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _dateController,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                   labelText: 'Date of Operation',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.calendar_today,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 onTap: () => _selectDate(context),
//                 validator: (String? value) {
//                   if (_selectedDate == null) {
//                     return 'Please select a date';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _categoryController,
//                 decoration: InputDecoration(
//                   labelText: 'Category',
//                   hintText: 'e.g., Groceries, Rent, Transport',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.category, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter a category';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _commentController,
//                 decoration: InputDecoration(
//                   labelText: 'Comment (Optional)',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.comment, color: colorScheme.onSurfaceVariant),
//                 ),
//                 maxLines: 2,
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton.icon(
//                 onPressed: _addExpense,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: colorScheme.error, // Use error color for expense button
//                   foregroundColor: colorScheme.onError,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   minimumSize: const Size(double.infinity, 50),
//                 ),
//                 icon: Icon(Icons.remove_circle_outline,
//                     color: colorScheme.onError, size: 20),
//                 label: Text(
//                   "Add Expense",
//                   style: Theme.of(context).textTheme.labelLarge!.copyWith(
//                         color: colorScheme.onError,
//                         fontWeight: FontWeight.w600,
//                       ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// A modal bottom sheet for making a transfer between money tools.
// class AddTransferForm extends StatefulWidget {
//   final String activeAccountId;

//   const AddTransferForm({super.key, required this.activeAccountId});

//   @override
//   State<AddTransferForm> createState() => _AddTransferFormState();
// }

// class _AddTransferFormState extends State<AddTransferForm> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _amountController = TextEditingController();
//   final TextEditingController _commissionController = TextEditingController();
//   final TextEditingController _dateController = TextEditingController();

//   DateTime? _selectedDate;
//   String? _selectedSourceToolName; // Only money tools from active account
//   String? _selectedDestinationToolIdentifier; // Format: "toolName|accountId"

//   @override
//   void initState() {
//     super.initState();
//     _selectedDate = DateTime.now();
//     _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final AccountData accountData =
//           Provider.of<AccountData>(context, listen: false);
//       final List<Tool> sourceMoneyTools =
//           accountData.getMoneyToolsForAccount(widget.activeAccountId);
//       if (sourceMoneyTools.isNotEmpty) {
//         setState(() {
//           _selectedSourceToolName = sourceMoneyTools.first.name;
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _commissionController.dispose();
//     _dateController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate!,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//         _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
//       });
//     }
//   }

//   void _makeTransfer() {
//     if (_formKey.currentState!.validate()) {
//       if (_selectedSourceToolName == null ||
//           _selectedDestinationToolIdentifier == null ||
//           _selectedDate == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please fill all required fields.')),
//         );
//         return;
//       }

//       final double amount = double.parse(_amountController.text);
//       final double commission = _commissionController.text.trim().isEmpty
//           ? 0.0
//           : double.parse(_commissionController.text);

//       final List<String> destinationParts =
//           _selectedDestinationToolIdentifier!.split('|');
//       final String destinationToolName = destinationParts[0];
//       final String destinationAccountId = destinationParts[1];

//       Provider.of<AccountData>(context, listen: false).makeToolTransfer(
//         fromToolName: _selectedSourceToolName!,
//         fromAccountId: widget.activeAccountId,
//         toToolName: destinationToolName,
//         toAccountId: destinationAccountId,
//         amount: amount,
//         date: _selectedDate!,
//         commission: commission,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Transfer completed successfully!')),
//       );
//       Navigator.pop(context); // Close the bottom sheet
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;
//     final AccountData accountData = Provider.of<AccountData>(context);

//     // Filter source tools by active account
//     final List<Tool> sourceMoneyTools =
//         accountData.getMoneyToolsForAccount(widget.activeAccountId);

//     // Get all money tools for destination, exclude already selected source tool
//     final List<Tool> allPossibleDestinationTools =
//         accountData.allMoneyTools.where((Tool tool) {
//       // Don't allow transferring to the same tool it's coming from
//       return !(tool.name == _selectedSourceToolName &&
//           tool.accountId == widget.activeAccountId);
//     }).toList();

//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 16.0),
//                 child: Text(
//                   "Make Transfer",
//                   style: Theme.of(context).textTheme.headlineSmall!.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: colorScheme.onSurface,
//                       ),
//                 ),
//               ),
//               DropdownButtonFormField<String>(
//                 value: _selectedSourceToolName,
//                 decoration: InputDecoration(
//                   labelText: 'From (Source Money Tool)',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.outbox, color: colorScheme.onSurfaceVariant),
//                 ),
//                 items: sourceMoneyTools.map<DropdownMenuItem<String>>((Tool tool) {
//                   return DropdownMenuItem<String>(
//                     value: tool.name,
//                     child:
//                         Text('${tool.name} (${formatCurrency(tool.currentValue)})'),
//                   );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedSourceToolName = newValue;
//                     // If the selected source tool is now the same as the destination, clear destination
//                     if (_selectedDestinationToolIdentifier != null) {
//                       final List<String> destParts =
//                           _selectedDestinationToolIdentifier!.split('|');
//                       if (destParts[0] == _selectedSourceToolName &&
//                           destParts[1] == widget.activeAccountId) {
//                         _selectedDestinationToolIdentifier = null;
//                       }
//                     }
//                   });
//                 },
//                 validator: (String? value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please select a source money tool';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: _selectedDestinationToolIdentifier,
//                 decoration: InputDecoration(
//                   labelText: 'To (Destination Money Tool)',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.inbox, color: colorScheme.onSurfaceVariant),
//                 ),
//                 items: allPossibleDestinationTools
//                     .map<DropdownMenuItem<String>>((Tool tool) {
//                   final String toolAccountName =
//                       accountData.getAccountById(tool.accountId)?.name ??
//                           'Unknown Account';
//                   return DropdownMenuItem<String>(
//                     value: '${tool.name}|${tool.accountId}',
//                     child: Text(
//                         '${tool.name} (${toolAccountName}) - ${formatCurrency(tool.currentValue)}'),
//                   );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedDestinationToolIdentifier = newValue;
//                   });
//                 },
//                 validator: (String? value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please select a destination money tool';
//                   }
//                   // Prevent selecting the same tool as source
//                   final List<String> destParts = value.split('|');
//                   if (destParts[0] == _selectedSourceToolName &&
//                       destParts[1] == widget.activeAccountId) {
//                     return 'Cannot transfer to the same source tool';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _amountController,
//                 keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true, signed: false),
//                 decoration: InputDecoration(
//                   labelText: 'Amount (RUB equivalent)',
//                   hintText: 'e.g., 1000.00',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.payments, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter the amount';
//                   }
//                   final double? val = double.tryParse(value);
//                   if (val == null || val <= 0) {
//                     return 'Please enter a valid positive number';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _dateController,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                   labelText: 'Date of Transfer',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.calendar_today,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 onTap: () => _selectDate(context),
//                 validator: (String? value) {
//                   if (_selectedDate == null) {
//                     return 'Please select a date';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _commissionController,
//                 keyboardType: const TextInputType.numberWithOptions(
//                     decimal: true, signed: false),
//                 decoration: InputDecoration(
//                   labelText: 'Commission (Optional, RUB equivalent)',
//                   hintText: 'e.g., 5.00',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.money_off, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value != null && value.isNotEmpty) {
//                     final double? val = double.tryParse(value);
//                     if (val == null || val < 0) {
//                       return 'Please enter a valid non-negative number';
//                     }
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton.icon(
//                 onPressed: _makeTransfer,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: colorScheme.primary,
//                   foregroundColor: colorScheme.onPrimary,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   minimumSize: const Size(double.infinity, 50),
//                 ),
//                 icon: Icon(Icons.swap_horiz,
//                     color: colorScheme.onPrimary, size: 20),
//                 label: Text(
//                   "Complete Transfer",
//                   style: Theme.of(context).textTheme.labelLarge!.copyWith(
//                         color: colorScheme.onPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// A modal bottom sheet for buying or selling stocks or ETFs.
// class AddInvestmentOperationForm extends StatefulWidget {
//   final String accountId;
//   final InvestmentOperationType operationType;
//   final ToolType investmentType; // e.g., ToolType.stocks or ToolType.etf or ToolType.bonds

//   const AddInvestmentOperationForm({
//     super.key,
//     required this.accountId,
//     required this.operationType,
//     required this.investmentType,
//   });

//   @override
//   State<AddInvestmentOperationForm> createState() =>
//       _AddInvestmentOperationFormState();
// }

// class _AddInvestmentOperationFormState
//     extends State<AddInvestmentOperationForm> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _tickerController = TextEditingController();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _quantityController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   final TextEditingController _commissionController = TextEditingController();
//   final TextEditingController _dateController = TextEditingController();
//   // New controllers for bonds
//   final TextEditingController _faceValueController = TextEditingController();
//   final TextEditingController _accruedCouponIncomeController =
//       TextEditingController();

//   DateTime? _selectedDate;
//   List<String> _investmentSuggestions = <String>[];

//   @override
//   void initState() {
//     super.initState();
//     _selectedDate = DateTime.now();
//     _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

//     final AccountData accountData =
//         Provider.of<AccountData>(context, listen: false);

//     if (widget.operationType == InvestmentOperationType.sell) {
//       // For selling, suggest only investments currently held in this account of the specified type
//       _investmentSuggestions = accountData
//           .getToolsForAccount(widget.accountId)
//           .where((Tool tool) =>
//               tool.type == widget.investmentType && tool.ticker != null)
//           .map<String>((Tool tool) => tool.ticker!)
//           .toList();
//     } else {
//       // For buying, suggest all known investment options relevant to the type
//       _investmentSuggestions = accountData.allInvestmentOptions.keys
//           .where((String ticker) {
//             // Determine if the ticker matches the current investmentType
//             // This is a heuristic based on initial data, not a robust solution for all tickers
//             if (widget.investmentType == ToolType.stocks) {
//               return [
//                 'AAPL',
//                 'TSLA',
//                 'NVDA',
//                 'GOOG',
//                 'MSFT',
//                 'AMZN',
//                 'FB',
//                 'JPM',
//                 'XOM',
//                 'V',
//                 'PG',
//                 'KO',
//                 'NFLX',
//                 'DIS',
//                 'BA',
//                 'GS',
//                 'SBER',
//                 'GAZP',
//                 'LKOH',
//                 'YNDX'
//               ].contains(ticker);
//             } else if (widget.investmentType == ToolType.etf) {
//               return ['SPY', 'QQQ', 'DIA', 'GLD', 'ARKK'].contains(ticker);
//             } else if (widget.investmentType == ToolType.bonds) {
//               return ['GOV', 'CORP'].contains(ticker);
//             } else if (widget.investmentType == ToolType.cryptocurrency) {
//               return ['BTC', 'ETH', 'XRP', 'LTC'].contains(ticker);
//             }
//             return false;
//           }).toList();
//     }
//     _investmentSuggestions.sort(); // Keep suggestions sorted
//   }

//   @override
//   void dispose() {
//     _tickerController.dispose();
//     _nameController.dispose();
//     _quantityController.dispose();
//     _priceController.dispose();
//     _commissionController.dispose();
//     _dateController.dispose();
//     _faceValueController.dispose();
//     _accruedCouponIncomeController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate!,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//         _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
//       });
//     }
//   }

//   void _performInvestmentOperation() {
//     if (_formKey.currentState!.validate()) {
//       final String ticker = _tickerController.text.trim().toUpperCase();
//       final String name = _nameController.text.trim();
//       final double quantity = double.parse(_quantityController.text);
//       final double price = double.parse(_priceController.text);
//       final double commission = _commissionController.text.trim().isEmpty
//           ? 0.0
//           : double.parse(_commissionController.text);

//       double? faceValue;
//       double? accruedCouponIncome;

//       if (widget.investmentType == ToolType.bonds) {
//         faceValue = double.parse(_faceValueController.text);
//         accruedCouponIncome = double.parse(_accruedCouponIncomeController.text);
//       }

//       if (_selectedDate == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please select a date.')),
//         );
//         return;
//       }

//       final AccountData accountData =
//           Provider.of<AccountData>(context, listen: false);

//       if (widget.operationType == InvestmentOperationType.buy) {
//         if (widget.investmentType == ToolType.stocks) {
//           accountData.buyStock(
//             accountId: widget.accountId,
//             ticker: ticker,
//             stockName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Bought $quantity shares of $ticker!')),
//           );
//         } else if (widget.investmentType == ToolType.etf) {
//           accountData.buyEtf(
//             accountId: widget.accountId,
//             ticker: ticker,
//             etfName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Bought $quantity units of $ticker ETF!')),
//           );
//         } else if (widget.investmentType == ToolType.bonds) {
//           accountData.buyBond(
//             accountId: widget.accountId,
//             ticker: ticker,
//             bondName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             faceValue: faceValue!,
//             accruedCouponIncome: accruedCouponIncome!,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Bought $quantity bonds of $ticker!')),
//           );
//         } else if (widget.investmentType == ToolType.cryptocurrency) {
//           // NEW
//           accountData.buyCrypto(
//             accountId: widget.accountId,
//             ticker: ticker,
//             cryptoName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//                 content: Text(
//                     'Bought $quantity units of $ticker cryptocurrency!')),
//           );
//         }
//       } else {
//         // Sell operation
//         if (widget.investmentType == ToolType.stocks) {
//           accountData.sellStock(
//             accountId: widget.accountId,
//             ticker: ticker,
//             stockName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Sold $quantity shares of $ticker!')),
//           );
//         } else if (widget.investmentType == ToolType.etf) {
//           accountData.sellEtf(
//             accountId: widget.accountId,
//             ticker: ticker,
//             etfName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Sold $quantity units of $ticker ETF!')),
//           );
//         } else if (widget.investmentType == ToolType.bonds) {
//           accountData.sellBond(
//             accountId: widget.accountId,
//             ticker: ticker,
//             bondName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             accruedCouponIncome: accruedCouponIncome!,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Sold $quantity bonds of $ticker!')),
//           );
//         } else if (widget.investmentType == ToolType.cryptocurrency) {
//           // NEW
//           accountData.sellCrypto(
//             accountId: widget.accountId,
//             ticker: ticker,
//             cryptoName: name,
//             quantity: quantity,
//             pricePerUnit: price,
//             commission: commission,
//             date: _selectedDate!,
//           );
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//                 content: Text(
//                     'Sold $quantity units of $ticker cryptocurrency!')),
//           );
//         }
//       }
//       Navigator.pop(context); // Close the bottom sheet
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ColorScheme colorScheme = Theme.of(context).colorScheme;
//     final AccountData accountData =
//         Provider.of<AccountData>(context, listen: false);

//     final String investmentTypeName;
//     IconData tickerPrefixIcon;
//     switch (widget.investmentType) {
//       case ToolType.stocks:
//         investmentTypeName = "Акции";
//         tickerPrefixIcon = Icons.trending_up;
//         break;
//       case ToolType.etf:
//         investmentTypeName = "ETF";
//         tickerPrefixIcon = Icons.auto_graph;
//         break;
//       case ToolType.bonds:
//         investmentTypeName = "Облигации";
//         tickerPrefixIcon = Icons.receipt_long;
//         break;
//       case ToolType.cryptocurrency: // NEW
//         investmentTypeName = "Криптовалюту";
//         tickerPrefixIcon = Icons.currency_bitcoin;
//         break;
//       default:
//         investmentTypeName = "Инвестиция"; // Fallback
//         tickerPrefixIcon = Icons.currency_exchange;
//     }

//     final String title = widget.operationType == InvestmentOperationType.buy
//         ? "Купить $investmentTypeName"
//         : "Продать $investmentTypeName";
//     final String buttonText = widget.operationType == InvestmentOperationType.buy
//         ? "Купить"
//         : "Продать";
//     final IconData buttonIcon = widget.operationType == InvestmentOperationType.buy
//         ? Icons.add_shopping_cart
//         : Icons.sell;
//     final Color buttonColor = widget.operationType == InvestmentOperationType.buy
//         ? colorScheme.primary
//         : colorScheme.error;

//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 16.0),
//                 child: Text(
//                   title,
//                   style: Theme.of(context).textTheme.headlineSmall!.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: colorScheme.onSurface,
//                       ),
//                 ),
//               ),
//               Autocomplete<String>(
//                 optionsBuilder: (TextEditingValue textEditingValue) {
//                   if (textEditingValue.text == '') {
//                     return const Iterable<String>.empty();
//                   }
//                   final String lowerCaseQuery =
//                       textEditingValue.text.toLowerCase();
//                   return _investmentSuggestions.where((String option) {
//                     return option.toLowerCase().contains(lowerCaseQuery) ||
//                            (accountData.allInvestmentOptions[option]?.toLowerCase() ?? '')
//                                .contains(lowerCaseQuery);
//                   });
//                 },
//                 onSelected: (String selection) {
//                   _tickerController.text = selection;
//                   _nameController.text =
//                       accountData.allInvestmentOptions[selection] ?? '';
//                   debugPrint('You selected $selection');
//                 },
//                 fieldViewBuilder: (BuildContext context,
//                     TextEditingController fieldTextEditingController,
//                     FocusNode fieldFocusNode,
//                     VoidCallback onFieldSubmitted) {
//                   // Sync internal controller with Autocomplete's controller
//                   _tickerController.text = fieldTextEditingController.text;
//                   return TextFormField(
//                     controller: fieldTextEditingController,
//                     focusNode: fieldFocusNode,
//                     decoration: InputDecoration(
//                       labelText: 'Ticker Symbol (e.g., AAPL, SPY, GOV, BTC)',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12.0),
//                       ),
//                       prefixIcon: Icon(tickerPrefixIcon, // Use dynamic icon
//                           color: colorScheme.onSurfaceVariant),
//                     ),
//                     textCapitalization: TextCapitalization.characters,
//                     validator: (String? value) {
//                       if (value == null || value.trim().isEmpty) {
//                         return 'Please enter a ticker symbol';
//                       }
//                       return null;
//                     },
//                     onChanged: (String value) {
//                       final String? name =
//                           accountData.allInvestmentOptions[value.toUpperCase()];
//                       if (name != null && name.isNotEmpty) {
//                         _nameController.text = name;
//                       } else {
//                         // Clear name if ticker doesn't match a known investment
//                         _nameController.text = '';
//                       }
//                     },
//                   );
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(
//                   labelText: '$investmentTypeName Name',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.label, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter a $investmentTypeName name';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _quantityController,
//                 keyboardType:
//                     const TextInputType.numberWithOptions(decimal: true),
//                 decoration: InputDecoration(
//                   labelText: 'Quantity (шт.)',
//                   hintText: 'e.g., 10.5',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.numbers, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter quantity';
//                   }
//                   final double? val = double.tryParse(value);
//                   if (val == null || val <= 0) {
//                     return 'Please enter a valid positive number';
//                   }
//                   // For sell operation, validate sufficient quantity based on specific investment type
//                   if (widget.operationType == InvestmentOperationType.sell) {
//                     final Tool? existingInvestment = _tickerController.text.trim().isEmpty
//                         ? null
//                         : accountData.getToolsForAccount(widget.accountId).cast<Tool?>().firstWhere(
//                               (Tool? tool) =>
//                                   tool != null &&
//                                   tool.ticker == _tickerController.text.trim().toUpperCase() &&
//                                   tool.type == widget.investmentType,
//                               orElse: () => null,
//                             );

//                     if (existingInvestment == null || val > existingInvestment.quantity) {
//                       return 'Insufficient ${investmentTypeName.toLowerCase()} to sell. Available: ${existingInvestment?.quantity ?? 0}';
//                     }
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _priceController,
//                 keyboardType:
//                     const TextInputType.numberWithOptions(decimal: true),
//                 decoration: InputDecoration(
//                   labelText: 'Price Per Unit (RUB)',
//                   hintText: 'e.g., 150.75',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.money,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter price per unit';
//                   }
//                   final double? val = double.tryParse(value);
//                   if (val == null || val <= 0) {
//                     return 'Please enter a valid positive number';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               if (widget.investmentType == ToolType.bonds &&
//                   widget.operationType == InvestmentOperationType.buy)
//                 Column(
//                   children: <Widget>[
//                     TextFormField(
//                       controller: _faceValueController,
//                       keyboardType:
//                           const TextInputType.numberWithOptions(decimal: true),
//                       decoration: InputDecoration(
//                         labelText: 'Bond Face Value (Nominal)',
//                         hintText: 'e.g., 1000.00',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12.0),
//                         ),
//                         prefixIcon: Icon(Icons.badge,
//                             color: colorScheme.onSurfaceVariant),
//                       ),
//                       validator: (String? value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Please enter bond nominal value';
//                         }
//                         final double? val = double.tryParse(value);
//                         if (val == null || val <= 0) {
//                           return 'Please enter a valid positive number';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                   ],
//                 ),
//               if (widget.investmentType == ToolType.bonds)
//                 Column(
//                   children: <Widget>[
//                     TextFormField(
//                       controller: _accruedCouponIncomeController,
//                       keyboardType:
//                           const TextInputType.numberWithOptions(decimal: true),
//                       decoration: InputDecoration(
//                         labelText: 'Accrued Coupon Income (RUB)',
//                         hintText: 'e.g., 12.50',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12.0),
//                         ),
//                         prefixIcon: Icon(Icons.account_balance_wallet,
//                             color: colorScheme.onSurfaceVariant),
//                       ),
//                       validator: (String? value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Please enter accrued coupon income (ACI)';
//                         }
//                         final double? val = double.tryParse(value);
//                         if (val == null || val < 0) {
//                           return 'Please enter a valid non-negative number';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                   ],
//                 ),
//               TextFormField(
//                 controller: _commissionController,
//                 keyboardType:
//                     const TextInputType.numberWithOptions(decimal: true),
//                 decoration: InputDecoration(
//                   labelText: 'Commission (Optional, RUB)',
//                   hintText: 'e.g., 5.00',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon:
//                       Icon(Icons.money_off, color: colorScheme.onSurfaceVariant),
//                 ),
//                 validator: (String? value) {
//                   if (value != null && value.isNotEmpty) {
//                     final double? val = double.tryParse(value);
//                     if (val == null || val < 0) {
//                       return 'Please enter a valid non-negative number';
//                     }
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _dateController,
//                 readOnly: true,
//                 decoration: InputDecoration(
//                   labelText: 'Date of Operation',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   prefixIcon: Icon(Icons.calendar_today,
//                       color: colorScheme.onSurfaceVariant),
//                 ),
//                 onTap: () => _selectDate(context),
//                 validator: (String? value) {
//                   if (_selectedDate == null) {
//                     return 'Please select a date';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton.icon(
//                 onPressed: _performInvestmentOperation,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: buttonColor,
//                   foregroundColor: colorScheme.onPrimary,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   minimumSize: const Size(double.infinity, 50),
//                 ),
//                 icon: Icon(buttonIcon, color: colorScheme.onPrimary, size: 20),
//                 label: Text(
//                   buttonText,
//                   style: Theme.of(context).textTheme.labelLarge!.copyWith(
//                         color: colorScheme.onPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
