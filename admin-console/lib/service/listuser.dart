import 'package:cloud_functions/cloud_functions.dart';

class ListUserService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<Map<String, dynamic>>> listUsers() async {
    try {
      final result = await _functions.httpsCallable('listUsers').call();

      final Map<String, dynamic> mapData = Map<String, dynamic>.from(
        result.data as Map,
      );

      final List<dynamic> rawUsers = mapData['users'] as List<dynamic>? ?? [];
      return rawUsers
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList(growable: false);
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }
}
