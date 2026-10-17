import 'package:flutter/material.dart';
import 'package:investflow/core/utils/toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:investflow/core/utils/formatCurrency.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/tools/domain/credit_schedule.dart';
import 'package:investflow/data/repository/currencyRepository.dart';
import 'package:investflow/feature/tools/domain/tool_valuation.dart';
import 'package:investflow/feature/tool_detail/tool_detail_bloc.dart';
import 'package:investflow/feature/tool_detail/tool_detail_event.dart';
import 'package:investflow/feature/tool_detail/tool_detail_state.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_models.dart';
import 'package:investflow/feature/tool_detail/data/tool_detail_repository.dart';
import 'package:investflow/feature/tool_detail/presentation/components/investment_form_sheet.dart';

/// Детальный экран инструмента: hero-блок (сумма, чипы валюты/типа) и
/// «наезжающий» лист с деталями, кнопками действий и плитками разделов
/// (активности, динамика, график платежей). Табов больше нет.
class ToolDetailScreen extends StatelessWidget {
  final String accountId;
  final String toolId;

  const ToolDetailScreen({
    super.key,
    required this.accountId,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ToolDetailBloc>(
      create: (_) => ToolDetailBloc()..add(LoadToolDetail(accountId, toolId)),
      child: Scaffold(
        appBar: AppBar(
          // Заголовок — название тула (после загрузки).
          title: BlocBuilder<ToolDetailBloc, ToolDetailState>(
            builder: (BuildContext context, ToolDetailState state) {
              final String name =
                  state is ToolDetailLoaded ? state.tool.name : toolId;
              return Text(name, overflow: TextOverflow.ellipsis);
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0,
        ),
        body: BlocBuilder<ToolDetailBloc, ToolDetailState>(
          builder: (context, state) {
            if (state is ToolDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ToolDetailError) {
              return Center(
                child: Text('Error loading tool: ${state.message}'),
              );
            }
            if (state is ToolDetailLoaded) {
              return _buildAssetDetail(state.tool, context);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ─────────────────────────── HERO ───────────────────────────

  /// Верхний блок: градиент, чипы валюты/типа, общая сумма.
  Widget _buildHero(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isForeignMoney = tool.type == 'MONEY' && tool.ticker != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colorScheme.primaryContainer, colorScheme.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (tool.ticker != null)
                _chip(
                  tool.ticker!,
                  color: colorScheme.primary,
                  textColor: colorScheme.onPrimary,
                ),
              _chip(
                _typeDisplayName(tool.type),
                color: colorScheme.secondaryContainer,
                textColor: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isForeignMoney
                ? '${_formatCryptoQuantity(tool.quantity)} ${tool.ticker}'
                : formatCurrency(tool.currentValue),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (isForeignMoney) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '≈ ${formatCurrency(tool.currentValue)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
          if (tool.percentageChange != 0) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '${tool.percentageChange >= 0 ? '+' : ''}${tool.percentageChange.toStringAsFixed(2)}%',
              style: TextStyle(
                color: tool.percentageChange >= 0
                    ? Colors.green
                    : colorScheme.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, {required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─────────────────────── ЛИСТ С СЕКЦИЯМИ ───────────────────────

  Widget _buildAssetDetail(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        _buildHero(tool, context),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            transform: Matrix4.translationValues(0, -24, 0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSheetSections(tool, context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSheetSections(
    ToolDetailDisplay tool,
    BuildContext context,
  ) {
    switch (tool.type) {
      case 'MONEY':
        return _moneySections(tool, context);
      case 'STOCK':
      case 'STOCKS':
        return _securitiesSections(tool, context, ToolType.stocks);
      case 'BOND':
      case 'BONDS':
        return _bondSections(tool, context);
      case 'CRYPTOCURRENCY':
      case 'CRYPTO':
        return _securitiesSections(tool, context, ToolType.cryptocurrency);
      case 'DEPOSIT':
        return _depositSections(tool, context);
      case 'CREDIT':
        return _creditSections(tool, context);
      case 'OTHER':
        return _otherSections(tool, context);
      default:
        return _genericSections(tool, context);
    }
  }

  // ── MONEY ──

  List<Widget> _moneySections(ToolDetailDisplay tool, BuildContext context) {
    return <Widget>[
      _sectionTitle(context, 'Детали'),
      _detailsCard(<Widget>[
        _infoRow('Тип', 'Деньги', context),
        if (tool.ticker != null) _infoRow('Валюта', tool.ticker!, context),
        _infoRow(
          'Количество',
          '${_formatCryptoQuantity(tool.quantity)} ${tool.ticker ?? ''}'.trim(),
          context,
        ),
        _infoRow('Эквивалент', formatCurrency(tool.currentValue), context),
      ], context),
      _sectionTitle(context, 'Действия'),
      FilledButton.icon(
        onPressed: () => _showCloseMoneySheet(context, tool),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        icon: const Icon(Icons.currency_exchange, size: 20),
        label: const Text('Перевести на другой тул'),
      ),
      const SizedBox(height: 20),
      ..._tilesSection(tool, context, <Widget>[_activitiesTile(context, tool)]),
    ];
  }

  // ── STOCKS / CRYPTO ──

  List<Widget> _securitiesSections(
    ToolDetailDisplay tool,
    BuildContext context,
    ToolType type,
  ) {
    final bool isCrypto = type == ToolType.cryptocurrency;
    return <Widget>[
      _sectionTitle(context, 'Позиция'),
      _detailsCard(<Widget>[
        _infoRow(
          'Количество',
          '${_formatCryptoQuantity(tool.quantity)} ${tool.ticker ?? ''}'.trim(),
          context,
        ),
        if (tool.quantity.abs() > 0)
          _infoRow(
            'Цена за единицу',
            formatCurrency(tool.currentValue / tool.quantity.abs()),
            context,
          ),
        _infoRow(
          'Стоимость позиции',
          formatCurrency(tool.currentValue),
          context,
        ),
      ], context),
      _sectionTitle(context, 'Действия'),
      Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showInvestmentFormSheet(
                context,
                accountId: tool.accountId,
                toolId: tool.id,
                investmentType: type,
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
                investmentType: type,
                operationType: InvestmentOperationType.sell,
                presetTicker: tool.ticker,
                presetName: tool.name,
              ),
              icon: const Icon(Icons.sell),
              label: const Text('Продать'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ..._tilesSection(
        tool,
        context,
        <Widget>[
          _activitiesTile(context, tool),
          if (!isCrypto)
            _tile(
              context,
              icon: Icons.insights_outlined,
              label: 'Динамика',
              onTap: () {},
            ),
        ],
      ),
      // Мок-график как фактура (только акции).
      if (!isCrypto) ...<Widget>[
        _sectionTitle(context, 'Динамика'),
        _mockChartCard(context),
      ],
    ];
  }

  // ── BONDS ──

  List<Widget> _bondSections(ToolDetailDisplay tool, BuildContext context) {
    return <Widget>[
      _sectionTitle(context, 'Детали'),
      _detailsCard(<Widget>[
        _infoRow(
          'Количество',
          '${_formatCryptoQuantity(tool.quantity)} ${tool.ticker ?? ''}'.trim(),
          context,
        ),
        if (tool.quantity.abs() > 0)
          _infoRow(
            'Цена за единицу',
            formatCurrency(tool.currentValue / tool.quantity.abs()),
            context,
          ),
        if (tool.faceValue != null)
          _infoRow('Номинал', formatCurrency(tool.faceValue!), context),
        if (tool.interestRate != null)
          _infoRow(
            'Ставка купона',
            '${(tool.interestRate! * 100).toStringAsFixed(2)}%',
            context,
          ),
        if (tool.endDate != null)
          _infoRow(
            'Погашение',
            DateFormat('dd.MM.yyyy').format(tool.endDate!),
            context,
          ),
      ], context),
      _sectionTitle(context, 'Действия'),
      Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showInvestmentFormSheet(
                context,
                accountId: tool.accountId,
                toolId: tool.id,
                investmentType: ToolType.bonds,
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
                investmentType: ToolType.bonds,
                operationType: InvestmentOperationType.sell,
                presetTicker: tool.ticker,
                presetName: tool.name,
              ),
              icon: const Icon(Icons.sell),
              label: const Text('Продать'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ..._tilesSection(tool, context, <Widget>[_activitiesTile(context, tool)]),
      if (tool.faceValue != null && tool.interestRate != null) ...<Widget>[
        _sectionTitle(context, 'Выплаты'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                _cashFlowRow(
                  context,
                  date: '—',
                  amount:
                      '${(tool.faceValue! * tool.interestRate! / 2).toStringAsFixed(2)} ₽',
                  type: 'Купон',
                ),
                const SizedBox(height: 12),
                _cashFlowRow(
                  context,
                  date: '—',
                  amount:
                      '${(tool.faceValue! + tool.faceValue! * tool.interestRate! / 2).toStringAsFixed(2)} ₽',
                  type: 'Купон + номинал',
                  isFinal: true,
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  // ── DEPOSIT ──

  List<Widget> _depositSections(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final DateTime start = tool.startDate ?? now;
    final DateTime? end = tool.endDate;
    final double accrued = depositValue(
      principal: tool.currentValue,
      annualRate: tool.interestRate ?? 0,
      startDate: start,
      endDate: end,
      asOf: now,
    );
    final double accruedOnly = accrued - tool.currentValue;
    return <Widget>[
      _sectionTitle(context, 'Детали'),
      _detailsCard(<Widget>[
        _infoRow('Стоимость с процентами', formatCurrency(accrued), context),
        _infoRow('Накоплено процентов', formatCurrency(accruedOnly), context),
        _infoRow(
          'Ставка',
          '${(tool.interestRate ?? 0).toStringAsFixed(2)}%',
          context,
        ),
        if (tool.startDate != null)
          _infoRow(
            'Начало',
            DateFormat('dd.MM.yyyy').format(tool.startDate!),
            context,
          ),
        if (tool.endDate != null)
          _infoRow(
            'Конец срока',
            DateFormat('dd.MM.yyyy').format(tool.endDate!),
            context,
          ),
        if (tool.payoutType != null)
          _infoRow(
            'Выплата процентов',
            _payoutTypeName(PayoutType.values.byName(tool.payoutType!)),
            context,
          ),
      ], context),
      _sectionTitle(context, 'Действия'),
      ElevatedButton.icon(
        onPressed: () => _confirmCloseDeposit(context, tool),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        icon: const Icon(Icons.delete_outline, size: 20),
        label: const Text('Закрыть депозит'),
      ),
      const SizedBox(height: 20),
      ..._tilesSection(tool, context, <Widget>[_activitiesTile(context, tool)]),
    ];
  }

  // ── CREDIT ──

  List<Widget> _creditSections(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double debt = tool.currentValue.abs();
    final CreditPaymentType? paymentType = tool.creditPaymentType == null
        ? null
        : CreditPaymentType.values.byName(tool.creditPaymentType!);
    return <Widget>[
      _sectionTitle(context, 'Детали'),
      _detailsCard(<Widget>[
        _infoRow('Текущий долг', formatCurrency(debt), context),
        _infoRow(
          'Ставка',
          '${(tool.interestRate ?? 0).toStringAsFixed(2)}%',
          context,
        ),
        if (tool.loanStartDate != null)
          _infoRow(
            'Начало кредита',
            DateFormat('dd.MM.yyyy').format(tool.loanStartDate!),
            context,
          ),
        if (tool.loanTermMonths != null)
          _infoRow('Срок', '${tool.loanTermMonths} мес.', context),
        if (tool.paymentDayOfMonth != null)
          _infoRow('День платежа', '${tool.paymentDayOfMonth}', context),
        if (paymentType != null)
          _infoRow(
            'Тип платежей',
            paymentType == CreditPaymentType.annuity
                ? 'Аннуитетный'
                : 'Дифференцированный',
            context,
          ),
      ], context),
      _sectionTitle(context, 'Действия'),
      ElevatedButton.icon(
        onPressed: () => _confirmCloseCredit(context, tool),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        icon: const Icon(Icons.delete_outline, size: 20),
        label: const Text('Погасить кредит'),
      ),
      const SizedBox(height: 20),
      ..._tilesSection(
        tool,
        context,
        <Widget>[
          _activitiesTile(context, tool),
          _tile(
            context,
            icon: Icons.calendar_month_outlined,
            label: 'График платежей',
            onTap: () => _openCreditSchedule(context, tool),
          ),
        ],
      ),
    ];
  }

  // ── OTHER ──

  List<Widget> _otherSections(ToolDetailDisplay tool, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextEditingController valueController = TextEditingController(
      text: tool.currentValue.toStringAsFixed(2),
    );
    return <Widget>[
      _sectionTitle(context, 'Детали'),
      _detailsCard(<Widget>[
        _infoRow('Тип', 'Прочее', context),
        _infoRow(
          'Текущая стоимость',
          formatCurrency(tool.currentValue),
          context,
        ),
      ], context),
      _sectionTitle(context, 'Действия'),
      Row(
        children: <Widget>[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _revalueOtherTool(context, tool, valueController),
              icon: const Icon(Icons.update, size: 20),
              label: const Text('Переоценить'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _sellOtherTool(context, tool),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              icon: const Icon(Icons.sell_outlined, size: 20),
              label: const Text('Продать'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _sectionTitle(context, 'Переоценка'),
      TextFormField(
        controller: valueController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Новая стоимость (RUB)',
          prefixIcon: Icon(Icons.attach_money),
        ),
      ),
      const SizedBox(height: 20),
      ..._tilesSection(tool, context, <Widget>[_activitiesTile(context, tool)]),
    ];
  }

  // ── GENERIC ──

  List<Widget> _genericSections(ToolDetailDisplay tool, BuildContext context) {
    return <Widget>[
      _sectionTitle(context, 'Детали'),
      _detailsCard(<Widget>[
        _infoRow('Тип', _typeDisplayName(tool.type), context),
        _infoRow(
          'Количество',
          '${_formatCryptoQuantity(tool.quantity)} ${tool.ticker ?? ''}'.trim(),
          context,
        ),
        _infoRow(
          'Текущая стоимость',
          formatCurrency(tool.currentValue),
          context,
        ),
      ], context),
      const SizedBox(height: 20),
      ..._tilesSection(tool, context, <Widget>[_activitiesTile(context, tool)]),
    ];
  }

  // ─────────────────────── СЕКЦИИ-ХЕЛПЕРЫ ───────────────────────

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _detailsCard(List<Widget> rows, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  /// Секция плиток: заголовок + сетка 2 колонки.
  List<Widget> _tilesSection(
    ToolDetailDisplay tool,
    BuildContext context,
    List<Widget> tiles,
  ) {
    return <Widget>[
      _sectionTitle(context, 'Разделы'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: tiles,
      ),
    ];
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activitiesTile(BuildContext context, ToolDetailDisplay tool) {
    return _tile(
      context,
      icon: Icons.receipt_long_outlined,
      label: 'Активности',
      onTap: () => _openActivities(context, tool),
    );
  }

  // ─────────────────────── ДИНАМИКА (мок) ───────────────────────

  Widget _mockChartCard(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 160,
              child: CustomPaint(size: Size.infinite, painter: _ChartPainter()),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _periodButton(context, '1D', true),
                _periodButton(context, '1W', false),
                _periodButton(context, '1M', false),
                _periodButton(context, '3M', false),
                _periodButton(context, '1Y', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodButton(BuildContext context, String period, bool isActive) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isActive
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ─────────────────────── ПЕРЕХОДЫ ───────────────────────

  void _openActivities(BuildContext context, ToolDetailDisplay tool) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ToolActivitiesScreen(tool: tool),
      ),
    );
  }

  // ─────────────────────── ДЕЙСТВИЯ ───────────────────────

  Future<void> _revalueOtherTool(
    BuildContext context,
    ToolDetailDisplay tool,
    TextEditingController valueController,
  ) async {
    final double? newValue = double.tryParse(
      valueController.text.replaceAll(',', '.'),
    );
    if (newValue == null || newValue <= 0) {
      Toast.show(context, 'Введите положительную стоимость');
      return;
    }
    final double delta = await ToolDetailRepository().revalueOtherTool(
      toolId: tool.id,
      newValue: newValue,
    );
    if (context.mounted) {
      Toast.show(
        context,
        delta >= 0
            ? 'Переоценка: +${delta.toStringAsFixed(2)} ₽'
            : 'Переоценка: ${delta.toStringAsFixed(2)} ₽',
      );
      context.read<ToolDetailBloc>().add(
        LoadToolDetail(tool.accountId, tool.id),
      );
    }
  }

  Future<void> _sellOtherTool(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Продажа актива'),
          content: Text(
            'Актив «${tool.name}» будет продан за '
            '${tool.currentValue.abs().toStringAsFixed(2)} ₽, деньги будут '
            'зачислены на money-тул счёта. Продолжить?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Продать'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final double price = await ToolDetailRepository().sellOtherTool(
        toolId: tool.id,
        toolName: tool.name,
        accountId: tool.accountId,
      );
      Toast.show(context, 'Актив продан: +${price.toStringAsFixed(2)} ₽ в деньги');
      Navigator.of(context).pop();
    } catch (e) {
      Toast.show(context, 'Не удалось продать актив: $e');
    }
  }

  Future<void> _confirmCloseDeposit(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Закрытие депозита'),
          content: Text(
            'Депозит «${tool.name}» будет закрыт, а вся сумма с процентами '
            'переведена в деньги счёта. Продолжить?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Закрыть депозит'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final double payout =
          await ToolDetailRepository().closeDepositAndTransferToMoney(
        depositToolId: tool.id,
        depositName: tool.name,
        accountId: tool.accountId,
        principal: tool.currentValue,
        interestRate: tool.interestRate ?? 0,
        startDate: tool.startDate ?? DateTime.now(),
        endDate: tool.endDate,
      );
      Toast.show(
        context,
        'Депозит закрыт: ${formatCurrency(payout)} зачислено в деньги счёта',
      );
      Navigator.of(context).pop();
    } catch (e) {
      Toast.show(context, 'Не удалось закрыть депозит: $e');
    }
  }

  Future<void> _confirmCloseCredit(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Закрытие кредита'),
          content: Text(
            'Кредит «${tool.name}» будет закрыт: остаток долга '
            '${tool.currentValue.abs().toStringAsFixed(2)} ₽ будет списан с '
            'денежного тула счёта. Продолжить?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Закрыть кредит'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final double paid = await ToolDetailRepository()
          .closeCreditAndRemoveSchedule(
        creditToolId: tool.id,
        creditName: tool.name,
        accountId: tool.accountId,
      );
      Toast.show(context, 'Кредит закрыт: погашено ${paid.toStringAsFixed(2)} ₽');
      Navigator.of(context).pop();
    } catch (e) {
      Toast.show(context, 'Не удалось закрыть кредит: $e');
    }
  }

  Future<void> _showCloseMoneySheet(
    BuildContext context,
    ToolDetailDisplay tool,
  ) async {
    final List<Map<String, Object?>> currencies = await CurrencyRepository()
        .getList();
    final List<Tool> moneyTools = await ToolDetailRepository()
        .getAccountMoneyTools(tool.accountId, excludeToolId: tool.id);
    if (!context.mounted) return;
    if (moneyTools.isEmpty) {
      Toast.show(context, 'Нет другого money-тула для перевода');
      return;
    }

    final double impliedRate = tool.quantity.abs() > 0
        ? tool.currentValue.abs() / tool.quantity.abs()
        : 0;
    final double savedRate = await CurrencyRepository().getRate(
      tool.ticker ?? '',
    );
    final double defaultRate = savedRate > 0 ? savedRate : impliedRate;

    final TextEditingController rateController = TextEditingController(
      text: defaultRate.toStringAsFixed(4),
    );
    String? targetToolId = moneyTools.first.id;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Перевод средств'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Весь остаток тула «${tool.name}» будет переведён на '
                    'выбранный тул, а тул закроется.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: targetToolId,
                    decoration: const InputDecoration(
                      labelText: 'Куда перевести',
                    ),
                    items: moneyTools
                        .map(
                          (Tool t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text('${t.name} (${t.id.substring(0, 8)})'),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) =>
                        setDialogState(() => targetToolId = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Курс обмена',
                      helperText: 'RUB за единицу валюты',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Перевести'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || targetToolId == null || !context.mounted) return;

    try {
      final double rate = double.tryParse(
        rateController.text.replaceAll(',', '.'),
      )!;
      final double rubValue = tool.currentValue.abs();
      final double transferred =
          await ToolDetailRepository().closeMoneyToolAndTransfer(
        toolId: tool.id,
        toolName: tool.name,
        accountId: tool.accountId,
        targetToolId: targetToolId!,
        quantityInCurrency: tool.quantity.abs(),
        rate: rate,
        rubValue: rubValue,
        closeName: 'Обмен «${tool.name}» по курсу ${rate.toStringAsFixed(2)}',
      );
      Toast.show(
        context,
        'Тул закрыт: ${transferred.toStringAsFixed(2)} ₽ переведено',
      );
      Navigator.of(context).pop();
    } catch (e) {
      Toast.show(context, 'Не удалось закрыть тул: $e');
    }
  }

  // ─────────────────── ГРАФИК ПЛАТЕЖЕЙ (экран) ───────────────────

  void _openCreditSchedule(BuildContext context, ToolDetailDisplay tool) {
    final CreditPaymentType paymentType =
        tool.creditPaymentType == null
            ? CreditPaymentType.annuity
            : CreditPaymentType.values.byName(tool.creditPaymentType!);
    final int term = tool.loanTermMonths ?? 0;
    final double debt = tool.currentValue.abs();
    final double rate = tool.interestRate ?? 0;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: const Text('График платежей')),
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('№')),
                  DataColumn(label: Text('Платёж')),
                  DataColumn(label: Text('Проценты')),
                  DataColumn(label: Text('Тело')),
                ],
                rows: <DataRow>[
                  for (int n = 1; n <= term; n++)
                    DataRow(
                      cells: <DataCell>[
                        DataCell(Text('$n')),
                        DataCell(
                          Text(
                            formatCurrency(
                              creditPaymentSplit(
                                paymentType: paymentType,
                                loanAmount: debt,
                                annualRate: rate,
                                termMonths: term,
                                paymentNumber: n,
                              ).payment,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            formatCurrency(
                              creditPaymentSplit(
                                paymentType: paymentType,
                                loanAmount: debt,
                                annualRate: rate,
                                termMonths: term,
                                paymentNumber: n,
                              ).interest,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            formatCurrency(
                              creditPaymentSplit(
                                paymentType: paymentType,
                                loanAmount: debt,
                                annualRate: rate,
                                termMonths: term,
                                paymentNumber: n,
                              ).principal,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────── ХЕЛПЕРЫ ───────────────────────

  String _typeDisplayName(String type) {
    return switch (type.toUpperCase()) {
      'MONEY' => 'Деньги',
      'DEPOSIT' => 'Депозит',
      'CREDIT' => 'Кредит',
      'STOCK' || 'STOCKS' => 'Акции',
      'BOND' || 'BONDS' => 'Облигации',
      'CRYPTOCURRENCY' => 'Криптовалюта',
      'OTHER' => 'Прочее',
      _ => type,
    };
  }

  Widget _cashFlowRow(
    BuildContext context, {
    required String date,
    required String amount,
    required String type,
    bool isFinal = false,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 80,
          child: Text(
            date,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            type,
            style: TextStyle(
              fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFinal
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Количество с точностью до 10 знаков после запятой,
  /// хвостовые нули обрезаются (для криптовалют).
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

  String _payoutTypeName(PayoutType type) {
    return switch (type) {
      PayoutType.atEndOfTerm => 'В конце срока',
      PayoutType.monthly => 'Ежемесячно',
      PayoutType.monthlyToWithdrawalAccount => 'Ежемесячно на счёт списания',
    };
  }
}

/// Экран активностей тула: список операций (перенос из вкладки «Операции»).
class ToolActivitiesScreen extends StatelessWidget {
  final ToolDetailDisplay tool;

  const ToolActivitiesScreen({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Активности · ${tool.name}')),
      body: FutureBuilder<List<Activity>>(
        future: ToolDetailRepository().getActivitiesForTool(tool.id),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<Activity>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final List<Activity> activities = snapshot.data ?? <Activity>[];
          if (activities.isEmpty) {
            return const Center(child: Text('Операций пока нет'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (BuildContext context, int index) {
              final Activity activity = activities[index];
              final bool isAdd = activity.type == ActivityType.add;
              // Маркер прибыль/убыток (quantity = 0) несёт сумму в price.
              final double value = activity.quantity == 0
                  ? activity.price
                  : activity.price * activity.quantity;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isAdd ? Icons.add_circle : Icons.remove_circle,
                  color: isAdd ? colorScheme.primary : colorScheme.error,
                ),
                title: Text(
                  activity.name ?? (isAdd ? 'Пополнение' : 'Списание'),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DateFormat('dd.MM.yyyy').format(activity.createAt),
                ),
                trailing: Text(
                  '${isAdd ? '+' : '-'}${formatCurrency(value)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isAdd ? colorScheme.primary : colorScheme.error,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Мок-график динамики (фактура для акций).
class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.green;

    final Path path = Path();
    const int points = 50;
    final double stepX = size.width / (points - 1);

    for (int i = 0; i < points; i++) {
      final double x = i * stepX;
      final double y = size.height / 2 + (i % 10 - 5) * 10.0;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.withValues(alpha: 0.1);
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
