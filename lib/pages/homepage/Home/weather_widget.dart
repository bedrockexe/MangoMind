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

    String locationName = "Your Field";
    try {
      // Use the same location used inside fetchWithAutoLocation
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
    } catch (_) {
      // fallback if reverse geocoding fails
    }

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

  // ---------- UI builders ----------
  Widget _buildLoadingPanel() => _shimmerContainer(
    child: const Text(
      'Fetching Weather Data...',
      style: TextStyle(color: Colors.white, fontSize: 18),
    ),
  );

  Widget _buildErrorPanel() => _coloredContainer(
    Colors.red.shade400,
    Colors.red.shade900,
    child: const Text(
      'Failed to load weather data.',
      style: TextStyle(color: Colors.white, fontSize: 18),
    ),
  );

  Widget _buildNoDataPanel() => _coloredContainer(
    Colors.grey.shade400,
    Colors.grey.shade900,
    child: const Text(
      'No weather data available.',
      style: TextStyle(color: Colors.white, fontSize: 18),
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
            location,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
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
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
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
        ],
      ),
    );
  }

  Widget _buildAnimatedTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
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
      height: 450,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [base1, base2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _shimmerContainer({required Widget child}) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade300, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.3),
        highlightColor: Colors.white.withOpacity(0.6),
        child: Center(child: child),
      ),
    );
  }
}
