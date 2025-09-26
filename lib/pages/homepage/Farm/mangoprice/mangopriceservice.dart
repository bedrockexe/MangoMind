// lib/services/mango_price_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insights/pages/homepage/Farm/mangoprice/mangomodel.dart';

class MangoPriceService {
  static const _base = 'http://www.bantaypresyo.da.gov.ph';
  static const _urlHeader = '$_base/tbl_price_get_comm_header.php';
  static const _urlPrice = '$_base/tbl_price_get_comm_price.php';
  static const _urlDate = '$_base/tbl_price_get_date_rice.php';

  static const _region = '040000000'; // CALABARZON
  static const _commodity = '5'; // FRUITS

  static const _cacheKey = 'mango_price_multi_v1';

  static Map<String, String> _headers() => {
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': _base,
    'Referer': '$_base/tbl_fruits.php',
    'User-Agent': 'FlutterApp/1.0',
  };

  /// Public: get mango prices for selected Batangas/Laguna markets
  static Future<(List<MangoPrice>, bool isCached)> getSelectedMarkets() async {
    try {
      final fresh = await _fetchMarketsLive();
      await _saveCache(fresh);
      return (fresh, false);
    } catch (_) {
      final cached = await _loadCache();
      if (cached != null) return (cached, true);
      rethrow;
    }
  }

  // ---------- Internals ----------

  static Future<List<MangoPrice>> _fetchMarketsLive() async {
    final client = http.Client();
    try {
      // Header first (to get market labels + count)
      final hdrRes = await client.post(
        Uri.parse(_urlHeader),
        headers: _headers(),
        body: {'commodity': _commodity, 'region': _region},
      );
      final hdrHtml = hdrRes.body.trim();
      if (hdrHtml.isEmpty) throw Exception('Empty header response');

      final headerLabels = _parseHeaderLabels(hdrHtml);
      final count = headerLabels.length;

      // Price table
      final prcRes = await client.post(
        Uri.parse(_urlPrice),
        headers: _headers(),
        body: {'commodity': _commodity, 'region': _region, 'count': '$count'},
      );
      final prcHtml = prcRes.body.trim();
      if (prcHtml.isEmpty) throw Exception('Empty price response');
      final prcDoc = html_parser.parse('<table>$prcHtml</table>');
      final rows = prcDoc.querySelectorAll('tr');

      // Date
      final dateRes = await client.post(
        Uri.parse(_urlDate),
        headers: _headers(),
        body: {'commodity': _commodity, 'region': _region},
      );
      final dateText = dateRes.body.trim();
      final asOfMatch = RegExp(
        r'([A-Za-z]+\s+\d{1,2},\s+\d{4})',
      ).firstMatch(dateText);
      final asOf = asOfMatch?.group(1) ?? dateText;

      // Find mango row once
      final mangoRow = rows.firstWhere(
        (tr) {
          final tds = tr.querySelectorAll('td');
          final commodity = tds.isNotEmpty
              ? tds[0].text.trim().toUpperCase()
              : '';
          final spec = tds.length > 1 ? tds[1].text.trim().toUpperCase() : '';
          return commodity.contains('MANGO (CARABAO)') &&
              RegExp(r'3[\-\–]4').hasMatch(spec);
        },
        orElse: () =>
            throw Exception('Carabao Mango 3–4 pcs/kg row not found.'),
      );

      final tds = mangoRow.querySelectorAll('td');

      // Target markets
      final targets = [
        'LIPA CITY PUBLIC MARKET',
        'TANZA PUBLIC MARKET',
        'BINAN CITY PUBLIC MARKET',
      ];

      final results = <MangoPrice>[];

      for (final target in targets) {
        final idx = headerLabels.indexWhere(
          (lbl) => lbl.toUpperCase().contains(target),
        );
        if (idx == -1 || idx >= tds.length) continue;

        final priceText = tds[idx].text.trim();
        final price = double.tryParse(priceText.replaceAll(',', ''));

        results.add(
          MangoPrice(
            market: headerLabels[idx],
            commodity: 'Mango (Carabao)',
            spec: 'RIPE, 3–4 PCS/KG',
            price: price,
            unit: 'PHP/kg',
            asOf: asOf,
            fetchedAt: DateTime.now(),
          ),
        );
      }

      return results;
    } finally {
      client.close();
    }
  }

  static List<String> _parseHeaderLabels(String headerHtml) {
    final doc = html_parser.parse('<table>$headerHtml</table>');
    final firstTr = doc.querySelector('tr');
    if (firstTr == null) return [];
    final labels = <String>[];
    for (final cell in firstTr.querySelectorAll('td, th')) {
      final label = cell.text.trim();
      final colspan = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;
      for (var i = 0; i < colspan; i++) {
        labels.add(label);
      }
    }
    return labels;
  }

  static Future<void> _saveCache(List<MangoPrice> data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = data.map((m) => m.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(list));
  }

  static Future<List<MangoPrice>?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((m) => MangoPrice.fromJson(m)).toList();
  }
}
