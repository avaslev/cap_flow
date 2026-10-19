import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/account.dart';
import 'package:investflow/data/repository/accountRepository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';
import 'package:investflow/feature/report/logic/bloc.dart';
import 'package:investflow/feature/report/logic/reportEvent.dart';
import 'package:investflow/feature/report/logic/reportState.dart';
import 'package:investflow/feature/report/presentation/widgets/legendWidget.dart';

/// Подпись месяца для оси X вида "01.26" (12 месяцев окна отчёта).
String formatMonth(int monthOffset) {
  final DateTime now = DateTime.now();
  final DateTime monthDate = DateTime(now.year, now.month - 11 + monthOffset);
  return "${monthDate.month.toString().padLeft(2, '0')}.${monthDate.year.toString().substring(2)}";
}

/// Сокращённый формат числа: 1.2M / 34.5K / 480 (знак сохраняется).
String formatNumber(double value) {
  // Сокращение по модулю, знак сохраняется (кредит = отрицательное).
  final double abs = value.abs();
  final String sign = value < 0 ? '-' : '';
  if (abs >= 1000000) {
    return '$sign${(abs / 1000000).toStringAsFixed(1)}M';
  } else if (abs >= 1000) {
    return '$sign${(abs / 1000).toStringAsFixed(1)}K';
  }
  return '$sign${abs.toStringAsFixed(0)}';
}

/// Обёртка карточки отчёта (градиент + рамка, как у остальных секций).
Widget _reportCard({required BuildContext context, required List<Widget> children}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerLow],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

/// Пустое состояние карточки.
Widget _reportEmptyCard(BuildContext context, String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      ),
    ),
  );
}

/// Заголовок секции отчёта: иконка + название слева, подпись справа.
Widget _sectionTitle(BuildContext context, IconData icon, String title, {String? hint}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      if (hint != null)
        Text(
          hint,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
        ),
    ],
  );
}

class ReportScreen extends StatelessWidget {
  final String accountId;
  ReportScreen({super.key, required this.accountId});

  final Map<String, Color> assetColors = {
    'total': Colors.blue,
    'money': Colors.green,
    'stocks': Colors.orange,
    'bonds': Colors.purple,
    'funds': Colors.teal,
    'crypto': Colors.amber,
    'other': Colors.grey,
  };

  // Generate 12 months for the last year — helpers formatMonth/formatNumber
  // вынесены на уровень файла (используются и карточкой категорий).

  Widget _buildSummaryCards(BuildContext context, ReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(/*...*/),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ...data.summary.entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: assetColors[entry.key] ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        formatNumber(entry.value),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: assetColors[entry.key] ?? Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  // Градиентные цвета
  LinearGradient incomeGradient = LinearGradient(
    colors: [Colors.green.shade400, Colors.green.shade700],
  );
  LinearGradient expenseGradient = LinearGradient(
    colors: [Colors.red.shade400, Colors.red.shade700],
  );
  LinearGradient totalGradient = LinearGradient(
    colors: [Colors.blue.shade400, Colors.blue.shade700],
  );

  // Линейная диаграмма с улучшениями
  Widget _buildTotalLineChart(BuildContext context, ReportData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Общая сумма',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: totalGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.totalLineDataPercentage.toString() + '%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 2.2,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50000,
                  verticalInterval: 1,
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget:
                          (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              formatNumber(value),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final int monthIndex = value.toInt();
                        if (monthIndex < 0 || monthIndex >= 12) {
                          return const SizedBox();
                        }
                        // Pre‑computed month labels like "01.26", "02.26", …
                        final List<String> monthLabels = List.generate(12, (i) => formatMonth(i));
                        final String monthLabel = monthLabels[monthIndex];
                        // Show full "01.26" only for January (index 0); otherwise just the month part.
                        final String display = data.totalLineData[monthIndex].month == "01" ? monthLabel : monthLabel.split('.').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            display,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (touchedBarSpots) {
                      return touchedBarSpots.map((spot) {
                        return LineTooltipItem(
                          formatNumber(spot.y),
                          TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(12, (i) => FlSpot(i.toDouble(), data.totalLineData[i].value)),
                    isCurved: true,
                    color: Colors.transparent,
                    barWidth: 4,
                    shadow: Shadow(
                      color: totalGradient.colors.last.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          totalGradient.colors.last.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter:
                          (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 6,
                            color: totalGradient.colors.first,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearTotal(BuildContext context, String label, double value, Color color) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 4),
        // Сокращённый формат (K/M), чтобы миллионы помещались в блок.
        Text(
          formatNumber(value),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart({
    required BuildContext context,
    required ReportData data,
    required List<MonthIncomeExpense> monthData,
    required String title,
    IconData? titleIcon,
    required List<Legend> legends,
    required Color incomeColor,
    required Color expenseColor,
    bool showBudget = false,
    Color? budgetColor,
    String emptyMessage = 'Нет данных за период',
  }) {
    // ✅ Адаптивные деления по вертикали
    final bool hasData = monthData.any(
      (MonthIncomeExpense m) =>
          m.income > 0 || m.expense > 0 || m.budget > 0,
    );
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          // Пустое состояние: цвет темы (поддержка тёмного оформления).
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              emptyMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ),
      );
    }
    final maxIncome = monthData
        .map((e) => e.income)
        .reduce((a, b) => a > b ? a : b);
    final maxExpense = monthData
        .map((e) => e.expense)
        .reduce((a, b) => a > b ? a : b);
    final maxBudget = showBudget
        ? monthData.map((e) => e.budget).reduce((a, b) => a > b ? a : b)
        : 0.0;
    double maxValue =
        (maxIncome > maxExpense ? maxIncome : maxExpense) * 1.2;
    if (maxBudget > maxValue) maxValue = maxBudget * 1.2;
    final interval = _calculateNiceInterval(maxValue);

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (titleIcon != null) ...<Widget>[
                    Icon(
                      titleIcon,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '12 месяцев',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LegendsListWidget(legends: legends),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 2.2,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.start,
                maxY: maxValue, // ✅ Адаптивный максимум
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: interval, // ✅ Адаптивный интервал
                      getTitlesWidget:
                          (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              formatNumber(value),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        final int monthIndex = value.toInt();
                        if (monthIndex >= 0 && monthIndex < monthData.length) {
                          final displayText =
                              monthData[monthIndex].month == '01'
                                  ? '${monthData[monthIndex].month}.${monthData[monthIndex].year}'
                                  : monthData[monthIndex].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              displayText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval, // ✅ Адаптивная сетка
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                ),
                barGroups: List.generate(12, (index) {
                  final monthDataItem = monthData[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: monthDataItem.income,
                        color: incomeColor,
                        width: showBudget ? 4 : 5,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                      BarChartRodData(
                        toY: monthDataItem.expense,
                        color: expenseColor,
                        width: showBudget ? 4 : 5,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                      if (showBudget)
                        BarChartRodData(
                          toY: monthDataItem.budget,
                          color: budgetColor ?? Colors.orange,
                          width: showBudget ? 4 : 5,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Хелпер для красивых интервалов
  double _calculateNiceInterval(double maxValue) {
    if (maxValue <= 100000) return 20000.0;
    if (maxValue <= 500000) return 50000.0;
    if (maxValue <= 1000000) return 100000.0;
    if (maxValue <= 5000000) return 500000.0;
    return 1000000.0;
  }

  /// Разбивка реальных расходов по категориям: список со шкалами долей.
  Widget _buildCategoryExpenses(BuildContext context, ReportData data) {
    final List<CategoryExpense> categories = data.categoryExpenses;
    if (categories.isEmpty) {
      return _reportEmptyCard(context, 'Нет расходов с категориями за период');
    }

    const int maxRows = 10;
    final List<CategoryExpense> visible = categories.take(maxRows).toList();
    double restTotal = 0;
    double restShare = 0;
    if (categories.length > maxRows) {
      for (final CategoryExpense c in categories.skip(maxRows)) {
        restTotal += c.total;
        restShare += c.share;
      }
    }

    double grandTotal = 0;
    for (final CategoryExpense c in categories) {
      grandTotal += c.total;
    }

    return _reportCard(context: context, children: [
      _sectionTitle(
        context,
        Icons.category_outlined,
        'Расходы по категориям',
        hint: '12 месяцев',
      ),
      const SizedBox(height: 4),
      Text(
        'Всего: ${formatNumber(grandTotal)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 8),
      for (final CategoryExpense c in visible)
        _categoryRow(context, c.name, c.total, c.share),
      if (categories.length > maxRows)
        _categoryRow(context, 'Остальные', restTotal, restShare),
    ]);
  }

  Widget _categoryRow(BuildContext context, String name, double total, double share) {
    final Color color = Colors.red.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatNumber(total),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${(share * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Account>(
          future: AccountRepository().get(accountId),
          builder: (BuildContext context, AsyncSnapshot<Account> snapshot) {
            final String accountName = snapshot.data?.name ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Отчёт'),
                if (accountName.isNotEmpty)
                  Text(
                    accountName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      body: BlocProvider(
        create: (context) => ReportBloc()..add(LoadReportEvent(accountId)),
        child: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            if (state is ReportInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReportLoaded) {
              return _buildContent(context, state.reportData);
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Ошибка загрузки отчёта'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.read<ReportBloc>().add(
                      LoadReportEvent(accountId),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ReportData data) {
    double yearIncome = 0;
    double yearExpense = 0;
    for (final MonthIncomeExpense m in data.incomeExpenseData) {
      yearIncome += m.income;
      yearExpense += m.expense;
    }
    double yearBudget = 0;
    for (final MonthIncomeExpense m in data.plannedData) {
      yearBudget += m.budget;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _yearTotal(context, 'Доход', yearIncome, Colors.green.shade600),
                _yearTotal(context, 'Расход', yearExpense, Colors.red.shade600),
                _yearTotal(context, 'Бюджет (план, переводы)', yearBudget, Colors.orange.shade700),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSummaryCards(context, data),
          const SizedBox(height: 24),
          _buildTotalLineChart(context, data),
          const SizedBox(height: 24),
          // ✅ Доход/Расход
          _buildBarChart(
            context: context,
            data: data,
            monthData: data.incomeExpenseData,
            title: 'Доход/Расход',
            titleIcon: Icons.paid_outlined,
            legends: [
              Legend('Доход', Colors.green.shade600),
              Legend('Расход', Colors.red.shade600),
            ],
            incomeColor: Colors.green.shade500,
            expenseColor: Colors.red.shade500,
          ),
          const SizedBox(height: 24),
          // ✅ Расходы по категориям
          _buildCategoryExpenses(context, data),
          const SizedBox(height: 24),
          // ✅ Накопительный итог по выбранной категории
          _CategoryCumulativeCard(data: data),
          const SizedBox(height: 24),
          // ✅ План
          _buildBarChart(
            context: context,
            data: data,
            monthData: data.plannedData,
            title: 'План',
            titleIcon: Icons.event_note_outlined,
            legends: [
              Legend('План доход', Colors.green.shade500.withOpacity(0.8)),
              Legend('План расход', Colors.red.shade500.withOpacity(0.8)),
              Legend('Бюджет (переводы)', Colors.orange.shade600),
            ],
            incomeColor: Colors.green.shade500.withOpacity(0.8),
            expenseColor: Colors.red.shade500.withOpacity(0.8),
            showBudget: true,
            budgetColor: Colors.orange.shade600,
            emptyMessage: 'Нет плановых событий',
          ),
        ],
      ),
    );
  }
}
/// Карточка «Накопительно»: линейный график накопленных расходов
/// выбранной категории за 12 месяцев окна отчёта.
class _CategoryCumulativeCard extends StatefulWidget {
  final ReportData data;

  const _CategoryCumulativeCard({required this.data});

  @override
  State<_CategoryCumulativeCard> createState() => _CategoryCumulativeCardState();
}

class _CategoryCumulativeCardState extends State<_CategoryCumulativeCard> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.data.categoryExpenses.isNotEmpty
        ? widget.data.categoryExpenses.first.name
        : null;
  }

  @override
  void didUpdateWidget(covariant _CategoryCumulativeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Отчёт перезагрузился — выбранная категория могла исчезнуть.
    if (_selected != null &&
        !widget.data.categoryExpenses
            .any((CategoryExpense c) => c.name == _selected)) {
      _selected = widget.data.categoryExpenses.isNotEmpty
          ? widget.data.categoryExpenses.first.name
          : null;
    }
  }

  CategoryExpense? get _category {
    final String? selected = _selected;
    if (selected == null) return null;
    for (final CategoryExpense c in widget.data.categoryExpenses) {
      if (c.name == selected) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final CategoryExpense? category = _category;
    if (category == null) {
      return _reportEmptyCard(context, 'Нет расходов с категориями за период');
    }

    final List<double> cumulative = <double>[];
    double sum = 0;
    for (final double value in category.monthly) {
      sum += value;
      cumulative.add(sum);
    }

    double maxValue = 0;
    for (final double value in cumulative) {
      if (value > maxValue) maxValue = value;
    }
    final double interval = _niceInterval(maxValue);

    final Color color = Colors.red.shade600;
    final List<MonthIncomeExpense> months = widget.data.incomeExpenseData;

    return _reportCard(
      context: context,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Накопительно',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Text(
              '12 месяцев',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selected,
              isExpanded: true,
              items: widget.data.categoryExpenses
                  .map<DropdownMenuItem<String>>(
                    (CategoryExpense c) => DropdownMenuItem<String>(
                      value: c.name,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) => setState(() => _selected = value),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Накоплено: ${formatNumber(category.total)}',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 2.2,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: interval,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        formatNumber(value),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final int monthIndex = value.toInt();
                      if (monthIndex < 0 || monthIndex >= months.length) {
                        return const SizedBox();
                      }
                      final MonthIncomeExpense m = months[monthIndex];
                      final String display =
                          m.month == '01' ? '${m.month}.${m.year}' : m.month;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          display,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItems: (touchedBarSpots) {
                    return touchedBarSpots.map((spot) {
                      return LineTooltipItem(
                        formatNumber(spot.y),
                        TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    cumulative.length,
                    (int i) => FlSpot(i.toDouble(), cumulative[i]),
                  ),
                  isCurved: false,
                  color: color,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter:
                        (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Интервал сетки под ~4 деления (1/2/5 × 10^n).
  double _niceInterval(double maxValue) {
    if (maxValue <= 0) return 1;
    final double rough = maxValue / 4;
    final double magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final double norm = rough / magnitude;
    final double step = norm <= 1
        ? 1.0
        : norm <= 2
        ? 2.0
        : norm <= 5
        ? 5.0
        : 10.0;
    return step * magnitude;
  }
}
