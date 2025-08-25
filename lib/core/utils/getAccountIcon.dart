import 'package:flutter/material.dart';

import '../../feature/account/data/accountDataState.dart';

/// Helper function to get an icon for AccountType.
IconData getAccountIcon(AccountType type) {
  switch (type) {
    case AccountType.general:
      return Icons.account_balance_wallet;
    case AccountType.brokerage:
      return Icons.bar_chart;
    case AccountType.cryptocurrency:
      return Icons.currency_bitcoin;
  }
}