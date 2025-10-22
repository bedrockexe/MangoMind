// lib/features/irrigation/irrigation_check.dart
import 'package:insights/pages/services/open_meteo_service.dart';
import 'package:insights/pages/services/irrigation_advisor.dart';
import 'package:insights/notifier.dart';

class IrrigationCheck {
  // Run a check right now and show a local notification if recommended
  static Future<void> runOnceAndNotifyForLocation(
    double lat,
    double lon,
  ) async {
    try {
      final m = await OpenMeteoService.fetch(lat: lat, lon: lon);
      final advice = IrrigationAdvisor.evaluate(m);
      final title = advice.recommend
          ? 'Irrigation recommended'
          : 'Irrigation not recommended';
      final body = advice.recommend
          ? '${advice.reason} • Deficit ${advice.waterDeficitMm.toStringAsFixed(1)} mm'
          : advice.reason;
      await LocalNotifier.showNow(title: title, body: body, payload: '/farm');
    } catch (e) {
      //
    }
  }

  static Future<void> scheduleDailyForLocation(double lat, double lon) async {
    await LocalNotifier.scheduleDailyAt6AM(
      buildBody: () async {
        try {
          final m = await OpenMeteoService.fetch(lat: lat, lon: lon);
          final advice = IrrigationAdvisor.evaluate(m);
          return advice.recommend
              ? '${advice.reason} • Deficit ${advice.waterDeficitMm.toStringAsFixed(1)} mm'
              : 'Not recommended: ${advice.reason}';
        } catch (_) {
          return 'Irrigation check failed';
        }
      },
    );
  }
}
