import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String userId, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': userId, 'pin': pin}),
      );
      print(pin);
      print(userId);
     
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Response body: ${response.body}');

        // Save Token Securely
        await _storage.write(key: 'jwt_token', value: data['access_token']);

        // Save User Data (optional, for offline reference)
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));

        return data;
      } else {
        throw Exception('Invalid PIN or User ID');
      }
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
