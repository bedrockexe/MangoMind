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

  // ---------- Loading (upgraded shimmer skeleton) ----------
  Widget _buildLoadingPanel() => Container(
    height: 500,
    decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/weather2.jpg"),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.3),
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
            // header row skeleton
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        height: 18,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // big card skeleton for temperature
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 22,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 22,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 22,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
              color: Colors.white.withOpacity(0.08),
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
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
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
              backgroundColor: Colors.white.withOpacity(0.12),
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
                  color: Colors.white.withOpacity(0.06),
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
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    ),
  );

  Widget _buildWeatherPanel(OpenMeteoData data, String location) {
    return _coloredContainer(
      Colors.green.shade400,
      Colors.green.shade900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.wb_sunny, color: Colors.white, size: 32),
              SizedBox(width: 10),
              Text(
                'Today’s Field Weather',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'San Nicolas, Batangas',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.thermostat, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.dailyTempMax.toStringAsFixed(1)}°C / '
                      '${data.dailyTempMin.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Max / Min Temperature',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().slideY(begin: 0.5, duration: 700.ms),
          const SizedBox(height: 20),
          _buildAnimatedTile(
            Icons.water_drop,
            'Precipitation (mm)',
            data.dailyPrecip.toStringAsFixed(1),
          ),
          _buildAnimatedTile(
            Icons.wind_power,
            'Max Wind',
            '${data.maxWindToday.toStringAsFixed(1)} km/h',
          ),
          _buildAnimatedTile(
            Icons.cloud_queue,
            'Chance of Rain (Next 24 h)',
            '${data.maxPrecipProbNext24h}%',
          ),
          _buildAnimatedTile(
            Icons.opacity,
            'Humidity',
            '${double.parse(data.dailyHumidity.toString()).toInt().toString()}%',
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.3);
  }

  // ---------- Utility containers ----------
  Widget _coloredContainer(Color base1, Color base2, {required Widget child}) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/weather2.jpg"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.3),
            BlendMode.darken,
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
