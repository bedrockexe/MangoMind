import 'package:flutter/material.dart';
import 'package:insights/pages/homepage/Farm/mangoprice/mangopriceservice.dart';
import 'package:insights/pages/homepage/Farm/mangoprice/mangomodel.dart';
import 'package:intl/intl.dart';

class MangoPriceTile extends StatefulWidget {
  const MangoPriceTile({super.key});

  @override
  State<MangoPriceTile> createState() => _MangoPriceTileState();
}

class _MangoPriceTileState extends State<MangoPriceTile> {
  late Future<(List<MangoPrice>, bool)> _future;

  @override
  void initState() {
    super.initState();
    _future = MangoPriceService.getSelectedMarkets();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = MangoPriceService.getSelectedMarkets();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    // Rendered inside a plain surface card, so it reads its colors straight
    // from the theme (which already adapts to light/dark mode).
    final scheme = Theme.of(context).colorScheme;
    final onScrim = scheme.onSurface;
    final onScrimVariant = scheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(List<MangoPrice>, bool)>(
        future: _future,
        builder: (context, snap) {
          // Loading Mango Prices
          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                ListTile(
                  title: Text('Mango (Carabao)'),
                  subtitle: Text('Loading latest price...'),
                  trailing: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            );
          }

          // Show Error if no data is retrieved
          if (snap.hasError || snap.data?.$1 == null) {
            return ListView(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                ListTile(
                  title: Text('Mango (Carabao) - Lipa'),
                  subtitle: Text('No data available'),
                  trailing: Icon(Icons.error, color: Colors.red),
                ),
              ],
            );
          }

          final (markets, isCached) = snap.data!;

          final fetched = DateFormat(
            'MMM d, yyyy h:mma',
          ).format(markets[1].fetchedAt);

          return Column(
            children: [
              ListView(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                children: markets.map((m) {
                  return Column(
                    children: [
                      ListTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 30,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              m.market.replaceAll("PUBLIC MARKET", "").trim(),
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: onScrim,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          m.price == null
                              ? 'N/A'
                              : '₱${m.price!.toStringAsFixed(2)}/kg',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: "Poppins",
                            fontFamilyFallback: ["Roboto", "sans-serif"],
                            color: onScrimVariant,
                          ),
                        ),
                      ),
                      Divider(),
                    ],
                  );
                }).toList(),
              ),
              Text(
                "Prices are updated as of $fetched",
                style: TextStyle(fontSize: 12, color: onScrimVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}
