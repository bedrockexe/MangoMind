import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherPanel extends StatefulWidget {
  const WeatherPanel({super.key});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  late Future<_WeatherData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WeatherData> _load() async {
    // ---------- 1) Location with graceful fallbacks ----------
    double lat = 13.928880330206127, lon = 120.95075460563223;

    try {
      // a) Services enabled?
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw const LocationServiceDisabledException();
      }

      // b) Permission (runtime)
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        throw const PermissionDeniedException('location-permission-denied');
      }

      // c) Last known first (instant)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        lat = last.latitude;
        lon = last.longitude;
      }

      // d) Fresh, accurate fix with short time limit (don’t block UX)
      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 8),
      );

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      lat = pos.latitude;
      lon = pos.longitude;
    } on PermissionDeniedException {
      // keep fallback silently
    } on LocationServiceDisabledException {
      // keep fallback silently
    } catch (_) {
      // any other error → keep fallback silently
    }

    // ---------- 2) Open-Meteo request ----------
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&timezone=auto'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,'
      'wind_direction_10m,wind_gusts_10m,precipitation,precipitation_probability,'
      'uv_index,cloud_cover'
      '&daily=temperature_2m_max,temperature_2m_min,uv_index_max,uv_index_clear_sky_max,'
      'precipitation_sum,rain_sum,showers_sum,precipitation_hours,wind_speed_10m_max,'
      'wind_gusts_10m_max,sunrise,sunset',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Weather API error: ${res.statusCode}');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return _WeatherData.fromOpenMeteo(j);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeatherData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _panelShell(
            child: Container(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage("assets/weather.jpg"),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.wb_sunny_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Today\'s Field Weather',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Text(
                      'Fetching weather data',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_bigStat('', 'Feels like field temp')],
                    ),
                    const Divider(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _miniTile(Icons.thermostat, 'Max / Min', ''),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _miniTile(Icons.air, 'Wind max', '')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _miniTile(
                            Icons.water_drop_outlined,
                            'Humidity',
                            '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _miniTile(
                            Icons.percent,
                            'Chance of raining',
                            '',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        }

        // Error
        if (snap.hasError) {
          return _panelShell(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load weather data.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Possible causes:\n'
                    '• Your internet might be slow\n'
                    '• The server may be unreachable\n'
                    '• Please try reloading again',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // No data (defensive; avoids snap.data! when null)
        if (!snap.hasData) {
          return _panelShell(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No weather data available right now.'),
            ),
          );
        }

        final w = snap.data!;

        final _Daily today = (w.daily.isNotEmpty)
            ? w.daily.first
            : _Daily(
                date: DateTime.now(),
                tMax: w.currentTemp,
                tMin: w.currentTemp,
                uvMax: null,
                precipSum: null,
                rainSum: null,
                showersSum: null,
                precipHours: null,
                windMax: w.currentWindSpeed,
                gustMax: w.currentWindGust,
                sunrise: DateTime.now(),
                sunset: DateTime.now().add(const Duration(hours: 12)),
              );

        return _panelShell(
          child: Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage("assets/weather.jpg"),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.wb_sunny_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Today\'s Field Weather',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.locationLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bigStat(
                        '${w.currentTemp.toStringAsFixed(1)}°C',
                        'Feels like field temp',
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.thermostat,
                          'Max / Min',
                          '${today.tMax.toStringAsFixed(1)}° / ${today.tMin.toStringAsFixed(1)}°',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.air,
                          'Wind max',
                          '${(today.windMax ?? w.currentWindSpeed).toStringAsFixed(1)} m/s',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.water_drop_outlined,
                          'Humidity',
                          '${w.currentHumidity}%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.percent,
                          'Chance of raining',
                          '${(w.currentPrecipProb ?? 0).round()}%',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panelShell({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  Widget _bigStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          value == ''
              ? Center(child: CircularProgressIndicator(strokeWidth: 3))
              : Text(
                  value,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _miniTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          value == ''
              ? Center(child: CircularProgressIndicator(strokeWidth: 3))
              : Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ],
      ),
    );
  }
}

class _WeatherData {
  final String locationLabel;
  final double currentTemp;
  final int currentHumidity;
  final double currentWindSpeed;
  final double currentWindDir;
  final double? currentWindGust;
  final double? currentPrecip; // mm
  final double? currentPrecipProb; // %
  final double? currentUv;
  final int? currentCloud;

  final List<_Daily> daily;

  _WeatherData({
    required this.locationLabel,
    required this.currentTemp,
    required this.currentHumidity,
    required this.currentWindSpeed,
    required this.currentWindDir,
    this.currentWindGust,
    this.currentPrecip,
    this.currentPrecipProb,
    this.currentUv,
    this.currentCloud,
    required this.daily,
  });

  factory _WeatherData.fromOpenMeteo(Map<String, dynamic> j) {
    final current = j['current'] as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    final times = (daily['time'] as List).cast<String>();

    final List<_Daily> dailies = List.generate(times.length, (i) {
      return _Daily(
        date: DateTime.parse(times[i]),
        tMax: _asD(daily['temperature_2m_max'][i]) ?? 0.0,
        tMin: _asD(daily['temperature_2m_min'][i]) ?? 0.0,
        uvMax: _asD(daily['uv_index_max'][i]),
        precipSum: _asD(daily['precipitation_sum'][i]),
        rainSum: _asD(daily['rain_sum'][i]),
        showersSum: _asD(daily['showers_sum'][i]),
        precipHours: _asD(daily['precipitation_hours'][i])?.round(),
        windMax: _asD(daily['wind_speed_10m_max'][i]),
        gustMax: _asD(daily['wind_gusts_10m_max'][i]),
        sunrise: DateTime.parse(daily['sunrise'][i]),
        sunset: DateTime.parse(daily['sunset'][i]),
      );
    });

    return _WeatherData(
      locationLabel: j['timezone']?.toString() ?? 'Local forecast',
      currentTemp: _asD(current['temperature_2m']) ?? 0,
      currentHumidity: (current['relative_humidity_2m'] as num?)?.round() ?? 0,
      currentWindSpeed: _asD(current['wind_speed_10m']) ?? 0,
      currentWindDir: _asD(current['wind_direction_10m']) ?? 0,
      currentWindGust: _asD(current['wind_gusts_10m']),
      currentPrecip: _asD(current['precipitation']),
      currentPrecipProb: _asD(current['precipitation_probability']),
      currentUv: _asD(current['uv_index']),
      currentCloud: (current['cloud_cover'] as num?)?.round(),
      daily: dailies,
    );
  }

  static double? _asD(dynamic v) => v == null ? null : (v as num).toDouble();
}

class _Daily {
  final DateTime date;
  final double tMax;
  final double tMin;
  final double? uvMax;
  final double? precipSum; // mm
  final double? rainSum; // mm
  final double? showersSum; // mm
  final int? precipHours; // h
  final double? windMax; // m/s
  final double? gustMax; // m/s
  final DateTime sunrise;
  final DateTime sunset;

  _Daily({
    required this.date,
    required this.tMax,
    required this.tMin,
    this.uvMax,
    this.precipSum,
    this.rainSum,
    this.showersSum,
    this.precipHours,
    this.windMax,
    this.gustMax,
    required this.sunrise,
    required this.sunset,
  });
}
