import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String base = 'http://158.178.246.29:3000/api/app';
  static const String pair = 'http://158.178.246.29:3000/api/pair';

  // ── Auth header (backend requires x-app-secret) ────────────
  static const Map<String, String> _h = {
    'Content-Type':  'application/json',
    'x-app-secret':  'unity_md_2025_@secret#key',
  };

  // ── Ping ───────────────────────────────────────────────────
  static Future<bool> ping() async {
    try {
      final r = await http.get(Uri.parse('$base/ping'), headers: _h)
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Register + get pair code ───────────────────────────────
  static Future<Map<String, dynamic>> register(String phone) async {
    final r = await http.post(
      Uri.parse('$base/register'),
      headers: _h,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 40));
    return jsonDecode(r.body);
  }

  // ── Status ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> status(String phone) async {
    final r = await http.get(Uri.parse('$base/status/$phone'), headers: _h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── Reconnect ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> reconnect(String phone) async {
    final r = await http.post(
      Uri.parse('$base/reconnect'),
      headers: _h,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  }

  // ── Restart ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> restart(String phone) async {
    final r = await http.post(
      Uri.parse('$base/restart'),
      headers: _h,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 20));
    return jsonDecode(r.body);
  }

  // ── Bot info ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> botInfo(String phone) async {
    final r = await http.get(Uri.parse('$base/bot/info/$phone'), headers: _h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── Disconnect ─────────────────────────────────────────────
  static Future<void> disconnect(String phone) async {
    await http.post(
      Uri.parse('$base/disconnect'),
      headers: _h,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 10));
  }

  // ── Settings: request password via WhatsApp ────────────────
  static Future<Map<String, dynamic>> resendSettingsPassword(String phone) async {
    final r = await http.post(
      Uri.parse('$pair/resend-password/$phone'),
      headers: _h,
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  }

  // ── Settings: verify password ──────────────────────────────
  static Future<Map<String, dynamic>> verifySettingsPassword(
      String phone, String password) async {
    final r = await http.post(
      Uri.parse('$pair/verify/$phone'),
      headers: _h,
      body: jsonEncode({'password': password}),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── Settings: get current settings ────────────────────────
  static Future<Map<String, dynamic>> getSettings(String phone) async {
    final r = await http.get(
      Uri.parse('$pair/settings/$phone'),
      headers: _h,
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── Settings: save + restart ───────────────────────────────
  static Future<Map<String, dynamic>> saveSettings(
    String phone, {
    required String mode,
    required bool maintenance,
    required Map<String, dynamic> features,
    required Map<String, bool> commands,
  }) async {
    final r = await http.post(
      Uri.parse('$pair/settings/$phone'),
      headers: _h,
      body: jsonEncode({
        'mode':        mode,
        'maintenance': maintenance,
        'features':    features,
        'commands':    commands,
      }),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  // ── App Chat: setup group ──────────────────────────────────
  static Future<Map<String, dynamic>> chatSetup(String phone) async {
    final r = await http.post(
      Uri.parse('$base/chat/setup'),
      headers: _h,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 20));
    return jsonDecode(r.body);
  }

  // ── App Chat: get JID ──────────────────────────────────────
  static Future<Map<String, dynamic>> chatJid(String phone) async {
    final r = await http.get(Uri.parse('$base/chat/jid/$phone'), headers: _h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── App Chat: send message ─────────────────────────────────
  static Future<Map<String, dynamic>> chatSend(String phone, String text) async {
    final r = await http.post(
      Uri.parse('$base/chat/send'),
      headers: _h,
      body: jsonEncode({'phone': phone, 'text': text}),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── App Chat: get messages ─────────────────────────────────
  static Future<Map<String, dynamic>> chatMessages(String phone) async {
    final r = await http.get(Uri.parse('$base/chat/messages/$phone'), headers: _h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(r.body);
  }

  // ── OTP: check if bot already connected ──────────────────────
  static Future<Map<String, dynamic>> checkBotConnected(String phone) async {
    try {
      final r = await http.get(Uri.parse('$base/status/$phone'), headers: _h)
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(r.body);
      return {'botConnected': body['status'] == 'connected'};
    } catch (_) {
      return {'botConnected': false};
    }
  }

  // ── OTP: send OTP via bot to owner inbox ──────────────────────
  static Future<void> sendOtp(String phone) async {
    await http.post(
      Uri.parse('$base/otp/send'),
      headers: _h,
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 15));
  }

  // ── OTP: verify OTP ───────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final r = await http.post(
      Uri.parse('$base/otp/verify'),
      headers: _h,
      body: jsonEncode({'phone': phone, 'otp': otp}),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body);
  }
}

