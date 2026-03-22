import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:investflow/feature/report/data/model/report_data.dart';
import 'package:investflow/feature/report/logic/bloc.dart';
import 'package:investflow/feature/report/logic/reportEvent.dart';
import 'package:investflow/feature/report/logic/reportState.dart';
import 'package:investflow/feature/report/presentation/widgets/legendWidget.dart';

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

  // Generate 12 months for the last year
  String formatMonth(int monthOffset) {
    final DateTime now = DateTime.now();
    final DateTime monthDate = DateTime(now.year, now.month - 11 + monthOffset);
    return "${monthDate.month.toString().padLeft(2, '0')}.${monthDate.year.toString().substring(2)}";
  }

  String formatNumber(double value) {
    if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(1) + 'M';
    } else if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildSummaryCards(ReportData data) {
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
  Widget _buildTotalLineChart(ReportData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📈 Общая сумма',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
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
                    color: Colors.white,
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
                        color: Colors.grey.shade200,
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
                                color: Colors.grey.shade600,
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
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
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
                          const TextStyle(
                            color: Colors.white,
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

  Widget _buildBarChart({
    required ReportData data,
    required List<MonthIncomeExpense> monthData,
    required String title,
    required List<Legend> legends,
    required Color incomeColor,
    required Color expenseColor,
  }) {
    // ✅ Адаптивные деления по вертикали
    final maxIncome = monthData
        .map((e) => e.income)
        .reduce((a, b) => a > b ? a : b);
    final maxExpense = monthData
        .map((e) => e.expense)
        .reduce((a, b) => a > b ? a : b);
    final maxValue = (maxIncome > maxExpense ? maxIncome : maxExpense) * 1.2;
    final interval = _calculateNiceInterval(maxValue);

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                '12 месяцев',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        final monthIndex = (value / 2).floor();
                        if (monthIndex >= 0 && monthIndex <= 11) {
                          final displayText =
                              monthData[monthIndex].month == '01'
                                  ? monthData[monthIndex].month +
                                      '.' +
                                      monthData[monthIndex].year
                                  : monthData[monthIndex].month;

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              displayText,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
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
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                ),
                barGroups: List.generate(12, (index) {
                  final monthDataItem = monthData[index];
                  return BarChartGroupData(
                    x: index * 2,
                    barRods: [
                      BarChartRodData(
                        toY: monthDataItem.income,
                        color: incomeColor,
                        width: 5,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                      BarChartRodData(
                        toY: monthDataItem.expense,
                        color: expenseColor,
                        width: 5,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчет')),
      body: BlocProvider(
        create: (context) => ReportBloc()..add(LoadReportEvent(accountId)),
        child: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            if (state is ReportInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReportLoaded) {
              return _buildContent(state.reportData);
            }
            return const Center(child: Text('Ошибка загрузки'));
          },
        ),
      ),
    );
  }

  Widget _buildContent(ReportData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(data),
          const SizedBox(height: 24),
          _buildTotalLineChart(data),
          const SizedBox(height: 24),
          // ✅ Доход/Расход
          _buildBarChart(
            data: data,
            monthData: data.incomeExpenseData,
            title: '💰 Доход/Расход',
            legends: [
              Legend('Доход', Colors.green.shade600),
              Legend('Расход', Colors.red.shade600),
            ],
            incomeColor: Colors.green.shade500,
            expenseColor: Colors.red.shade500,
          ),
          const SizedBox(height: 24),
          // ✅ План
          _buildBarChart(
            data: data,
            monthData: data.plannedData,
            title: '📋 План',
            legends: [
              Legend('План доход', Colors.green.shade500.withOpacity(0.8)),
              Legend('План расход', Colors.red.shade500.withOpacity(0.8)),
            ],
            incomeColor: Colors.green.shade500.withOpacity(0.8),
            expenseColor: Colors.red.shade500.withOpacity(0.8),
          ),
        ],
      ),
    );
  }
}