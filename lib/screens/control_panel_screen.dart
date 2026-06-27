import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show navigatorKey;

// ── API ───────────────────────────────────────────────────────
class _Api {
  static const String base = 'http://158.178.246.29:3000';
  static String? _cookie;

  static Future<Map<String, dynamic>> login(String password) async {
    final res = await http.post(Uri.parse('$base/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] == true) {
      _cookie = res.headers['set-cookie'];
    }
    return data;
  }

  static Future<Map<String, dynamic>> sendCpOtp(String phone) async {
    final res = await http.post(Uri.parse('$base/api/cp/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}))
        .timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyCpOtp(String otp) async {
    final res = await http.post(Uri.parse('$base/api/cp/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'otp': otp}))
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] == true) {
      _cookie = res.headers['set-cookie'];
    }
    return data;
  }

  static Map<String, String> get _h => {
    'Content-Type': 'application/json',
    if (_cookie != null) 'Cookie': _cookie!,
  };

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$base$path'), headers: _h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> post(String path, [Map? body]) async {
    final res = await http.post(Uri.parse('$base$path'),
        headers: _h,
        body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(Uri.parse('$base$path'), headers: _h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static void logout() => _cookie = null;
}

// ── Control Panel OTP Dialog ──────────────────────────────────
class ControlPanelPasswordDialog extends StatefulWidget {
  const ControlPanelPasswordDialog({super.key});
  @override State<ControlPanelPasswordDialog> createState() => _PWState();
}

class _PWState extends State<ControlPanelPasswordDialog> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _pwCtrl    = TextEditingController();
  bool _loading = false, _obscure = true;
  // step: 0=phone input, 1=otp input, 2=password input
  int _step = 0;
  String? _error;

  @override void dispose() {
    _phoneCtrl.dispose(); _otpCtrl.dispose(); _pwCtrl.dispose();
    super.dispose();
  }

  // Step 0 → send OTP
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 7) { setState(() => _error = 'Valid phone number enter කරන්න'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _Api.sendCpOtp(phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() { _step = 1; _loading = false; });
      } else {
        setState(() { _error = res['error'] ?? 'OTP send failed.'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Server reach වෙන්නේ නැහැ.'; _loading = false; });
    }
  }

  // Step 1 → verify OTP
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) { setState(() => _error = 'Valid OTP enter කරන්න'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _Api.verifyCpOtp(otp);
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() { _step = 2; _loading = false; });
      } else {
        setState(() { _error = res['error'] ?? 'Invalid OTP.'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Server reach වෙන්නේ නැහැ.'; _loading = false; });
    }
  }

  // Step 2 → verify password
  Future<void> _verifyPassword() async {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) { setState(() => _error = 'Password enter කරන්න'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _Api.login(pw);
      if (!mounted) return;
      if (res['ok'] == true) {
        Navigator.pop(context);
        navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ControlPanelScreen()));
      } else {
        setState(() { _error = res['error'] ?? 'Password වැරදියි.'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Server reach වෙන්නේ නැහැ.'; _loading = false; });
    }
  }

  Widget _stepIndicator() {
    final labels = ['Phone', 'OTP', 'Password'];
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) {
      final active = i == _step;
      final done   = i < _step;
      return Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? const Color(0xFF25D366)
                : active ? const Color(0xFF00E5FF).withOpacity(0.2)
                : Colors.white10,
            border: Border.all(
              color: done ? const Color(0xFF25D366)
                  : active ? const Color(0xFF00E5FF)
                  : Colors.white24, width: 1.5)),
          child: Center(child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : Text('${i+1}', style: TextStyle(
                  color: active ? const Color(0xFF00E5FF) : Colors.white38,
                  fontSize: 12, fontWeight: FontWeight.w700)))),
        if (i < 2) Container(width: 24, height: 1.5,
          color: i < _step ? const Color(0xFF25D366) : Colors.white12),
      ]);
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF080D14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.25)),
          boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.12), blurRadius: 32)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF25D366), Color(0xFF00E5FF)])),
            child: Icon(
              _step == 0 ? Icons.phone_rounded
                  : _step == 1 ? Icons.sms_rounded
                  : Icons.lock_rounded,
              color: Colors.white, size: 26)),
          const SizedBox(height: 16),
          const Text('Control Panel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            _step == 0 ? 'OTP යවන්න phone number enter කරන්න'
                : _step == 1 ? 'SMS OTP code enter කරන්න'
                : 'Dashboard password confirm කරන්න',
            style: const TextStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _stepIndicator(),
          const SizedBox(height: 20),

          // ── Step 0: Phone input ──
          if (_step == 0) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _error != null
                    ? const Color(0xFFFF4757).withOpacity(0.6)
                    : const Color(0xFF25D366).withOpacity(0.3))),
              child: TextField(
                controller: _phoneCtrl,
                autofocus: true,
                keyboardType: TextInputType.phone,
                enabled: !_loading,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '+94xxxxxxxxx',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                  prefixIcon: Icon(Icons.phone_rounded, color: Colors.white38, size: 20),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                onSubmitted: (_) => _sendOtp(),
              )),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_loading ? 'Sending...' : 'Send OTP',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              )),
          ],

          // ── Step 1: OTP input ──
          if (_step == 1) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _error != null
                    ? const Color(0xFFFF4757).withOpacity(0.6)
                    : const Color(0xFF00E5FF).withOpacity(0.3))),
              child: TextField(
                controller: _otpCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !_loading,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 18, letterSpacing: 6),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                onSubmitted: (_) => _verifyOtp(),
              )),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                onTap: _loading ? null : () => setState(() { _step = 0; _error = null; _otpCtrl.clear(); }),
                child: const Text('← Back', style: TextStyle(color: Color(0xFF4A5280), fontSize: 13))),
              GestureDetector(
                onTap: _loading ? null : _sendOtp,
                child: const Text('🔄 Resend OTP', style: TextStyle(color: Color(0xFF25D366), fontSize: 13))),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify OTP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              )),
          ],

          // ── Step 2: Password input ──
          if (_step == 2) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _error != null
                    ? const Color(0xFFFF4757).withOpacity(0.6)
                    : const Color(0xFF25D366).withOpacity(0.3))),
              child: TextField(
                controller: _pwCtrl,
                autofocus: true,
                obscureText: _obscure,
                enabled: !_loading,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Dashboard password...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white38, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.white38, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                onSubmitted: (_) => _verifyPassword(),
              )),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              )),
          ],

          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4757), size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12))),
            ])],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 13))),
        ]),
      ),
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────
class ControlPanelScreen extends StatefulWidget {
  const ControlPanelScreen({super.key});
  @override State<ControlPanelScreen> createState() => _CPScreenState();
}

class _CPScreenState extends State<ControlPanelScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020408), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () { _Api.logout(); Navigator.pop(context); }),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF00E5FF)]),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('CONTROL PANEL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1))),
      ),
      body: IndexedStack(index: _tab, children: const [
        _OverviewTab(), _SessionsTab(), _UsersTab(), _GroupsTab(), _BroadcastTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF060A14),
        indicatorColor: const Color(0xFF25D366).withOpacity(0.2),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.phone_android_rounded), label: 'Sessions'),
          NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.group_rounded), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.campaign_rounded), label: 'Broadcast'),
        ],
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map? _status;
  Map? _stats;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([_Api.get('/api/status'), _Api.get('/api/stats')]);
      if (mounted) setState(() { _status = results[0]; _stats = results[1]; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtUptime(dynamic secs) {
    if (secs == null) return '-';
    final s = (secs as num).toInt();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  String _fmtRam(dynamic bytes) {
    if (bytes == null) return '-';
    return '${((bytes as num) / 1024 / 1024).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errWidget(_error!, _load);

    final sessions = _status?['sessions'] as Map? ?? {};
    final total = sessions['total'] ?? 0;
    final connected = sessions['connected'] ?? 0;
    final users = _status?['users'] ?? _stats?['users'] ?? 0;
    final groups = _status?['groups'] ?? _stats?['groups'] ?? 0;
    final uptime = _fmtUptime(_status?['uptime']);
    final ram = _fmtRam(_status?['memory']);

    return RefreshIndicator(
      color: const Color(0xFF25D366), onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Sessions status card
        _card(child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: connected > 0 ? const Color(0xFF25D366).withOpacity(0.15) : const Color(0xFFFF4757).withOpacity(0.15)),
            child: Icon(connected > 0 ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: connected > 0 ? const Color(0xFF25D366) : const Color(0xFFFF4757), size: 26)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(connected > 0 ? '$connected Active Session${connected > 1 ? "s" : ""}' : 'No Active Sessions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: connected > 0 ? const Color(0xFF25D366) : const Color(0xFFFF4757))),
            Text('$total total sessions',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
        ])),
        const SizedBox(height: 12),

        // Stats grid
        GridView.count(crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.7,
          children: [
            _statCard('Connected', '$connected', Icons.phone_android_rounded, const Color(0xFF25D366)),
            _statCard('Total Sessions', '$total', Icons.people_alt_rounded, const Color(0xFF00E5FF)),
            _statCard('Users', '$users', Icons.person_rounded, const Color(0xFFFF9F43)),
            _statCard('Groups', '$groups', Icons.group_rounded, const Color(0xFFa29bfe)),
          ]),
        const SizedBox(height: 12),

        // System
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('System', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _sysRow(Icons.timer_rounded, 'Uptime', uptime, const Color(0xFF00E5FF))),
            Expanded(child: _sysRow(Icons.memory_rounded, 'RAM', ram, const Color(0xFFFF9F43))),
          ]),
        ])),
        const SizedBox(height: 12),

        // Weekly stats
        if (_stats?['stats'] != null && (_stats!['stats'] as List).isNotEmpty) ...[
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This Week', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...(_stats!['stats'] as List).take(3).map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text(s['date'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                Text('${s['commands'] ?? 0} cmds',
                  style: const TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )),
          ])),
          const SizedBox(height: 12),
        ],

        // Restart
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _restart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4757).withOpacity(0.12),
            foregroundColor: const Color(0xFFFF4757),
            side: const BorderSide(color: Color(0xFFFF4757)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restart Server', style: TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    );
  }

  Widget _sysRow(IconData icon, String label, String val, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    ]);
  }

  Future<void> _restart() async {
    final ok = await _confirmDialog(context, 'Restart?', 'Server restart වෙනවා.');
    if (ok != true) return;
    await _Api.post('/api/sessions/${_status?['sessions']}/restart').catchError((_) => <String,dynamic>{});
    if (mounted) _showSnack(context, '🔄 Server restarting...', const Color(0xFF25D366));
  }
}

// ── Sessions Tab ──────────────────────────────────────────────
class _SessionsTab extends StatefulWidget {
  const _SessionsTab();
  @override State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  List _sessions = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _Api.get('/api/sessions');
      if (mounted) setState(() { _sessions = data['sessions'] ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _action(String userId, String action) async {
    try {
      if (action == 'remove') {
        final ok = await _confirmDialog(context, 'Remove?', 'Session සම්පූර්ණයෙන් delete වෙනවා.');
        if (ok != true) return;
        await _Api.post('/api/sessions/$userId/remove');
      } else if (action == 'block') {
        final ok = await _confirmDialog(context, 'Block?', '+$userId block වෙනවා.');
        if (ok != true) return;
        await _Api.post('/api/sessions/$userId/block');
      } else if (action == 'unblock') {
        await _Api.post('/api/sessions/$userId/unblock');
      } else if (action == 'stop') {
        await _Api.post('/api/sessions/$userId/stop');
      } else if (action == 'restart') {
        await _Api.post('/api/sessions/$userId/restart');
      }
      if (mounted) _showSnack(context, '✅ Done', const Color(0xFF25D366));
      _load();
    } catch (e) {
      if (mounted) _showSnack(context, '❌ Error: $e', const Color(0xFFFF4757));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'connected': return const Color(0xFF25D366);
      case 'pairing': return const Color(0xFFFF9F43);
      case 'blocked': return const Color(0xFFFF4757);
      default: return Colors.white38;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'connected': return Icons.check_circle_rounded;
      case 'pairing': return Icons.sync_rounded;
      case 'blocked': return Icons.block_rounded;
      default: return Icons.pause_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errWidget(_error!, _load);
    if (_sessions.isEmpty) return _emptyWidget('Sessions නෑ');

    return RefreshIndicator(
      color: const Color(0xFF25D366), onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _sessions.length,
        itemBuilder: (_, i) {
          final s = _sessions[i] as Map;
          final userId = s['userId'] as String? ?? '';
          final status = s['status'] as String? ?? 'stopped';
          final isBlocked = s['isBlocked'] == true;
          final isStopped = s['isStopped'] == true;
          final name = s['name'] as String? ?? '';
          final color = _statusColor(status);

          return _card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
                  child: Icon(_statusIcon(status), color: color, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('+$userId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  if (name.isNotEmpty)
                    Text(name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.35))),
                  child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 12),
              // Action buttons
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (isStopped)
                  _actionBtn('Start', Icons.play_arrow_rounded, const Color(0xFF25D366), () => _action(userId, 'restart')),
                if (!isStopped && !isBlocked)
                  _actionBtn('Stop', Icons.pause_rounded, Colors.white38, () => _action(userId, 'stop')),
                if (!isStopped && !isBlocked)
                  _actionBtn('Restart', Icons.restart_alt_rounded, const Color(0xFF00E5FF), () => _action(userId, 'restart')),
                if (isBlocked)
                  _actionBtn('Unblock', Icons.lock_open_rounded, const Color(0xFF25D366), () => _action(userId, 'unblock'))
                else
                  _actionBtn('Block', Icons.block_rounded, const Color(0xFFFF9F43), () => _action(userId, 'block')),
                _actionBtn('Remove', Icons.delete_rounded, const Color(0xFFFF4757), () => _action(userId, 'remove')),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Users Tab ─────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List _users = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _Api.get('/api/users');
      if (mounted) setState(() { _users = data['users'] ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errWidget(_error!, _load);
    if (_users.isEmpty) return _emptyWidget('Users නෑ');

    return RefreshIndicator(
      color: const Color(0xFF25D366), onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i] as Map;
          final jid = u['jid'] as String? ?? '';
          final num = jid.split('@').first;
          final cmds = u['totalCommands'] ?? 0;
          final banned = u['banned'] == true;

          return _card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                child: Text(num.isNotEmpty ? num[0] : '?',
                  style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('+$num', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('$cmds commands used', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ])),
              if (banned) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFF4757).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('Banned', style: TextStyle(color: Color(0xFFFF4757), fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
          );
        },
      ),
    );
  }
}

// ── Groups Tab ────────────────────────────────────────────────
class _GroupsTab extends StatefulWidget {
  const _GroupsTab();
  @override State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  List _groups = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _Api.get('/api/groups');
      if (mounted) setState(() { _groups = data['groups'] ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errWidget(_error!, _load);
    if (_groups.isEmpty) return _emptyWidget('Groups නෑ');

    return RefreshIndicator(
      color: const Color(0xFF25D366), onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final g = _groups[i] as Map;
          final name = g['name'] as String? ?? g['jid'] as String? ?? 'Unknown';
          final jid = g['jid'] as String? ?? '';
          final cmds = g['totalCommands'] ?? 0;

          return _card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF00E5FF).withOpacity(0.1)),
                child: const Icon(Icons.group_rounded, color: Color(0xFF00E5FF), size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$cmds commands', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ])),
            ]),
          );
        },
      ),
    );
  }
}

// ── Broadcast Tab ─────────────────────────────────────────────
class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();
  @override State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _ctrl = TextEditingController();
  String _type = 'all';
  bool _loading = false;
  String? _result;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    setState(() { _loading = true; _result = null; });
    try {
      final res = await _Api.post('/api/broadcast', {'message': msg, 'type': _type});
      if (mounted) setState(() {
        _result = res['success'] == true
            ? '✅ Broadcasting to ${res['sessions'] ?? '?'} sessions!'
            : '❌ ${res['error']}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _result = '❌ Server error'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Broadcast Message',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 4),
      const Text('සියලු sessions හරහා message send කරනවා.',
        style: TextStyle(color: Colors.white38, fontSize: 13)),
      const SizedBox(height: 20),

      // Type selector
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Send to', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final t in [('all', 'All'), ('groups', 'Groups'), ('private', 'Private'), ('connected', 'Self')])
            ChoiceChip(
              label: Text(t.$2),
              selected: _type == t.$1,
              onSelected: (_) => setState(() => _type = t.$1),
              selectedColor: const Color(0xFF25D366).withOpacity(0.2),
              side: BorderSide(color: _type == t.$1 ? const Color(0xFF25D366) : Colors.white12),
              labelStyle: TextStyle(color: _type == t.$1 ? const Color(0xFF25D366) : Colors.white54,
                fontWeight: FontWeight.w600, fontSize: 12),
              backgroundColor: Colors.transparent,
              showCheckmark: false,
            ),
        ]),
      ])),
      const SizedBox(height: 12),

      Container(
        decoration: BoxDecoration(color: const Color(0xFF0F1520),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2))),
        child: TextField(controller: _ctrl, maxLines: 6, enabled: !_loading,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Message type කරන්න...',
            hintStyle: TextStyle(color: Colors.white30),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16)))),
      const SizedBox(height: 16),

      ElevatedButton.icon(
        onPressed: _loading ? null : _send,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
        icon: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded),
        label: Text(_loading ? 'Sending...' : 'Send Broadcast',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),

      if (_result != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _result!.startsWith('✅') ? const Color(0xFF25D366).withOpacity(0.1) : const Color(0xFFFF4757).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _result!.startsWith('✅')
                ? const Color(0xFF25D366).withOpacity(0.3) : const Color(0xFFFF4757).withOpacity(0.3))),
          child: Text(_result!, style: TextStyle(
            color: _result!.startsWith('✅') ? const Color(0xFF25D366) : const Color(0xFFFF4757),
            fontWeight: FontWeight.w600))),
      ],
    ]);
  }
}

// ── Shared helpers ────────────────────────────────────────────
Widget _card({required Widget child, EdgeInsets? margin}) => Container(
  margin: margin,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: const Color(0xFF060A14),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.07))),
  child: child);

Widget _statCard(String label, String val, IconData icon, Color color) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(color: const Color(0xFF060A14),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.07))),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: color, size: 20),
    const Spacer(),
    Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
  ]));

Widget _errWidget(String e, VoidCallback retry) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
  const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
  const SizedBox(height: 12),
  Text(e, style: const TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
  const SizedBox(height: 16),
  ElevatedButton(onPressed: retry,
    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
    child: const Text('Retry')),
]));

Widget _emptyWidget(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
  const Icon(Icons.inbox_rounded, color: Colors.white24, size: 48),
  const SizedBox(height: 12),
  Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 14)),
]));

Future<bool?> _confirmDialog(BuildContext context, String title, String body) =>
  showDialog<bool>(context: context, builder: (_) => AlertDialog(
    backgroundColor: const Color(0xFF080D14),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    content: Text(body, style: const TextStyle(color: Colors.white54)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
      ElevatedButton(onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4757)),
        child: const Text('Confirm')),
    ]));

void _showSnack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)));
}
