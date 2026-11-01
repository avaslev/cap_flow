import 'package:flutter/material.dart';
import 'package:capflow/data/models/tools/tool_kind.dart';

/// Represents a financial wallet.
@immutable
class Wallet {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String accountId;
  final String accountName;
  final String ticker;
  final ToolType type;

  const Wallet({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.accountId = '',
    this.accountName = '',
    this.ticker = 'RUB',
    this.type = ToolType.money,
  });

  bool get isMoney => type == ToolType.money;

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, accountId: $accountId, '
        'ticker: $ticker, type: ${type.name})';
  }
}
