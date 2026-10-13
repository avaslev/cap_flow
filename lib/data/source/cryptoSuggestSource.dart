import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Инструмент из внешнего источника: тикер, название и курс к дефолтной валюте.
class OnlineInstrument {
  final String id;
  final String ticker;
  final String name;
  double? rate;

  OnlineInstrument({
    required this.id,
    required this.ticker,
    required this.name,
    this.rate,
  });
}

/// Внешний источник крипто-инструментов (CoinGecko, без ключа).
/// Любая сетевая ошибка — пустой результат (не критично).
class CryptoSuggestSource {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  /// Поиск по части тикера/названия. Без цен — они отдельным запросом,
  /// чтобы подсказки показывались не дожидаясь курсов.
  Future<List<OnlineInstrument>> search(String query) async {
    try {
      final Uri uri = Uri.parse(
        'https://api.coingecko.com/api/v3/search?query=$query',
      );
      final HttpClientRequest request = await _client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        return const <OnlineInstrument>[];
      }
      final Map<String, dynamic> body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      return ((body['coins'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .take(10)
          .map<OnlineInstrument>(
            (Map<String, dynamic> coin) => OnlineInstrument(
              id: coin['id'] as String? ?? '',
              ticker: (coin['symbol'] as String? ?? '').toUpperCase(),
              name: coin['name'] as String? ?? '',
            ),
          )
          .where((OnlineInstrument i) => i.ticker.isNotEmpty && i.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const <OnlineInstrument>[];
    }
  }

  /// Курсы к дефолтной валюте: id монеты → цена.
  Future<Map<String, double>> fetchRates(
    List<OnlineInstrument> items,
    String vsCurrency,
  ) async {
    final Map<String, double> rates = <String, double>{};
    if (items.isEmpty) return rates;
    try {
      final String ids = items.map((OnlineInstrument i) => i.id).join(',');
      final Uri uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=$ids&vs_currencies=${vsCurrency.toLowerCase()}',
      );
      final HttpClientRequest request = await _client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        return rates;
      }
      final Map<String, dynamic> body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      for (final OnlineInstrument i in items) {
        final dynamic entry = body[i.id];
        if (entry is Map<String, dynamic>) {
          final dynamic value = entry[vsCurrency.toLowerCase()];
          if (value is num) {
            rates[i.id] = value.toDouble();
          }
        }
      }
    } catch (_) {
      // Курс не критичен: подсказки без цены тоже полезны.
    }
    return rates;
  }

  void dispose() {
    _client.close(force: true);
  }
}
