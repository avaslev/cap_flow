import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Биржевой инструмент из внешнего источника (MOEX ISS).
class MoexInstrument {
  final String ticker; // SECID
  final String name; // SHORTNAME
  final double? price; // цена закрытия, RUB
  final double? couponValue; // купон, RUB на облигацию
  final String? nextCouponIso; // дата следующего купона YYYY-MM-DD
  final int? couponPeriodDays; // периодичность купона в днях
  final double? faceValue; // номинал, RUB
  final double? accruedInt; // НКД, RUB на облигацию
  final String? maturityIso; // дата погашения YYYY-MM-DD

  MoexInstrument({
    required this.ticker,
    required this.name,
    this.price,
    this.couponValue,
    this.nextCouponIso,
    this.couponPeriodDays,
    this.faceValue,
    this.accruedInt,
    this.maturityIso,
  });

  /// Полная цена в рублях: для облигаций котировка — % от номинала.
  double? priceInRub() {
    final double? p = price;
    if (p == null) return null;
    if (faceValue != null && faceValue! > 0) {
      return p / 100 * faceValue!;
    }
    return p;
  }

  /// Последний известный дивиденд: сумма на акцию и дата отсечки.
  ({double value, String dateIso})? dividend;
}

/// Внешний источник биржевых инструментов (MOEX ISS, без ключа).
/// Список борда грузится целиком и кэшируется в памяти — поиск локальный.
/// Любая сетевая ошибка — пустой результат (не критично).
class MoexSuggestSource {
  static final Map<String, ({List<MoexInstrument> items, DateTime at})>
  _boardCache = <String, ({List<MoexInstrument> items, DateTime at})>{};
  static final Map<String, MoexInstrument> _byTicker =
      <String, MoexInstrument>{};

  static const Duration _cacheTtl = Duration(minutes: 10);

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  /// Полный список бумаг борда (с кэшем на 10 минут).
  Future<List<MoexInstrument>> _board(String market, String board) async {
    final String key = '$market:$board';
    final cached = _boardCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.items;
    }
    try {
      final String columns = (market == 'bonds')
          ? 'SECID,SHORTNAME,PREVPRICE,COUPONVALUE,NEXTCOUPON,COUPONPERIOD,'
              'FACEVALUE,ACCRUEDINT,MATDATE'
          : 'SECID,SHORTNAME,PREVPRICE';
      final Uri uri = Uri.parse(
        'https://iss.moex.com/iss/engines/stock/markets/$market'
        '/boards/$board/securities.json'
        '?iss.meta=off&iss.only=securities&securities.columns=$columns',
      );
      final HttpClientRequest request = await _client.getUrl(uri);
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        return cached?.items ?? const <MoexInstrument>[];
      }
      final String raw = await response.transform(utf8.decoder).join().timeout(
        const Duration(seconds: 20),
      );
      final Map<String, dynamic> body =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, dynamic> sec = body['securities'] ?? const {};
      final List<dynamic> cols = (sec['columns'] as List?) ?? const [];
      final List<dynamic> rows = (sec['data'] as List?) ?? const [];
      T col<T>(List<dynamic> row, String name) {
        final int i = cols.indexOf(name);
        return (i >= 0 && i < row.length) ? row[i] as T : null as T;
      }

      final List<MoexInstrument> items = rows
          .whereType<List<dynamic>>()
          .map<MoexInstrument>(
            (List<dynamic> row) => MoexInstrument(
              ticker: col<String>(row, 'SECID') ?? '',
              name: col<String>(row, 'SHORTNAME') ?? '',
              price: (col<num?>(row, 'PREVPRICE'))?.toDouble(),
              couponValue:
                  market == 'bonds'
                      ? (col<num?>(row, 'COUPONVALUE'))?.toDouble()
                      : null,
              nextCouponIso:
                  market == 'bonds' ? col<String>(row, 'NEXTCOUPON') : null,
              couponPeriodDays:
                  market == 'bonds'
                      ? (col<num?>(row, 'COUPONPERIOD'))?.toInt()
                      : null,
              faceValue:
                  market == 'bonds'
                      ? (col<num?>(row, 'FACEVALUE'))?.toDouble()
                      : null,
              accruedInt:
                  market == 'bonds'
                      ? (col<num?>(row, 'ACCRUEDINT'))?.toDouble()
                      : null,
              maturityIso:
                  market == 'bonds' ? col<String>(row, 'MATDATE') : null,
            ),
          )
          .where((MoexInstrument i) => i.ticker.isNotEmpty)
          .toList();
      for (final MoexInstrument i in items) {
        _byTicker[i.ticker.toUpperCase()] = i;
      }
      _boardCache[key] = (items: items, at: DateTime.now());
      return items;
    } catch (_) {
      return cached?.items ?? const <MoexInstrument>[];
    }
  }

  /// Поиск по части тикера/названия. [bonds] — облигации (корпоративные
  /// + ОФЗ), иначе акции.
  Future<List<MoexInstrument>> search(String query, {required bool bonds}) async {
    List<MoexInstrument> board;
    if (bonds) {
      final List<MoexInstrument> corporate = await _board('bonds', 'TQCB');
      final List<MoexInstrument> ofz = await _board('bonds', 'TQOB');
      board = <MoexInstrument>[...corporate, ...ofz];
    } else {
      board = await _board('shares', 'TQBR');
    }
    if (board.isEmpty) return board;
    final String q = query.toLowerCase();
    final List<MoexInstrument> starts = <MoexInstrument>[];
    final List<MoexInstrument> contains = <MoexInstrument>[];
    for (final MoexInstrument i in board) {
      final String ticker = i.ticker.toLowerCase();
      final String name = i.name.toLowerCase();
      if (ticker.startsWith(q)) {
        starts.add(i);
      } else if (ticker.contains(q) || name.contains(q)) {
        contains.add(i);
      }
    }
    return <MoexInstrument>[...starts, ...contains].take(10).toList();
  }

  /// Метаданные тикера (купоны и т.п.) из уже загруженного борда.
  MoexInstrument? meta(String ticker) => _byTicker[ticker.toUpperCase()];

  /// Последний дивиденд на акцию (может отсутствовать — не критично).
  Future<({double value, String dateIso})?> lastDividend(String secid) async {
    try {
      final Uri uri = Uri.parse(
        'https://iss.moex.com/iss/securities/$secid/dividends.json'
        '?iss.meta=off&iss.only=dividends',
      );
      final HttpClientRequest request = await _client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) return null;
      final Map<String, dynamic> body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      final Map<String, dynamic> div = body['dividends'] ?? const {};
      final List<dynamic> cols = (div['columns'] as List?) ?? const [];
      final List<dynamic> rows = (div['data'] as List?) ?? const [];
      if (rows.isEmpty) return null;
      final int di = cols.indexOf('registrydate');
      final int vi = cols.indexOf('value');
      if (di < 0 || vi < 0) return null;
      final List<dynamic> last = rows.last;
      final dynamic value = last[vi];
      final dynamic date = last[di];
      if (value is! num || date is! String) return null;
      return (value: value.toDouble(), dateIso: date);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close(force: true);
  }
}
