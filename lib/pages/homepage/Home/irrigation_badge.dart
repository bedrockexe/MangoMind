// lib/widgets/irrigation_badge.dart
import 'package:flutter/material.dart';
import 'package:insights/pages/services/open_meteo_service.dart';
import 'package:insights/pages/services/irrigation_advisor.dart';
import 'package:insights/pages/homepage/Farm/farmlist/farmlist.dart';

class IrrigationBadge extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String timezone;
  final double kc;
  const IrrigationBadge({
    super.key,
    required this.latitude,
    required this.longitude,
    this.timezone = 'Asia/Manila',
    this.kc = 0.8,
  });

  @override
  State<IrrigationBadge> createState() => _IrrigationBadgeState();
}

class _IrrigationBadgeState extends State<IrrigationBadge> {
  Future<(IrrigationAdvice, OpenMeteoData)>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(IrrigationAdvice, OpenMeteoData)> _load() async {
    try {
      final m = await OpenMeteoService.fetch(
        lat: widget.latitude,
        lon: widget.longitude,
      );
      final advice = IrrigationAdvisor.evaluate(m, kc: widget.kc);
      return (advice, m);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<(IrrigationAdvice, OpenMeteoData)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Checking irrigation…'),
              ],
            ),
          );
        }
        if (snap.hasError) {
          final err = snap.error;
          return _pill(
            context,
            cs.errorContainer,
            cs.onErrorContainer,
            false,
            'Irrigation check failed',
          );
        }
        final (advice, m) = snap.data!;
        final ok = advice.recommend;
        final bg = ok ? cs.primaryContainer : cs.secondaryContainer;
        final fg = ok ? cs.onPrimaryContainer : cs.onSecondaryContainer;
        final label = ok
            ? 'Irrigation: Recommended'
            : 'Irrigation: Not Recommended';
        final rain = m.maxPrecipProbNext24h.toStringAsFixed(0);
        final wind = m.maxWindToday.toStringAsFixed(0);

        return _pill(context, bg, fg, ok, label, raining: rain, wind: wind);
      },
    );
  }

  Widget _pill(
    BuildContext context,
    Color bg,
    Color fg,
    bool isRecommended,
    String text, {
    String? raining,
    String? wind,
  }) {
    return Container(
      decoration: BoxDecoration(
        image: isRecommended
            ? DecorationImage(
                image: AssetImage("assets/sunny.jpg"),
                fit: BoxFit.cover,
              )
            : DecorationImage(
                image: AssetImage("assets/raining.jpg"),
                fit: BoxFit.cover,
              ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FarmListPage()),
              );
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: bg,
                      child: const Icon(Icons.opacity),
                    ),
                    title: Text(
                      'Irrigation check',
                      style: isRecommended
                          ? TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.black,
                            )
                          : TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: isRecommended
                              ? TextStyle(color: Colors.black)
                              : TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
                Divider(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: isRecommended
                      ? Text(
                          "Tip: Conditions are dry and your plants may need water. Run a short irrigation cycle or check soil moisture to confirm.",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.justify,
                        )
                      : Text(
                          "Tip: Rain detected — irrigation is not recommended right now. Soil moisture should stay sufficient for the next 24–48 hours. Save water and skip the scheduled cycle.",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
