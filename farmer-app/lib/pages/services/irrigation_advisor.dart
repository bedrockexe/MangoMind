// lib/services/irrigation_advisor.dart
import 'open_meteo_service.dart';

class IrrigationAdvice {
  final bool recommend;
  final String reason;
  final double waterDeficitMm;
  final String? blockedBy;

  const IrrigationAdvice({
    required this.recommend,
    required this.reason,
    required this.waterDeficitMm,
    this.blockedBy,
  });
}

class IrrigationAdvisor {
  /// - Don’t irrigate if any blocker is true:
  ///     * high rain chance (>= 60%)
  ///     * near-term nowcast rain (> 0.5 mm in next 2h)
  ///     * strong wind (>= 30 km/h)
  ///     * top soil moisture adequate (>= 0.25 m³/m³)
  static IrrigationAdvice evaluate(
    OpenMeteoData m, {
    double kc = 0.8, // tune per season/stage
    double deficitThreshold = 2, // mm
    double moistOkay = 0.25, // m³/m³
    int rainProbBlock = 60, // %
    double nowcastBlockMm = 0.5, // mm in next ~2h
    double windBlockKmh = 30.0, // km/h
  }) {
    double _nn(num? v) => (v ?? 0).toDouble();
    double _clamp(double v, double min, double max) => v.isNaN
        ? 0
        : v < min
        ? min
        : (v > max ? max : v);

    final et0 = _clamp(_nn(m.dailyEt0), 0, 50);
    final rain = _clamp(_nn(m.dailyRain), 0, 500);
    final windMax = _clamp(_nn(m.maxWindToday), 0, 200);
    final soil07 = _clamp(_nn(m.soilMoisture07cm), 0, 1);
    final rainProb = (m.maxPrecipProbNext24h).clamp(0, 100);

    final etCrop = kc * et0;
    final rawDeficit = etCrop - rain;
    final deficit = rawDeficit <= 0 ? 0.0 : rawDeficit;

    if (rainProb >= rainProbBlock) {
      return IrrigationAdvice(
        recommend: false,
        reason: 'High chance of rain (≥ $rainProbBlock%).',
        waterDeficitMm: 0,
        blockedBy: 'rain_probability',
      );
    }

    if (_nn(m.precipNowcastNext2h) > nowcastBlockMm) {
      return const IrrigationAdvice(
        recommend: false,
        reason: 'Rain expected soon (nowcast ≤2h).',
        waterDeficitMm: 0,
        blockedBy: 'nowcast_rain',
      );
    }

    if (windMax >= windBlockKmh) {
      return IrrigationAdvice(
        recommend: false,
        reason:
            'Too windy for efficient irrigation (≥ ${windBlockKmh.toStringAsFixed(0)} km/h).',
        waterDeficitMm: 0,
        blockedBy: 'wind',
      );
    }

    if (soil07 >= moistOkay) {
      return IrrigationAdvice(
        recommend: false,
        reason:
            'Top soil moisture is adequate (≥ ${moistOkay.toStringAsFixed(2)} m³/m³).',
        waterDeficitMm: 0,
        blockedBy: 'soil_moisture',
      );
    }

    if (deficit >= deficitThreshold) {
      return IrrigationAdvice(
        recommend: true,
        reason: 'Water deficit: ${deficit.toStringAsFixed(1)} mm.',
        waterDeficitMm: double.parse(deficit.toStringAsFixed(2)),
        blockedBy: null,
      );
    }

    return const IrrigationAdvice(
      recommend: false,
      reason: 'Low water deficit today.',
      waterDeficitMm: 0,
      blockedBy: null,
    );
  }

  static double kcForStage(String stage) {
    switch (stage.toLowerCase()) {
      case 'vegetative':
        return 0.6;
      case 'flowering':
        return 0.9;
      case 'fruiting':
        return 0.8;
      case 'late':
      case 'senescence':
        return 0.5;
      default:
        return 0.8;
    }
  }
}
