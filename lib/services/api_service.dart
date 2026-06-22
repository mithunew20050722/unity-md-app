import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String base = 'http://158.178.246.29:3000/api/app';

  // ── Ping ─────────────────────────────────────────────────────
  static Future<bool> ping() async {
    try {
      final r = await http.get(Uri.parse('$base/ping')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Register + get pair code ──────────────────────────────────
  static Future<Map<String, dynamic>> register(String phone) async {
    final r = await http.post(
      Uri.parse('$base/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 40));
    return jsonDecode(r.body);
  }

  // ── Status ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> status(String phone) async {
    final r = await http.get(
      Uri.parse('$base/status/$phone'),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── Reconnect ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> reconnect(String phone) async {
    final r = await http.post(
      Uri.parse('$base/reconnect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  }

  // ── Bot info ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> botInfo(String phone) async {
    final r = await http.get(
      Uri.parse('$base/bot/info/$phone'),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── Disconnect ────────────────────────────────────────────────
  static Future<void> disconnect(String phone) async {
    await http.post(
      Uri.parse('$base/disconnect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 10));
  }
}
