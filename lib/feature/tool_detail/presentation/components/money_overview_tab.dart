import 'package:flutter/material.dart';

import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/repository/settingsRepository.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

/// Обзор денежного инструмента: карточка баланса.
class MoneyOverviewTab extends StatelessWidget {
  final ToolDetailDisplay tool;

  const MoneyOverviewTab({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // Для недефолтной валюты показываем баланс в валюте инструмента,
    // а эквивалент по курсу — второй строкой.
    return FutureBuilder<String>(
      future: SettingsRepository().getDefaultCurrency(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String defaultCurrency = snapshot.data ?? 'RUB';
        final bool isForeign =
            tool.ticker != null && tool.ticker != defaultCurrency;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tool.ticker ?? 'RUB',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isForeign
                          ? 'Баланс (${tool.ticker})'
                          : 'Текущий баланс',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isForeign
                          ? '${tool.quantity.toStringAsFixed(2)} ${tool.ticker}'
                          : formatCurrency(tool.currentValue),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    if (isForeign) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        '≈ ${formatCurrency(tool.currentValue)}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
