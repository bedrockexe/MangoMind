// lib/widgets/weather_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:insights/pages/services/open_meteo_service.dart';
import 'package:shimmer/shimmer.dart';

class WeatherPanel extends StatefulWidget {
  const WeatherPanel({super.key});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel>
    with TickerProviderStateMixin {
  late Future<Map<String, dynamic>> _future;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _future = _loadWeatherAndLocation();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<Map<String, dynamic>> _loadWeatherAndLocation() async {
    final data = await OpenMeteoService.fetchWithAutoLocation();

    String locationName = "Manila";
    try {
      final pos = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locality = place.locality ?? '';
        final province = place.administrativeArea ?? '';
        locationName = [
          locality,
          province,
        ].where((e) => e.isNotEmpty).join(', ').trim();
      }
    } catch (_) {}

    return {"data": data, "location": locationName};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _buildLoadingPanel();
        }

        if (snap.hasError) {
          return _buildErrorPanel();
        }

        if (!snap.hasData) {
          return _buildNoDataPanel();
        }

        final data = snap.data!["data"] as OpenMeteoData;
        final location = snap.data!["location"] as String;

        _animationController.forward();
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _buildWeatherPanel(data, location),
        );
      },
    );
  }

  // ---------- Loading (compact shimmer skeleton) ----------
  Widget _skeletonBlock({double? width, double height = 14, double radius = 8}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  Widget _buildLoadingPanel() => Container(
    decoration: BoxDecoration(
      image: DecorationImage(
        image: const AssetImage("assets/weather_bg.jpg"),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.4),
          BlendMode.darken,
        ),
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.18),
      highlightColor: Colors.white.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonBlock(width: 160, height: 16),
            const SizedBox(height: 8),
            _skeletonBlock(width: 110),
            const SizedBox(height: 18),
            _skeletonBlock(width: 120, height: 48, radius: 12),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _skeletonBlock(height: 48, radius: 14)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBlock(height: 48, radius: 14)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _skeletonBlock(height: 48, radius: 14)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBlock(height: 48, radius: 14)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildErrorPanel() => _coloredContainer(
    Colors.red.shade400,
    Colors.red.shade900,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated error icon
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            padding: const EdgeInsets.all(14),
            child: Icon(Icons.error_outline, color: Colors.white, size: 48),
          ).animate().shake(delay: 200.ms, duration: 800.ms),
          const SizedBox(height: 12),
          const Text(
            'Failed to load weather data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 6),
          Text(
            'Please check your connection or try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 14),
          // subtle retry action — non-blocking, caller can change behavior
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _future = _loadWeatherAndLocation();
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    ),
  );

  Widget _buildNoDataPanel() => _coloredContainer(
    Colors.grey.shade400,
    Colors.grey.shade900,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 600.ms,
              ),
          const SizedBox(height: 12),
          const Text(
            'No weather data available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 6),
          Text(
            'Data might be temporarily unavailable for your location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    ),
  );

  Widget _buildWeatherPanel(OpenMeteoData data, String location) {
    final humidity = double.parse(data.dailyHumidity.toString()).toInt();
    return _coloredContainer(
      Colors.green.shade400,
      Colors.green.shade900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location + condition
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location.trim().isEmpty ? 'Your location' : location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.wb_sunny, color: Colors.white, size: 26),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Today’s field weather',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          // Headline temperature
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.dailyTempMax.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High / Low',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${data.dailyTempMax.toStringAsFixed(0)}° / '
                      '${data.dailyTempMin.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 18),
          // Metric pills (2x2)
          Row(
            children: [
              _metricPill(Icons.opacity, '$humidity%', 'Humidity'),
              const SizedBox(width: 10),
              _metricPill(
                Icons.air,
                data.maxWindToday.toStringAsFixed(0),
                'km/h wind',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricPill(
                Icons.umbrella,
                '${data.maxPrecipProbNext24h}%',
                'Rain (24h)',
              ),
              const SizedBox(width: 10),
              _metricPill(
                Icons.water_drop,
                data.dailyPrecip.toStringAsFixed(1),
                'mm precip',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Utility containers ----------
  Widget _coloredContainer(Color base1, Color base2, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage("assets/weather_bg.jpg"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.4),
            BlendMode.darken,
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
