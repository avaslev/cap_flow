import 'package:flutter/material.dart';

/// Represents a financial wallet.
@immutable
class Wallet {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const Wallet({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, icon: $icon, color: $color)';
  }
}
