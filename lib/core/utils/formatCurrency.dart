import 'package:intl/intl.dart';

/// Formats a double value as a currency string.
String formatCurrency(double amount) {
  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'ru_RU',
    symbol: '₽',
    decimalDigits: 2,
  );
  return currencyFormat.format(amount);
}