import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:investflow/data/models/activity.dart';
import 'package:investflow/data/models/tool.dart';
import 'package:investflow/data/repository/activityRepository.dart';
import 'package:investflow/data/repository/toolRepository.dart';
import 'package:investflow/feature/account/data/accountDataState.dart';
import 'package:investflow/feature/account/logic/accountBloc.dart';
import 'package:investflow/data/repository/settingsRepository.dart';
import 'package:investflow/data/source/cryptoSuggestSource.dart';
import 'package:investflow/data/source/moexSuggestSource.dart';
import 'package:investflow/data/models/scheduledTransaction.dart';
import 'package:investflow/core/utils/averageCost.dart';
import 'package:investflow/data/repository/scheduledTransactionRepository.dart';
import 'package:investflow/data/repository/currencyRepository.dart';
import 'package:uuid/uuid.dart';

enum InvestmentFormStatus { initial, loading, success, failure }

class InvestmentState {
  final InvestmentFormStatus formStatus;
  final String? errorMessage;
  final String? selectedTicker;
  final String? selectedName;
  final double? quantity;
  final double? price;
  final double? commission;
  final double? faceValue;
  final double? accruedCouponIncome;
  final DateTime selectedDate;
  final List<String> suggestions;
  /// Идёт запрос подсказок во внешний источник.
  final bool isSearching;
  /// Курс к дефолтной валюте по тикеру из внешнего источника.
  final Map<String, double> onlineRates;
  final InvestmentOperationType operationType;
  final ToolType investmentType;
  final String? accountId;

  InvestmentState({
    this.formStatus = InvestmentFormStatus.initial,
    this.errorMessage,
    this.selectedTicker,
    this.selectedName,
    this.quantity,
    this.price,
    this.commission,
    this.faceValue,
    this.accruedCouponIncome,
    DateTime? selectedDate,
    this.suggestions = const [],
    this.isSearching = false,
    this.onlineRates = const <String, double>{},
    required this.operationType,
    required this.investmentType,
    required this.accountId,
  }) : selectedDate = selectedDate ?? DateTime.now();

  InvestmentState copyWith({
    InvestmentFormStatus? formStatus,
    String? errorMessage,
    String? selectedTicker,
    String? selectedName,
    double? quantity,
    double? price,
    double? commission,
    double? faceValue,
    double? accruedCouponIncome,
    DateTime? selectedDate,
    List<String>? suggestions,
    bool? isSearching,
    Map<String, double>? onlineRates,
    InvestmentOperationType? operationType,
    ToolType? investmentType,
    String? accountId,
  }) {
    return InvestmentState(
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedTicker: selectedTicker ?? this.selectedTicker,
      selectedName: selectedName ?? this.selectedName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      commission: commission ?? this.commission,
      faceValue: faceValue ?? this.faceValue,
      accruedCouponIncome: accruedCouponIncome ?? this.accruedCouponIncome,
      selectedDate: selectedDate ?? this.selectedDate,
      suggestions: suggestions ?? this.suggestions,
      isSearching: isSearching ?? this.isSearching,
      onlineRates: onlineRates ?? this.onlineRates,
      operationType: operationType ?? this.operationType,
      investmentType: investmentType ?? this.investmentType,
      accountId: accountId ?? this.accountId,
    );
  }
}

class InvestmentCubit extends Cubit<InvestmentState> {
  final AccountData accountData;
  final String accountId;
  final InvestmentOperationType operationType;
  final ToolType investmentType;
  final AccountsBloc accountsBloc;
  /// Форма открыта с детального экрана: тикер/название уже известны.
  final String? presetTicker;
  final String? presetName;
  final CryptoSuggestSource _cryptoSource = CryptoSuggestSource();
  final MoexSuggestSource _moexSource = MoexSuggestSource();
  final Map<String, List<OnlineInstrument>> _onlineCache =
      <String, List<OnlineInstrument>>{};
  String? _vsCurrencyCache;
  Timer? _searchDebounce;
  String? _searchQuery;
  /// Счётчик поисков: ответы устаревших запросов отбрасываются.
  int _searchEpoch = 0;

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    _cryptoSource.dispose();
    _moexSource.dispose();
    return super.close();
  }

  InvestmentCubit({
    required this.accountData,
    required this.accountId,
    required this.operationType,
    required this.investmentType,
    required this.accountsBloc,
    this.presetTicker,
    this.presetName,
  }) : super(InvestmentState(
          selectedDate: DateTime.now(),
          operationType: operationType,
          investmentType: investmentType,
          accountId: accountId,
          selectedTicker: presetTicker,
          selectedName: presetName,
        )) {
    emit(state.copyWith(suggestions: getSuggestions()));
    // Пресет с детального экрана: полное количество при продаже
    // и актуальная цена (MOEX, иначе портфель) при покупке и продаже.
    if (presetTicker != null) {
      final String upper = presetTicker!.toUpperCase();
      if (operationType == InvestmentOperationType.sell) {
        final Iterable<ToolSummary> matches = accountData
            .getToolsForAccount(accountId)
            .where(
              (ToolSummary t) =>
                  t.type == investmentType &&
                  (t.ticker ?? '').toUpperCase() == upper,
            );
        if (matches.isNotEmpty) {
          quantityChanged(_trimQuantity(matches.first.quantity));
        }
      }
      unawaited(_prefillPrice(upper));
    }
  }

  /// Цена по умолчанию: актуальная из внешнего источника, при недоступности —
  /// текущая цена из портфеля (стоимость / количество).
  Future<void> _prefillPrice(String ticker) async {
    double? price;
    if (investmentType == ToolType.stocks ||
        investmentType == ToolType.bonds) {
      try {
        final List<MoexInstrument> board = await _moexSource.search(
          ticker,
          bonds: investmentType == ToolType.bonds,
        );
        for (final MoexInstrument i in board) {
          if (i.ticker.toUpperCase() == ticker && (i.price ?? 0) > 0) {
            price = i.priceInRub()! * await _rubToDefault();
            break;
          }
        }
      } catch (_) {
        // Внешний источник недоступен — используем портфель.
      }
    }
    price ??= _impliedRate(ticker);
    if (price != null && price > 0 && state.price == null) {
      priceChanged(_fmtRate(price));
    }
    // Облигация: номинал и НКД из провайдера, если поля пустые.
    if (investmentType == ToolType.bonds) {
      final MoexInstrument? meta = _moexSource.meta(ticker);
      final double? face = meta?.faceValue;
      if (face != null && face > 0 && (state.faceValue ?? 0) <= 0) {
        faceValueChanged(_fmtRate(face));
      }
      final double? nkd = meta?.accruedInt;
      if (nkd != null && nkd > 0 && (state.accruedCouponIncome ?? 0) <= 0) {
        accruedCouponIncomeChanged(_fmtRate(nkd));
      }
    }
  }

  List<String> getSuggestions() {
    List<String> suggestions;
    if (operationType == InvestmentOperationType.sell) {
      suggestions = accountData
          .getToolsForAccount(accountId)
          .where((tool) =>
              tool.type == investmentType &&
              tool.ticker != null &&
              tool.quantity > 0)
          .map<String>((tool) => '${tool.ticker} - ${tool.name}')
          .toList();
    } else {
      // Для покупки справочник динамический: тула из БД этого счёта
      // (тикер, название). Цены добавляет внешний источник, приоритет у него.
      suggestions = accountData
          .getToolsForAccount(accountId)
          .where(
            (tool) =>
                tool.type == investmentType &&
                tool.ticker != null &&
                !tool.isClosed,
          )
          .map<String>((tool) => '${tool.ticker} - ${tool.name}')
          .toList();
    }
    suggestions.sort();
    return suggestions;
  }

  void tickerChanged(String ticker) {
    // Handle "TICKER - Name · курс VAL" format from suggestions
    String upper;
    String? name;
    if (ticker.contains(' - ')) {
      final List<String> parts = ticker.split(' - ');
      upper = parts[0].toUpperCase();
      name = parts.length > 1 ? parts[1].split(' · ').first.trim() : null;
    } else {
      upper = ticker.toUpperCase();
      // Имя берём из тулов БД, если такой тикер уже покупался.
      name = accountData
          .getToolsForAccount(accountId)
          .cast<ToolSummary?>()
          .firstWhere(
            (ToolSummary? t) =>
                t != null &&
                t.type == investmentType &&
                (t.ticker ?? '').toUpperCase() == upper,
            orElse: () => null,
          )
          ?.name;
    }
    // Refresh suggestions when ticker is cleared
    final List<String> suggestions;
    if (ticker.isEmpty) {
      suggestions = getSuggestions();
    } else if (!ticker.contains(' - ')) {
      // Ручной ввод: список закрывается и соберётся заново по запросу.
      suggestions = const <String>[];
    } else {
      suggestions = state.suggestions;
    }
    emit(state.copyWith(
      selectedTicker: upper,
      selectedName: name != null && name.isNotEmpty ? name : null,
      suggestions: suggestions,
    ));
    // Цена — прямо из строки подсказки «· 150 RUB»: надёжнее карты курсов,
    // которую могут перетереть параллельные запросы.
    double? price = () {
      final RegExpMatch? m = RegExp(
        r'·\s*([\d., ]+?)\s*[A-ZА-Я]{3}\s*$',
      ).firstMatch(ticker);
      if (m == null) return null;
      return double.tryParse(m.group(1)!.replaceAll(' ', '').replaceAll(',', '.'));
    }();
    if (price == null || price <= 0) {
      price = state.onlineRates[upper];
    }
    if (price != null && price > 0) {
      priceChanged(_fmtRate(price));
    }
    // Облигация: номинал и НКД из данных провайдера.
    if (investmentType == ToolType.bonds) {
      final MoexInstrument? meta = _moexSource.meta(upper);
      final double? face = meta?.faceValue;
      if (face != null && face > 0) {
        faceValueChanged(_fmtRate(face));
      }
      final double? nkd = meta?.accruedInt;
      if (nkd != null && nkd > 0) {
        accruedCouponIncomeChanged(_fmtRate(nkd));
      }
    }
    // При продаже подставляем полное количество тула.
    if (operationType == InvestmentOperationType.sell) {
      final Iterable<ToolSummary> matches = accountData
          .getToolsForAccount(accountId)
          .where(
            (ToolSummary t) =>
                t.type == investmentType &&
                (t.ticker ?? '').toUpperCase() == upper,
          );
      if (matches.isNotEmpty) {
        quantityChanged(_trimQuantity(matches.first.quantity));
      }
    }
    if (ticker.contains(' - ')) {
      // Подсказка выбрана: закрываем список и обновляем цены выбранного.
      emit(state.copyWith(suggestions: const <String>[]));
      unawaited(_applySelectedTickerExtras(upper));
    } else {
      _scheduleOnlineSearch(upper);
    }
  }

  /// После выбора подсказки: догрузить курсы и подставить цену,
  /// если она не была известна в момент выбора.
  Future<void> _applySelectedTickerExtras(String upper) async {
    await _loadOnlineSuggestions(upper);
    if (isClosed) return;
    final double? lateRate = state.onlineRates[upper];
    if (lateRate != null && lateRate > 0 && (state.price ?? 0) <= 0) {
      priceChanged(_fmtRate(lateRate));
    }
  }

  /// Поиск подсказок во внешнем источнике с дебаунсом
  /// (крипта — CoinGecko, акции/облигации — MOEX).
  void _scheduleOnlineSearch(String query) {
    if (operationType != InvestmentOperationType.buy || query.length < 2) {
      return;
    }
    _searchDebounce?.cancel();
    _searchQuery = query;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final int epoch = ++_searchEpoch;
      emit(state.copyWith(isSearching: true));
      await _loadOnlineSuggestions(_searchQuery ?? query, epoch);
      if (!isClosed && epoch == _searchEpoch) {
        emit(state.copyWith(isSearching: false));
      }
    });
  }

  /// Внешний источник + тула из БД; дубли убираются, побеждает внешний.
  /// Имена показываются сразу после поиска, цены догружаются следом.
  Future<void> _loadOnlineSuggestions(String query, [int? epoch]) async {
    epoch ??= ++_searchEpoch;
    if (investmentType == ToolType.stocks ||
        investmentType == ToolType.bonds) {
      await _loadMoexSuggestions(query, epoch);
      return;
    }
    final String vs = await _defaultCurrency();
    final String key = '${investmentType.name}:${query.toLowerCase()}';
    List<OnlineInstrument> online =
        _onlineCache[key] ?? await _cryptoSource.search(query);
    _onlineCache[key] = online;
    if (online.isEmpty) {
      final String q = query.toLowerCase();
      final List<String> matched = q.isEmpty
          ? getSuggestions()
          : getSuggestions()
                .where((String e) => e.toLowerCase().contains(q))
                .toList();
      final (List<String> hints, Map<String, double> rates) =
          _withImpliedRates(matched, vs);
      emit(state.copyWith(suggestions: hints, onlineRates: rates));
      _applySelectedTickerPrice();
      return;
    }

    // 1) Быстрый показ имён без курсов.
    _emitMerged(online, <String, double>{}, vs, query: query);

    // 2) Догрузка цен (для закэшированных не повторяется).
    if (online.any((OnlineInstrument i) => i.rate == null)) {
      final Map<String, double> rates = await _cryptoSource.fetchRates(
        online,
        vs,
      );
      for (final OnlineInstrument i in online) {
        final double? r = rates[i.id];
        if (r != null) {
          i.rate = r;
        }
      }
      _emitMerged(online, rates, vs, query: query);
    } else {
      _emitMerged(
        online,
        <String, double>{
          for (final OnlineInstrument i in online)
            if (i.rate != null) i.id: i.rate!,
        },
        vs,
        query: query,
      );
    }
  }

  /// Подсказки акций/облигаций из MOEX: борд кэшируется в источнике,
  /// поиск локальный. Курс = цена закрытия, конвертированная в дефолтную валюту.
  Future<void> _loadMoexSuggestions(String query, int epoch) async {
    final String vs = await _defaultCurrency();
    final double rubToDefault = await _rubToDefault();
    final List<MoexInstrument> online = await _moexSource.search(
      query,
      bonds: investmentType == ToolType.bonds,
    );
    if (epoch != _searchEpoch) {
      return; // ответ устарел: уже есть более новый запрос
    }
    final String q = query.toLowerCase();
    if (online.isEmpty) {
      // Провайдер ничего не нашёл: DB-подсказки с ценой из портфеля.
      final List<String> matched = getSuggestions()
          .where((String e) => e.toLowerCase().contains(q))
          .toList();
      final (List<String> hints, Map<String, double> rates) =
          _withImpliedRates(matched, vs);
      emit(state.copyWith(suggestions: hints, onlineRates: rates));
      _applySelectedTickerPrice();
      return;
    }
    // Котировка облигаций — % от номинала: полная цена = % × номинал.
    final Map<String, double> rates = <String, double>{
      for (final MoexInstrument i in online)
        if (i.priceInRub() != null && i.priceInRub()! > 0)
          i.ticker.toUpperCase(): i.priceInRub()! * rubToDefault,
    };
    final Set<String> onlineTickers = online
        .map((MoexInstrument i) => i.ticker.toUpperCase())
        .toSet();
    final List<String> dbEntries = getSuggestions()
        .where((String entry) {
          final String entryTicker = entry.split(' - ').first.toUpperCase();
          if (onlineTickers.contains(entryTicker)) {
            return false; // дубли: побеждает внешний источник
          }
          return entry.toLowerCase().contains(q);
        })
        .map<String>((String entry) => _withImpliedRate(entry, vs))
        .toList();
    final List<String> merged = <String>[
      ...online.map((MoexInstrument i) {
        final double? fullPrice = i.priceInRub();
        final String suffix =
            (fullPrice != null && fullPrice > 0)
                ? ' · ${_fmtRate(fullPrice * rubToDefault)} $vs'
                : '';
        return '${i.ticker} - ${i.name}$suffix';
      }),
      ...dbEntries,
    ];
    emit(state.copyWith(suggestions: merged, onlineRates: rates));
    // Дозаполнение цены выбранным курсом.
    final String? selected = state.selectedTicker;
    final double? selectedRate = selected != null ? rates[selected] : null;
    if (selectedRate != null && selectedRate > 0 && state.price == null) {
      priceChanged(_fmtRate(selectedRate));
    }
  }

  /// DB-подсказки с ценой из портфеля + карта курсов, чтобы при выборе
  /// подсказки цена подставилась в форму.
  (List<String>, Map<String, double>) _withImpliedRates(
    List<String> entries,
    String vs,
  ) {
    final Map<String, double> rates = <String, double>{};
    final List<String> result = entries.map<String>((String entry) {
      final String withRate = _withImpliedRate(entry, vs);
      final int sep = entry.indexOf(' - ');
      if (sep > 0) {
        final String ticker = entry.substring(0, sep).toUpperCase();
        final double? rate = _impliedRate(ticker);
        if (rate != null && rate > 0) {
          rates[ticker] = rate;
        }
      }
      return withRate;
    }).toList();
    return (result, rates);
  }

  /// Дозаполнить цену выбранного тикера, когда курсы доехали позже выбора.
  void _applySelectedTickerPrice() {
    final String? selected = state.selectedTicker;
    if (selected == null) return;
    final double? rate = state.onlineRates[selected];
    if (rate != null && rate > 0 && (state.price ?? 0) <= 0) {
  
      priceChanged(_fmtRate(rate));
    }
  }

  /// Курс дефолтной валюты к рублю (для перевода MOEX-цен).
  Future<double> _rubToDefault() async {
    final String def = await _defaultCurrency();
    if (def.toUpperCase() == 'RUB') return 1;
    final double r = await CurrencyRepository().getRate('RUB');
    return r > 0 ? r : 1;
  }

  /// Дописать БД-подсказке текущую цену инструмента, если она есть.
  String _withImpliedRate(String entry, String vs) {
    final int sep = entry.indexOf(' - ');
    if (sep < 0) return entry;
    if (entry.contains(' · ')) return entry;
    final String ticker = entry.substring(0, sep).toUpperCase();
    final double? rate = _impliedRate(ticker);
    final String suffix =
        (rate != null && rate > 0) ? ' · ${_fmtRate(rate)} $vs' : '';
    return '$entry$suffix';
  }

  Future<String> _defaultCurrency() async {
    _vsCurrencyCache ??= await SettingsRepository().getDefaultCurrency();
    return _vsCurrencyCache!;
  }

  /// Слияние внешних подсказок с тулами из БД и обновление состояния.
  void _emitMerged(
    List<OnlineInstrument> online,
    Map<String, double> freshRates,
    String vs, {
    String? query,
  }) {
    final Map<String, double> rates = <String, double>{
      for (final OnlineInstrument i in online)
        if (i.rate != null && i.rate! > 0) i.ticker.toUpperCase(): i.rate!,
    };
    final Set<String> onlineTickers = online
        .map((OnlineInstrument i) => i.ticker.toUpperCase())
        .toSet();
    // Единый формат «ТИКЕР - Название · курс»: тулам из БД курс —
    // текущая цена инструмента (стоимость / количество).
    final String q = query?.toLowerCase() ?? '';
    // Цены портфеля для DB-подсказок — чтобы при выборе подставлялись.
    final Map<String, double> dbRates = <String, double>{};
    final List<String> dbEntries = getSuggestions()
        .where((String entry) {
          final String entryTicker = entry.split(' - ').first.toUpperCase();
          if (onlineTickers.contains(entryTicker)) {
            return false; // дубли: побеждает внешний источник
          }
          if (q.isEmpty || entry.toLowerCase().contains(q)) {
            final double? rate = _impliedRate(entryTicker);
            if (rate != null && rate > 0) {
              dbRates[entryTicker] = rate;
            }
            return true;
          }
          return false;
        })
        .map<String>((String entry) {
          final int sep = entry.indexOf(' - ');
          if (sep < 0) return entry;
          final String ticker = entry.substring(0, sep).toUpperCase();
          final String name = entry.substring(sep + 3);
          final double? rate = _impliedRate(ticker);
          final String rateSuffix =
              (rate != null && rate > 0) ? ' · ${_fmtRate(rate)} $vs' : '';
          return '$ticker - $name$rateSuffix';
        })
        .toList();
    final List<String> merged = <String>[
      ...online.map((OnlineInstrument i) {
        final double r = i.rate ?? freshRates[i.id] ?? 0;
        final String rateSuffix = r > 0 ? ' · ${_fmtRate(r)} $vs' : '';
        return '${i.ticker} - ${i.name}$rateSuffix';
      }),
      ...dbEntries,
    ];
    emit(
      state.copyWith(
        suggestions: merged,
        onlineRates: <String, double>{...rates, ...dbRates},
      ),
    );
    // Дозаполнение цены выбранным курсом, если она ещё пуста.
    final String? selected = state.selectedTicker;
    final double? selectedRate = selected != null ? rates[selected] : null;
    if (selectedRate != null && selectedRate > 0 && state.price == null) {
      priceChanged(_fmtRate(selectedRate));
    }
  }

  // ─── Дивиденды и купоны через планировщик ───

  /// Создать запись планировщика (дивиденды/купоны), если данных нет — тихо выйти.
  Future<void> _ensureIncomeSchedule({
    required String toolId,
    required String ticker,
    required double qty,
    required ToolSummary? moneyTool,
  }) async {
    if (qty <= 0) return;
    final List<ScheduledTransaction> existing = await _schedulesFor(toolId);
    if (existing.isNotEmpty) return;

    if (investmentType == ToolType.stocks) {
      final ({double value, String dateIso})? div = await _moexSource
          .lastDividend(ticker);
      if (div == null) return;
      final DateTime divDate =
          DateTime.tryParse(div.dateIso) ?? DateTime.now();
      final DateTime now = DateTime.now();
      final DateTime first = divDate.isAfter(now)
          ? divDate
          : DateTime(divDate.year + 1, divDate.month, divDate.day);
      await ScheduledTransactionRepository().add(
        ScheduledTransaction(
          id: const Uuid().v7(),
          accountId: accountId,
          name: 'Дивиденды $ticker',
          amount: _round2(div.value * qty),
          type: 'income',
          category: 'Дивиденды',
          date: first,
          walletId: moneyTool?.id ?? accountId,
          recurrenceType: 'annually',
          nextExecutionDate: first,
          totalExecutions: 0,
          executedCount: 0,
          depositToolId: toolId,
        ),
      );
    } else if (investmentType == ToolType.bonds) {
      final MoexInstrument? meta = _moexSource.meta(ticker);
      if (meta == null ||
          meta.couponValue == null ||
          meta.couponValue! <= 0) {
        return;
      }
      final DateTime? nextCoupon = DateTime.tryParse(meta.nextCouponIso ?? '');
      if (nextCoupon == null) return;
      final int period = meta.couponPeriodDays ?? 182;
      final String recurrence =
          period <= 40
              ? 'monthly'
              : period <= 110
              ? 'quarterly'
              : period <= 220
              ? 'semiannual'
              : 'annually';
      await ScheduledTransactionRepository().add(
        ScheduledTransaction(
          id: const Uuid().v7(),
          accountId: accountId,
          name: 'Купон $ticker',
          amount: _round2(meta.couponValue! * qty),
          type: 'income',
          category: 'Купоны',
          date: nextCoupon,
          walletId: moneyTool?.id ?? accountId,
          recurrenceType: recurrence,
          nextExecutionDate: nextCoupon,
          totalExecutions: 0,
          executedCount: 0,
          depositToolId: toolId,
        ),
      );
    }
  }

  /// Пересчитать суммы планировщика пропорционально новому количеству.
  Future<void> _recalcIncomeSchedule(
    String toolId,
    double oldQty,
    double newQty,
  ) async {
    if (oldQty <= 0 || newQty <= 0) return;
    final List<ScheduledTransaction> existing = await _schedulesFor(toolId);
    for (final ScheduledTransaction st in existing) {
      final double perUnit = st.amount / oldQty;
      await ScheduledTransactionRepository().update(
        st.copyWith(amount: _round2(perUnit * newQty)),
      );
    }
  }

  Future<List<ScheduledTransaction>> _schedulesFor(String toolId) =>
      ScheduledTransactionRepository().getByDepositTool(toolId);

  double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// Количество без хвостовых нулей (до 10 знаков).
  String _trimQuantity(double v) {
    String s = v.toStringAsFixed(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  /// Текущая цена единицы инструмента из БД (стоимость / количество).
  double? _impliedRate(String ticker) {
    for (final ToolSummary t in accountData.getToolsForAccount(accountId)) {
      if (t.type == investmentType &&
          (t.ticker ?? '').toUpperCase() == ticker &&
          t.quantity > 0) {
        return t.currentValue / t.quantity;
      }
    }
    return null;
  }

  String _fmtRate(double v) {
    String s = v.toStringAsFixed(2);
    if (v >= 1000) {
      s = v.round().toString();
    }
    return s;
  }

  void nameChanged(String name) {
    emit(state.copyWith(selectedName: name));
  }

  void quantityChanged(String value) {
    final q = double.tryParse(value);
    emit(state.copyWith(quantity: q));
  }

  void priceChanged(String value) {
    final p = double.tryParse(value);
    emit(state.copyWith(price: p));
  }

  void commissionChanged(String value) {
    final c = value.trim().isEmpty ? 0.0 : double.tryParse(value);
    emit(state.copyWith(commission: c));
  }

  void faceValueChanged(String value) {
    final f = double.tryParse(value);
    emit(state.copyWith(faceValue: f));
  }

  void accruedCouponIncomeChanged(String value) {
    final a = double.tryParse(value);
    emit(state.copyWith(accruedCouponIncome: a));
  }

  void dateSelected(DateTime date) {
    emit(state.copyWith(selectedDate: date));
  }

  ToolSummary? _getDefaultMoneyToolForAccount() {
    final List<ToolSummary> moneyTools = accountData.getMoneyToolsForAccount(accountId);
    final ToolSummary? rurTool = moneyTools.cast<ToolSummary?>().firstWhere(
      (ToolSummary? tool) => tool != null && tool.ticker == 'RUB',
      orElse: () => null,
    );
    if (rurTool != null) {
      return rurTool;
    }
    return moneyTools.isNotEmpty ? moneyTools.first : null;
  }

  Future<void> submit() async {
    emit(state.copyWith(formStatus: InvestmentFormStatus.loading));

    final ticker = state.selectedTicker ?? '';
    final name = state.selectedName ?? '';
    final quantity = state.quantity;
    final price = state.price;
    final commission = state.commission ?? 0.0;
    final faceValue = state.faceValue;
    final accruedCouponIncome = state.accruedCouponIncome;
    final date = state.selectedDate;

    if (ticker.isEmpty || name.isEmpty || quantity == null || price == null || quantity <= 0 || price <= 0) {
      emit(state.copyWith(
        formStatus: InvestmentFormStatus.failure,
        errorMessage: 'Пожалуйста, заполните все обязательные поля корректно',
      ));
      return;
    }

    try {
      if (operationType == InvestmentOperationType.buy) {
        await _handleBuy(ticker, name, quantity, price, commission, faceValue, accruedCouponIncome, date);
      } else {
        await _handleSell(ticker, name, quantity, price, commission, accruedCouponIncome, date);
      }

      emit(state.copyWith(formStatus: InvestmentFormStatus.success));
    } catch (e) {
      emit(state.copyWith(
        formStatus: InvestmentFormStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<String> _handleBuy(
    String ticker,
    String name,
    double quantity,
    double price,
    double commission,
    double? faceValue,
    double? accruedCouponIncome,
    DateTime date,
  ) async {
    final moneyTool = _getDefaultMoneyToolForAccount();
    if (moneyTool == null) {
      throw Exception('No money tool found for account $accountId');
    }

    final instrumentCost = quantity * price;

    // Add Activity record for money tool change (money out)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: moneyTool.id,
        type: ActivityType.substract,
        createAt: date,
        quantity: instrumentCost,
        price: 1,
        currency: Currency.RUB,
        isTransmit: true, // внутренний обмен, не расход
        name: 'Buy $name (money out)',
      ),
    );

    // Add separate Activity record for commission
    if (commission > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: date,
          quantity: commission,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'Commission for $name',
        ),
      );
    }

    // Add Activity record for НКД (accrued coupon) when buying bonds
    if (investmentType == ToolType.bonds && accruedCouponIncome != null && accruedCouponIncome > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: date,
          // НКД в форме — на одну облигацию; списываем за всё количество.
          quantity: accruedCouponIncome * quantity,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'НКД for $name (buy)',
        ),
      );
    }

    ToolSummary? existingTool = accountData.getToolByTickerAndAccountId(ticker, accountId);
    // Verify type matches (getToolByTickerAndAccountId doesn't check type)
    if (existingTool != null && existingTool.type != investmentType) {
      existingTool = null;
    }
    if (existingTool != null) {
      // Create activity to increase the instrument position
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: existingTool.id,
          type: ActivityType.add,
          createAt: date,
          quantity: quantity,
          price: price,
          currency: Currency.RUB,
          isTransmit: true, // внутренний обмен, не доход
          name: 'Buy $name',
        ),
      );
      final double newQty = existingTool.quantity + quantity;
      await _recalcIncomeSchedule(existingTool.id, existingTool.quantity, newQty);
      await _ensureIncomeSchedule(
        toolId: existingTool.id,
        ticker: ticker,
        qty: newQty,
        moneyTool: moneyTool,
      );
      return existingTool.id;
    } else {
      final String newToolId = Uuid().v7();
      // Облигация: реальные номинал, годовая ставка купона и дата погашения
      // из данных MOEX (если биржа недоступна — поля остаются пустыми).
      double? faceValue;
      double? interestRate;
      DateTime? endDate;
      if (investmentType == ToolType.bonds) {
        final MoexInstrument? meta = _moexSource.meta(ticker);
        final MoexInstrument? bondMeta = _moexSource.meta(ticker);
        final double face = bondMeta?.faceValue ?? 0;
        if (face > 0) {
          faceValue = face;
        }
        final double coupon = bondMeta?.couponValue ?? 0;
        final int period = bondMeta?.couponPeriodDays ?? 0;
        if (coupon > 0 && period > 0 && faceValue != null) {
          final double annualCoupon = coupon * 365 / period;
          interestRate = annualCoupon / faceValue!;
        }
        final String? mat = bondMeta?.maturityIso;
        if (mat != null) {
          endDate = DateTime.tryParse(mat);
        }
      }
      await ToolRepository().insert(Tool(
        id: newToolId,
        name: name,
        accountId: accountId,
        type: investmentType.name,
        ticker: ticker,
        faceValue: faceValue,
        interestRate: interestRate,
        endDate: endDate,
      ));
      // Create activity to set the initial position
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: newToolId,
          type: ActivityType.add,
          createAt: date,
          quantity: quantity,
          price: price,
          currency: Currency.RUB,
          isTransmit: true, // внутренний обмен, не доход
          name: 'Buy $name',
        ),
      );
      await _ensureIncomeSchedule(
        toolId: newToolId,
        ticker: ticker,
        qty: quantity,
        moneyTool: moneyTool,
      );
      return newToolId;
    }
  }

  Future<String> _handleSell(
    String ticker,
    String name,
    double quantity,
    double price,
    double commission,
    double? accruedCouponIncome,
    DateTime date,
  ) async {
    final moneyTool = _getDefaultMoneyToolForAccount();
    if (moneyTool == null) {
      throw Exception('No money tool found for account $accountId');
    }

    ToolSummary? existingTool = accountData.getToolByTickerAndAccountId(ticker, accountId);
    // Verify type matches
    if (existingTool != null && existingTool.type != investmentType) {
      existingTool = null;
    }
    if (existingTool == null || existingTool.quantity < quantity) {
      throw Exception('Insufficient quantity of $ticker to sell');
    }

    // Add Activity record for money tool change (money in from sale)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: moneyTool.id,
        type: ActivityType.add,
        createAt: date,
        quantity: quantity * price,
        price: 1,
        currency: Currency.RUB,
        isTransmit: true, // внутренний обмен, не доход
        name: 'Sell $name (money in)',
      ),
    );

    // Add Activity record for НКД (accrued coupon) when selling bonds
    if (investmentType == ToolType.bonds && accruedCouponIncome != null && accruedCouponIncome > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.add,
          createAt: date,
          // НКД в форме — на одну облигацию; получаем за всё количество.
          quantity: accruedCouponIncome * quantity,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'НКД for $name (sell)',
        ),
      );
    }

    // Add separate Activity record for commission
    if (commission > 0) {
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: moneyTool.id,
          type: ActivityType.substract,
          createAt: date,
          quantity: commission,
          price: 1,
          currency: Currency.RUB,
          isTransmit: false,
          name: 'Commission for $name',
        ),
      );
    }

    // Средняя цена позиции из истории активити тула (до записи продажи) —
    // списание с инструмента идёт по себестоимости, чтобы реплей тула
    // показывал себестоимость остатка, а не накапливал прибыль в минус.
    final List<Activity> history = await ActivityRepository()
        .getActivityListByTool(existingTool.id);
    final AverageCostResult avg = computeAverageCost(history);
    final double costPrice = avg.avgCost > 0 ? avg.avgCost : price;

    // Create activity to reduce the instrument position (по себестоимости)
    await ActivityRepository().insert(
      Activity(
        id: Uuid().v7(),
        toolId: existingTool.id,
        type: ActivityType.substract,
        createAt: date,
        quantity: quantity,
        price: costPrice,
        currency: Currency.RUB,
        isTransmit: true, // внутренний обмен, не расход
        name: 'Sell $name',
      ),
    );

    // Реализованная прибыль/убыток — отдельная активити на туле-инструменте
    // (quantity 0 — на количество и балансы не влияет, сумма хранится в price).
    final double realized = (price - costPrice) * quantity;
    if (avg.hasBuyHistory && realized.abs() > 0.01) {
      final bool isGain = realized > 0;
      // Маркер на туле-инструменте: quantity 0 — на количество и балансы
      // не влияет, сумма хранится в price.
      await ActivityRepository().insert(
        Activity(
          id: Uuid().v7(),
          toolId: existingTool.id,
          type: isGain ? ActivityType.add : ActivityType.substract,
          createAt: date,
          quantity: 0,
          price: realized.abs(),
          currency: Currency.RUB,
          isTransmit: false,
          name: isGain
              ? '${Activity.investmentGainName} $name'
              : '${Activity.investmentLossName} $name',
        ),
      );
    }

    // Полная продажа: тул остаётся с количеством 0 (скрыт в списках),
    // план купонов/дивидендов удаляется — позиции нет.
    final double newQty = existingTool.quantity - quantity;
    if (newQty <= 0) {
      await ScheduledTransactionRepository().deleteByDepositTool(
        existingTool.id,
      );
    } else {
      await _recalcIncomeSchedule(existingTool.id, existingTool.quantity, newQty);
    }

    return existingTool.id;
  }
}
