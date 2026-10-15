import 'package:flutter/material.dart';

import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/tool_detail/presentation/components/investment_form_sheet.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';

/// Обзор криптоинструмента: баланс, позиция и кнопки купить/продать.
class CryptoAssetTab extends StatelessWidget {
  final ToolDetailDisplay tool;

  const CryptoAssetTab({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Баланс: количество в валюте монеты + эквивалент.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                tool.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (tool.ticker != null)
                                Text(
                                  tool.ticker!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (tool.ticker != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tool.ticker!,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      formatCurrency(tool.currentValue),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatCryptoQuantity(tool.quantity)} ${tool.ticker ?? ''}'.trim(),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Кнопки операции.
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => showInvestmentFormSheet(
                      context,
                      accountId: tool.accountId,
                      toolId: tool.id,
                      investmentType: ToolType.cryptocurrency,
                      operationType: InvestmentOperationType.buy,
                      presetTicker: tool.ticker,
                      presetName: tool.name,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Купить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => showInvestmentFormSheet(
                      context,
                      accountId: tool.accountId,
                      toolId: tool.id,
                      investmentType: ToolType.cryptocurrency,
                      operationType: InvestmentOperationType.sell,
                      presetTicker: tool.ticker,
                      presetName: tool.name,
                    ),
                    icon: const Icon(Icons.sell),
                    label: const Text('Продать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Позиция.
            Text(
              'Позиция',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  child: _buildStatCard(
                    'Количество (${tool.ticker ?? ''})',
                    _formatCryptoQuantity(tool.quantity),
                    context,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Цена за единицу',
                    tool.quantity.abs() > 0
                        ? formatCurrency(tool.currentValue / tool.quantity.abs())
                        : '—',
                    context,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildStatCard(
              'Стоимость позиции',
              formatCurrency(tool.currentValue),
              context,
            ),
          ],
        ),
      ),
    );
  }

  /// Количество с точностью до 10 знаков, хвостовые нули обрезаются.
  String _formatCryptoQuantity(double v) {
    String s = v.toStringAsFixed(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  Widget _buildStatCard(String label, String value, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
