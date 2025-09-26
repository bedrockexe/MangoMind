// lib/models/mango_price.dart
class MangoPrice {
  final String market;
  final String commodity;
  final String spec;
  final double? price;
  final String unit;
  final String asOf;
  final DateTime fetchedAt;

  MangoPrice({
    required this.market,
    required this.commodity,
    required this.spec,
    required this.price,
    required this.unit,
    required this.asOf,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'market': market,
    'commodity': commodity,
    'spec': spec,
    'price': price,
    'unit': unit,
    'as_of': asOf,
    'fetched_at': fetchedAt.toIso8601String(),
  };

  static MangoPrice fromJson(Map<String, dynamic> m) => MangoPrice(
    market: m['market'] as String,
    commodity: m['commodity'] as String,
    spec: m['spec'] as String,
    price: (m['price'] is num) ? (m['price'] as num).toDouble() : null,
    unit: m['unit'] as String,
    asOf: m['as_of'] as String,
    fetchedAt: DateTime.parse(m['fetched_at'] as String),
  );
}
