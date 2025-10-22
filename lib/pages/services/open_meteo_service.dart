// lib/services/open_meteo_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class OpenMeteoData {
  final double dailyEt0; // mm
  final double dailyPotentialEvap; // mm
  final double dailyRain; // mm
  final double dailyPrecip; // mm
  final double dailyShortwave; // MJ/m^2
  final double soilMoisture07cm; // m^3/m^3
  final double maxWindToday; // km/h
  final int maxPrecipProbNext24h; // %
  final double precipNowcastNext2h; // mm
  final double dailyTempMax;
  final double dailyTempMin;

  OpenMeteoData({
    required this.dailyEt0,
    required this.dailyPotentialEvap,
    required this.dailyRain,
    required this.dailyPrecip,
    required this.dailyShortwave,
    required this.soilMoisture07cm,
    required this.maxWindToday,
    required this.maxPrecipProbNext24h,
    required this.precipNowcastNext2h,
    required this.dailyTempMax,
    required this.dailyTempMin,
  });
}

class OpenMeteoService {
  static const _forecastBase = 'https://api.open-meteo.com/v1/forecast';
  static const _nowcastBase = 'https://api.open-meteo.com/v1/nowcast';

  /// Primary fetch using explicit lat/lon. Uses timezone=auto.
  static Future<OpenMeteoData> fetch({
    required double lat,
    required double lon,
  }) async {
    // ---------- 1) Forecast (daily + hourly) ----------
    // Daily signals
    final dailyVars = [
      'et0_fao_evapotranspiration',
      'precipitation_sum',
      'rain_sum',
      'shortwave_radiation_sum',
      'temperature_2m_max',
      'temperature_2m_min',
    ].join(',');

    // Hourly signals (includes soil & wind & precip prob)
    final hourlyVars = [
      'precipitation_probability',
      'precipitation',
      'rain',
      'wind_speed_10m',
      'soil_moisture_0_to_7cm',
    ].join(',');

    final forecastUri = Uri.parse(
      '$_forecastBase?latitude=$lat&longitude=$lon'
      '&timezone=auto'
      '&hourly=$hourlyVars'
      '&daily=$dailyVars'
      '&forecast_days=2',
    );

    final fRes = await http.get(forecastUri);
    if (fRes.statusCode != 200) {
      throw Exception('Open-Meteo error ${fRes.statusCode}: ${fRes.body}');
    }

    final fjson = jsonDecode(fRes.body) as Map<String, dynamic>;

    // Helpers
    double _nn(num? v) => (v ?? 0).toDouble();
    double _pickDaily(List a) => a.isNotEmpty ? _nn(a[0]) : 0.0;
    T _as<T>(dynamic x, T fallback) => x is T ? x : fallback;

    // Daily
    final daily = _as<Map<String, dynamic>>(fjson['daily'], {});
    print(daily);
    final et0 = _pickDaily(
      _as<List>(daily['et0_fao_evapotranspiration'], const []),
    );
    final pSum = _pickDaily(_as<List>(daily['precipitation_sum'], const []));
    final rSum = _pickDaily(_as<List>(daily['rain_sum'], const []));
    final sw = _pickDaily(
      _as<List>(daily['shortwave_radiation_sum'], const []),
    );
    final tMax = _pickDaily(_as<List>(daily['temperature_2m_max'], const []));
    final tMin = _pickDaily(_as<List>(daily['temperature_2m_min'], const []));

    // Hourly
    final hourly = _as<Map<String, dynamic>>(fjson['hourly'], {});
    final probs = _as<List>(hourly['precipitation_probability'], const []);
    final winds = _as<List>(hourly['wind_speed_10m'], const []);
    final soil = _as<List>(hourly['soil_moisture_0_to_7cm'], const []);

    final maxProb = probs.take(24).fold<int>(0, (m, e) {
      final v = (e is num) ? e.toInt() : 0;
      return v > m ? v : m;
    });

    final maxWind = winds.take(24).fold<double>(0.0, (m, e) {
      final v = (e is num) ? e.toDouble() : 0.0;
      return v > m ? v : m;
    });

    // Choose a near-"now" soil value; first element is fine for simple display
    final soil07 = soil.isNotEmpty ? _nn(soil.first as num?) : 0.0;

    // ---------- 2) Nowcast (sum next 2h, 15-min steps) ----------
    double nowcastSum = 0.0;
    try {
      final ncUri = Uri.parse(
        '$_nowcastBase?latitude=$lat&longitude=$lon'
        '&minutely_15=precipitation'
        '&forecast_minutes=120',
      );
      final ncRes = await http.get(ncUri);
      if (ncRes.statusCode == 200) {
        final njson = jsonDecode(ncRes.body) as Map<String, dynamic>;
        final mins = _as<Map<String, dynamic>>(njson['minutely_15'], {});
        final prec = _as<List>(mins['precipitation'], const []);
        for (final v in prec) {
          nowcastSum += _nn(v is num ? v : 0);
        }
      } else {
        // Non-fatal if nowcast is not available in region
        // print('Nowcast ${ncRes.statusCode}: ${ncRes.body}');
      }
    } catch (_) {
      // swallow nowcast issues
    }

    final potentialEvap = et0;
    return OpenMeteoData(
      dailyEt0: et0,
      dailyPotentialEvap: potentialEvap,
      dailyPrecip: pSum,
      dailyRain: rSum,
      dailyShortwave: sw,
      soilMoisture07cm: soil07,
      maxWindToday: maxWind,
      maxPrecipProbNext24h: maxProb,
      precipNowcastNext2h: nowcastSum,
      dailyTempMax: tMax,
      dailyTempMin: tMin,
    );
  }

  static Future<OpenMeteoData> fetchWithAutoLocation() async {
    double lat = 13.928880330206127, lon = 120.95075460563223;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw const LocationServiceDisabledException();

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        throw const PermissionDeniedException('location-permission-denied');
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        lat = last.latitude;
        lon = last.longitude;
      }

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
    } catch (_) {
      // keep fallback silently
    }

    return fetch(lat: lat, lon: lon);
  }
}
