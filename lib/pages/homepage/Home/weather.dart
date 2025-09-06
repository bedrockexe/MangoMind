import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

/// Shows: temp, humidity, wind (speed/dir/gust), UV, precip (mm & %), sunrise/sunset, max/min.
class WeatherPanel extends StatefulWidget {
  const WeatherPanel({super.key});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  Future<_WeatherData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WeatherData> _load() async {
    // 1) Get location (with permission). Fallback: Manila
    double lat = 14.5995, lon = 120.9842; // Manila fallback
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (enabled &&
          (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse)) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        lat = pos.latitude;
        lon = pos.longitude;
      }
    } catch (_) {
      /* use fallback */
    }

    // 2) Call Open-Meteo (free, no key). We ask for current & daily variables useful to mango farming.
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&timezone=auto'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,precipitation_probability,uv_index,cloud_cover'
      '&daily=temperature_2m_max,temperature_2m_min,uv_index_max,uv_index_clear_sky_max,precipitation_sum,rain_sum,showers_sum,precipitation_hours,wind_speed_10m_max,wind_gusts_10m_max,sunrise,sunset',
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
        if (snap.connectionState == ConnectionState.waiting) {
          return _panelShell(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return _panelShell(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load weather.\n${snap.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        final w = snap.data!;
        final df = DateFormat('hh:mm a');
        final today = w.daily.first;

        return _panelShell(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/weather.jpg"),
                fit: BoxFit.cover, // cover, contain, etc.
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.white,
                          ),
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
                      Row(
                        children: [
                          SizedBox(width: 5, height: 5),
                          Text(
                            w.locationLabel,
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Current snapshot
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bigStat(
                        '${w.currentTemp.toStringAsFixed(1)}°C',
                        'Feels like field temp',
                      ),
                      // const SizedBox(width: 16),
                      // Expanded(
                      //   child: Wrap(
                      //     runSpacing: 10,
                      //     spacing: 12,
                      //     children: [
                      //       _chipStat(
                      //         Icons.water_drop_outlined,
                      //         'Humidity',
                      //         '${w.currentHumidity}%',
                      //       ),
                      //       _chipStat(
                      //         Icons.air_outlined,
                      //         'Wind',
                      //         '${w.currentWindSpeed.toStringAsFixed(1)} m/s ${_degToCompass(w.currentWindDir)}',
                      //       ),
                      //       _chipStat(
                      //         Icons.speed_outlined,
                      //         'Gust',
                      //         '${w.currentWindGust?.toStringAsFixed(1) ?? '-'} m/s',
                      //       ),
                      //       _chipStat(
                      //         Icons.grain_outlined,
                      //         'Precip',
                      //         '${w.currentPrecip?.toStringAsFixed(1) ?? '0'} mm',
                      //       ),
                      // _chipStat(
                      //   Icons.percent,
                      //   'Rain chance',
                      //   w.currentPrecipProb != null
                      //       ? '${w.currentPrecipProb!.round()}%'
                      //       : '—',
                      // ),
                      //       _chipStat(
                      //         Icons.sunny_snowing,
                      //         'UV',
                      //         w.currentUv?.toStringAsFixed(1) ?? '—',
                      //       ),
                      //       _chipStat(
                      //         Icons.cloud_outlined,
                      //         'Cloud',
                      //         '${w.currentCloud ?? 0}%',
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Today’s forecast (max/min, totals, sunrise/sunset)
                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.thermostat,
                          'Max / Min',
                          '${today.tMax.toStringAsFixed(1)}° / ${today.tMin.toStringAsFixed(1)}°',
                        ),
                      ),
                      // Expanded(
                      //   child: _miniTile(
                      //     Icons.umbrella_outlined,
                      //     'Precip (mm)',
                      //     (today.precipSum ?? 0).toStringAsFixed(1),
                      //   ),
                      // ),
                      // Expanded(
                      //   child: _miniTile(
                      //     Icons.bolt,
                      //     'UV max',
                      //     (today.uvMax ?? 0).toStringAsFixed(1),
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.air,
                          'Wind max',
                          '${today.windMax?.toStringAsFixed(1) ?? 0} m/s',
                        ),
                      ),
                      // Expanded(
                      //   child: _miniTile(
                      //     Icons.air_rounded,
                      //     'Gust max',
                      //     '${today.gustMax?.toStringAsFixed(1) ?? 0} m/s',
                      //   ),
                      // ),
                      // Expanded(
                      //   child: _miniTile(
                      //     Icons.timer,
                      //     'Rain hours',
                      //     '${today.precipHours ?? 0}h',
                      //   ),
                      // ),
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

                      // Expanded(
                      //   child: _miniTile(
                      //     Icons.wb_twighlight,
                      //     'Sunrise',
                      //     df.format(today.sunrise),
                      //   ),
                      // ),
                      // Expanded(
                      //   child: _miniTile(
                      //     Icons.dark_mode_outlined,
                      //     'Sunset',
                      //     df.format(today.sunset),
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _miniTile(
                          Icons.percent,
                          'Chance of raining',
                          '${w.currentHumidity}%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Tip: High humidity + calm winds increase fungal risk (e.g., powdery mildew). Plan sprays/irrigation around forecasted rain & wind.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _chipStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _degToCompass(num deg) {
    const dirs = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    return dirs[((deg / 22.5) + 0.5).floor() % 16];
  }
}

/// --------------------
/// Simple data classes
/// --------------------
class _WeatherData {
  final String locationLabel;
  // current
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

    List<_Daily> dailies = [];
    for (var i = 0; i < times.length; i++) {
      dailies.add(
        _Daily(
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
        ),
      );
    }

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
