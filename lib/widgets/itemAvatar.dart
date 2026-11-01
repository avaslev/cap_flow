import 'package:flutter/material.dart';

class ItemAvatar extends StatelessWidget {
  final String type;

  const ItemAvatar({super.key, required this.type});

  IconData getIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_upward;
      case 'expense':
        return Icons.arrow_downward;
      case 'transfer':
        return Icons.swap_horiz;
      case 'interAccountTransfer':
        return Icons.sync_alt;
      default:
        return Icons.info;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case 'income':
        return Colors.green;
      case 'expense':
        return Colors.red;
      case 'interAccountTransfer':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: getColor(type).withValues(alpha: 0.1),
      child: Icon(getIcon(type), color: getColor(type)),
    );
  }
}
