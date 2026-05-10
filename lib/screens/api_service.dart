import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _base   = 'https://unity.up.railway.app/api/app';
  // Must match APP_SECRET in Railway environment variables
  static const String _secret = 'unity_md_2025_@secret#key';

  static Map<String, String> get _headers => {
    'Content-Type':  'application/json',
    'x-app-secret':  _secret,
  };

  static Future<bool> ping() async {
    try {
      final r = await http.get(Uri.parse('$_base/ping'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<Map<String, dynamic>> register(String phone) async {
    final r = await http.post(
      Uri.parse('$_base/register'),
      headers: _headers,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 40));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> status(String phone) async {
    final r = await http.get(
      Uri.parse('$_base/status/$phone'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> reconnect(String phone) async {
    final r = await http.post(
      Uri.parse('$_base/reconnect'),
      headers: _headers,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> botInfo(String phone) async {
    final r = await http.get(
      Uri.parse('$_base/bot/info/$phone'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  static Future<void> disconnect(String phone) async {
    await http.post(
      Uri.parse('$_base/disconnect'),
      headers: _headers,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 10));
  }
}
