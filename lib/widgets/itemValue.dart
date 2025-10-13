import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ItemValue extends StatelessWidget {
  final String type;
  final double amount;

  const ItemValue({
    super.key,
    required this.type,
    required this.amount,
  });

  Color getColor(String type) {
    switch (type) {
      case 'income':
        return Colors.green;
      case 'expense':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2);
    return Text(
      '${type == 'expense' ? '-' : ''}${currencyFormat.format(amount)}',
      style: TextStyle(
        color: getColor(type),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}