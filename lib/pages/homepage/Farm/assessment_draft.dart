// draft_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DraftService {
  static const String _draftKey = 'sweet_insights_draft';
  static const String _farmerEmailKey = 'sweet_insights_farmer_email';

  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_draftKey);
    if (jsonStr == null) return null;
    try {
      final Map<String, dynamic> m = Map<String, dynamic>.from(
        jsonDecode(jsonStr),
      );
      return m;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  static Future<void> saveFarmerEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_farmerEmailKey, email);
  }

  static Future<String?> getSavedFarmerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_farmerEmailKey);
  }
}
