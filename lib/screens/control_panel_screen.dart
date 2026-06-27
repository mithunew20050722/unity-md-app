import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show navigatorKey;

// ── API helper ────────────────────────────────────────────────
class _PanelApi {
  static const String base = 'http://158.178.246.29:3000';
  static String? _cookie;

  static Future<Map<String, dynamic>> login(String password) async {
    final res = await http.post(
      Uri.parse('$base/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      _cookie = res.headers['set-cookie'];
    }
    return data;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_cookie != null) 'Cookie': _cookie!,
  };

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$base$path'), headers: _headers);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> post(String path, [Map? body]) async {
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static void logout() => _cookie = null;
}

// ── Password Dialog (called from FAB) ────────────────────────
class ControlPanelPasswordDialog extends StatefulWidget {
  const ControlPanelPasswordDialog({super.key});
  @override State<ControlPanelPasswordDialog> createState() => _CPPasswordState();
}

class _CPPasswordState extends State<ControlPanelPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final pw = _ctrl.text.trim();
    if (pw.isEmpty) { setState(() => _error = 'Password enter කරන්න'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _PanelApi.login(pw);
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
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF25D366), Color(0xFF00E5FF)]),
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 16),
          const Text('Control Panel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Dashboard password enter කරන්න', style: TextStyle(fontSize: 13, color: Colors.white54)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1520),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _error != null
                  ? const Color(0xFFFF4757).withOpacity(0.6)
                  : const Color(0xFF25D366).withOpacity(0.2)),
            ),
            child: TextField(
              controller: _ctrl, obscureText: _obscure, enabled: !_loading, autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Enter password...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _login(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4757), size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12))),
            ]),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── Main Control Panel Screen ─────────────────────────────────
class ControlPanelScreen extends StatefulWidget {
  const ControlPanelScreen({super.key});
  @override State<ControlPanelScreen> createState() => _ControlPanelScreenState();
}

class _ControlPanelScreenState extends State<ControlPanelScreen> {
  int _tab = 0;
  final _tabs = ['Dashboard', 'Users', 'Groups', 'Broadcast'];
  final _icons = [Icons.dashboard_rounded, Icons.people_rounded,
                  Icons.group_rounded, Icons.campaign_rounded];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020408),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () { _PanelApi.logout(); Navigator.pop(context); },
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF00E5FF)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('CONTROL PANEL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          ),
        ]),
      ),
      body: IndexedStack(index: _tab, children: const [
        _DashboardTab(),
        _UsersTab(),
        _GroupsTab(),
        _BroadcastTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF060A14),
        indicatorColor: const Color(0xFF25D366).withOpacity(0.2),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: List.generate(_tabs.length, (i) => NavigationDestination(
          icon: Icon(_icons[i], color: Colors.white38),
          selectedIcon: Icon(_icons[i], color: const Color(0xFF25D366)),
          label: _tabs[i],
        )),
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _PanelApi.get('/api/status');
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errorWidget(_error!, _load);
    final d = _data!;
    final online = d['online'] == true;
    return RefreshIndicator(
      color: const Color(0xFF25D366),
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Status card
        _card(child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (online ? const Color(0xFF25D366) : const Color(0xFFFF4757)).withOpacity(0.15),
            ),
            child: Icon(online ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: online ? const Color(0xFF25D366) : const Color(0xFFFF4757), size: 26),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(online ? 'Bot Online' : 'Bot Offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: online ? const Color(0xFF25D366) : const Color(0xFFFF4757))),
            Text(d['botName'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
        ])),
        const SizedBox(height: 12),
        // Stats grid
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
          children: [
            _statCard('Uptime', d['uptimeStr'] ?? '-', Icons.timer_rounded, const Color(0xFF00E5FF)),
            _statCard('RAM', '${d['ram'] ?? '-'} MB', Icons.memory_rounded, const Color(0xFFFF9F43)),
            _statCard('Commands', '${d['commands'] ?? '-'}', Icons.code_rounded, const Color(0xFF25D366)),
            _statCard('Node', d['nodeVersion'] ?? '-', Icons.developer_mode_rounded, const Color(0xFFa29bfe)),
          ],
        ),
        const SizedBox(height: 12),
        // Bot number
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bot Number', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(d['botNumber'] ?? '-', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(height: 12),
        // Restart button
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _restart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4757).withOpacity(0.15),
            foregroundColor: const Color(0xFFFF4757),
            side: const BorderSide(color: Color(0xFFFF4757), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restart Bot', style: TextStyle(fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF080D14),
        title: const Text('Restart?', style: TextStyle(color: Colors.white)),
        content: const Text('Bot restart වෙනවා.', style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4757)),
              child: const Text('Restart')),
        ],
      ),
    );
    if (ok == true) {
      await _PanelApi.post('/api/restart');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bot restarting...'), backgroundColor: Color(0xFF25D366)));
    }
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _PanelApi.get('/api/users');
      if (mounted) setState(() { _users = data['users'] ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleBan(String jid, bool banned) async {
    final path = banned ? '/api/users/${Uri.encodeComponent(jid)}/unban'
                        : '/api/users/${Uri.encodeComponent(jid)}/ban';
    await _PanelApi.post(path);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errorWidget(_error!, _load);
    return RefreshIndicator(
      color: const Color(0xFF25D366),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i] as Map;
          final jid = u['jid'] as String? ?? '';
          final banned = u['banned'] == true;
          final num = jid.split('@').first;
          return _card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF25D366).withOpacity(0.15),
                child: Text(num.length > 1 ? num[0] : '?',
                    style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('+$num', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('${u['totalCommands'] ?? 0} commands',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ])),
              if (banned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.4)),
                  ),
                  child: const Text('Banned', style: TextStyle(color: Color(0xFFFF4757), fontSize: 11)),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(banned ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: banned ? const Color(0xFF25D366) : const Color(0xFFFF4757), size: 20),
                onPressed: () => _toggleBan(jid, banned),
              ),
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _PanelApi.get('/api/groups');
      if (mounted) setState(() { _groups = data['groups'] ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    if (_error != null) return _errorWidget(_error!, _load);
    return RefreshIndicator(
      color: const Color(0xFF25D366),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final g = _groups[i] as Map;
          return _card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                ),
                child: const Icon(Icons.group_rounded, color: Color(0xFF00E5FF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${g['members'] ?? 0} members · ${g['admins'] ?? 0} admins',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
  bool _loading = false;
  String? _result;

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    setState(() { _loading = true; _result = null; });
    try {
      final res = await _PanelApi.post('/api/broadcast', {'message': msg});
      if (mounted) setState(() {
        _result = res['success'] == true
            ? '✅ Sent to ${res['sent']} groups!'
            : '❌ ${res['error']}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _result = '❌ Server error'; _loading = false; });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Broadcast Message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('සියලු groups වලට message send කරනවා.',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1520),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2)),
          ),
          child: TextField(
            controller: _ctrl, maxLines: 6, enabled: !_loading,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Message type කරන්න...',
              hintStyle: TextStyle(color: Colors.white30),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _loading ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded),
          label: Text(_loading ? 'Sending...' : 'Send Broadcast',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
        if (_result != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _result!.startsWith('✅')
                  ? const Color(0xFF25D366).withOpacity(0.1)
                  : const Color(0xFFFF4757).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _result!.startsWith('✅')
                    ? const Color(0xFF25D366).withOpacity(0.3)
                    : const Color(0xFFFF4757).withOpacity(0.3),
              ),
            ),
            child: Text(_result!, style: TextStyle(
              color: _result!.startsWith('✅') ? const Color(0xFF25D366) : const Color(0xFFFF4757),
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ]),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────
Widget _card({required Widget child, EdgeInsets? margin}) {
  return Container(
    margin: margin,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF060A14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: child,
  );
}

Widget _statCard(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF060A14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
    ]),
  );
}

Widget _errorWidget(String error, VoidCallback retry) {
  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
    const SizedBox(height: 12),
    Text(error, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: retry,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
        child: const Text('Retry')),
  ]));
}
