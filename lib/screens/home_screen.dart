import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';
import 'chat_screen.dart';

// ─── Particle ─────────────────────────────────────────────────
class _Particle {
  double x, y, r, speed, opacity;
  _Particle(Random rng)
      : x       = rng.nextDouble(),
        y       = rng.nextDouble(),
        r       = rng.nextDouble() * 2 + 1,
        speed   = rng.nextDouble() * 0.0008 + 0.0003,
        opacity = rng.nextDouble() * 0.3 + 0.07;
  void tick() { y -= speed; if (y < -0.02) y = 1.02; }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> pts;
  _ParticlePainter(this.pts);
  @override
  void paint(Canvas c, Size s) {
    for (final p in pts) {
      c.drawCircle(Offset(p.x * s.width, p.y * s.height), p.r,
          Paint()..color = const Color(0xFF25D366).withOpacity(p.opacity));
    }
  }
  @override bool shouldRepaint(_) => true;
}

// ─── Home Screen ──────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final String phone;
  const HomeScreen({super.key, required this.phone});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _status    = 'connecting';
  int?   _uptime;           // seconds from server
  int    _cmds      = 0;
  bool   _pingOk    = false; // live ping indicator
  int    _liveRt    = 0;     // live runtime ticking locally (seconds)
  DateTime? _rtBase;         // when we last got uptime from server

  Timer? _pollTimer, _particleTimer, _pingTimer, _rtTimer;
  final _rng = Random();
  late List<_Particle> _particles;
  late AnimationController _glowCtrl;
  late Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(28, (_) => _Particle(_rng));
    _glowCtrl  = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      for (final p in _particles) p.tick();
      setState(() {});
    });
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());

    // Live ping every 5s
    _doPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _doPing());

    // Live runtime ticker every second
    _rtTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_rtBase != null) {
        setState(() {
          _liveRt = (_uptime ?? 0) +
              DateTime.now().difference(_rtBase!).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _particleTimer?.cancel();
    _pingTimer?.cancel();
    _rtTimer?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await ApiService.botInfo(widget.phone);
      if (!mounted) return;
      setState(() {
        _status  = info['status'] ?? 'disconnected';
        _uptime  = info['uptime'];
        _cmds    = info['commandCount'] ?? 0;
        _rtBase  = DateTime.now();   // reset live ticker base
        _liveRt  = _uptime ?? 0;
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'disconnected');
    }
  }

  // ── Ping ───────────────────────────────────────────────────
  Future<void> _doPing() async {
    final ok = await ApiService.ping();
    if (mounted) setState(() => _pingOk = ok);
  }

  // ── Restart ────────────────────────────────────────────────
  Future<void> _restart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _confirmDialog(
        title: 'Restart Bot',
        body: 'Bot will restart. This takes ~10 seconds.',
        confirmLabel: 'Restart',
        confirmColor: const Color(0xFF00E5FF),
      ),
    );
    if (confirmed != true) return;

    setState(() => _status = 'connecting');
    try {
      await ApiService.restart(widget.phone);
      _snack('Bot restarting...', const Color(0xFF00E5FF));
      await Future.delayed(const Duration(seconds: 5));
      _load();
    } catch (_) {
      _snack('Restart failed.', const Color(0xFFFF4757));
      _load();
    }
  }

  // ── Disconnect ─────────────────────────────────────────────
  Future<void> _confirmDisconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _confirmDialog(
        title: langNotifier.lang.disconnectTitle,
        body: langNotifier.lang.disconnectBody,
        confirmLabel: langNotifier.lang.disconnect,
        confirmColor: const Color(0xFFFF4757),
      ),
    );
    if (ok != true) return;
    try { await ApiService.disconnect(widget.phone); } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('phone');
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  // ── Settings panel ─────────────────────────────────────────
  void _openSettings() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsSheet(phone: widget.phone),
  );

  void _openChat() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChatScreen(phone: widget.phone)),
  );

  void _openContact() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactSheet(l: langNotifier.lang),
  );

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'monospace')),
      backgroundColor: c,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _confirmDialog({
    required String title, required String body,
    required String confirmLabel, required Color confirmColor,
  }) => AlertDialog(
    backgroundColor: const Color(0xFF0D1117),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: confirmColor.withOpacity(0.2))),
    title: Text(title, style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.w700)),
    content: Text(body, style: const TextStyle(color: Colors.white60)),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(langNotifier.lang.cancel,
              style: const TextStyle(color: Colors.white38))),
      TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: TextStyle(color: confirmColor,
                  fontWeight: FontWeight.w700))),
    ],
  );

  Color get _col {
    switch (_status) {
      case 'connected':  return const Color(0xFF25D366);
      case 'pairing':    return const Color(0xFFFFD93D);
      case 'error':      return const Color(0xFFFF4757);
      default:           return const Color(0xFF4A5280);
    }
  }

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  static const _fColors = [
    Color(0xFF25D366), Color(0xFF00E5FF),
    Color(0xFFA259FF), Color(0xFFFFD93D),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langNotifier,
      builder: (_, __) {
        final l = langNotifier.lang;
        return Scaffold(
          backgroundColor: const Color(0xFF020408),
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(l),
          body: Stack(children: [
            Positioned.fill(child: CustomPaint(
                painter: _ParticlePainter(_particles))),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Stack(children: [
                Positioned(top: -80 + _glowAnim.value * 20, left: -80,
                    child: _glow(const Color(0xFF25D366),
                        240 + _glowAnim.value * 20)),
                Positioned(bottom: -80, right: -80,
                    child: _glow(const Color(0xFF00E5FF),
                        180 + _glowAnim.value * 20)),
                Positioned(
                    top: MediaQuery.of(context).size.height * 0.45,
                    left: MediaQuery.of(context).size.width * 0.3,
                    child: _glow(const Color(0xFFA259FF),
                        100 + _glowAnim.value * 10)),
              ]),
            ),
            RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF25D366),
              backgroundColor: const Color(0xFF060A14),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 72,
                    20, 40),
                children: [
                  _statusCard(l),
                  const SizedBox(height: 14),
                  _statsRow(l),
                  const SizedBox(height: 20),
                  // ── Quick Actions ──────────────────────────
                  _sectionLabel('QUICK ACTIONS'),
                  const SizedBox(height: 12),
                  _quickActions(l),
                  const SizedBox(height: 24),
                  // ── Features ──────────────────────────────
                  _sectionLabel('FEATURES'),
                  const SizedBox(height: 12),
                  ..._featureCards(l),
                  const SizedBox(height: 20),
                  _tipCard(l),
                  const SizedBox(height: 16),
                  _contactBtn(l),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(fontFamily: 'monospace',
          fontSize: 10, letterSpacing: 3, color: Color(0xFF4A5280)));

  // ── AppBar ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(l) => AppBar(
    backgroundColor: const Color(0xFF030610).withOpacity(0.92),
    elevation: 0,
    leading: Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.3)),
          boxShadow: [BoxShadow(
              color: const Color(0xFF25D366).withOpacity(0.2),
              blurRadius: 8)],
        ),
        child: ClipOval(child: Image.asset('assets/icon.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF060A14),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF25D366), size: 22)))),
      ),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF00E5FF)])
              .createShader(r),
          child: const Text('UNITY-MD',
              style: TextStyle(fontFamily: 'monospace', fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3, color: Colors.white)),
        ),
        const Text('® UNITY TEAM',
            style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                color: Color(0xFF4A5280), letterSpacing: 2)),
      ]),
    actions: [
      GestureDetector(
        onTap: () => langNotifier.toggle(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.25)),
          ),
          child: Text(
            langNotifier.lang.isSinhala ? '🇱🇰 SI' : '🇬🇧 EN',
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 10, color: Color(0xFF25D366))),
        ),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert,
            color: Colors.white38, size: 20),
        color: const Color(0xFF060A14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: const Color(0xFF25D366).withOpacity(0.1)),
        ),
        onSelected: (v) {
          if (v == 'dc')       _confirmDisconnect();
          if (v == 'contact')  _openContact();
          if (v == 'refresh')  _load();
          if (v == 'chat')     _openChat();
          if (v == 'settings') _openSettings();
          if (v == 'restart')  _restart();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'refresh',
              child: _menuRow(Icons.refresh_rounded,
                  const Color(0xFF00E5FF), 'Refresh')),
          PopupMenuItem(value: 'chat',
              child: _menuRow(Icons.chat_bubble_rounded,
                  const Color(0xFF25D366), 'Bot Chat')),
          PopupMenuItem(value: 'settings',
              child: _menuRow(Icons.tune_rounded,
                  const Color(0xFFA259FF), 'Bot Settings')),
          PopupMenuItem(value: 'restart',
              child: _menuRow(Icons.restart_alt_rounded,
                  const Color(0xFFFFD93D), 'Restart Bot')),
          PopupMenuItem(value: 'contact',
              child: _menuRow(Icons.people_alt_rounded,
                  const Color(0xFF25D366), l.contactUs)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'dc',
              child: _menuRow(Icons.link_off_rounded,
                  const Color(0xFFFF4757), l.disconnect)),
        ],
      ),
    ],
  );

  Widget _menuRow(IconData icon, Color c, String label) =>
      Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: c, size: 17)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 14)),
      ]);

  // ── Status card ────────────────────────────────────────────
  Widget _statusCard(l) => AnimatedBuilder(
    animation: _glowAnim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _col.withOpacity(0.09 + _glowAnim.value * 0.04),
            const Color(0xFF060A14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _col.withOpacity(0.22)),
        boxShadow: [BoxShadow(
            color: _col.withOpacity(0.08 + _glowAnim.value * 0.05),
            blurRadius: 32, spreadRadius: 4)],
      ),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Container(width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _col.withOpacity(
                      0.06 + _glowAnim.value * 0.07))),
          Container(width: 14, height: 14,
              decoration: BoxDecoration(
                  color: _col, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: _col.withOpacity(0.7),
                      blurRadius: 12, spreadRadius: 2)])),
        ]),
        const SizedBox(height: 14),
        Text(l.statusLabel(_status),
            style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: _col)),
        const SizedBox(height: 4),
        Text('+${widget.phone}',
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 13, color: Colors.white24, letterSpacing: 1)),
      ]),
    ),
  );

  // ── Stats row ──────────────────────────────────────────────
  Widget _statsRow(l) => Column(children: [
    // Ping indicator bar
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF060A14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (_pingOk
                ? const Color(0xFF25D366)
                : const Color(0xFFFF4757)).withOpacity(0.2)),
      ),
      child: Row(children: [
        // Animated ping dot
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (_, v, __) => Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pingOk
                  ? const Color(0xFF25D366)
                  : const Color(0xFFFF4757),
              boxShadow: [BoxShadow(
                  color: (_pingOk
                      ? const Color(0xFF25D366)
                      : const Color(0xFFFF4757)).withOpacity(v * 0.8),
                  blurRadius: 8, spreadRadius: 1)],
            ),
          ),
          onEnd: () => setState(() {}),
        ),
        const SizedBox(width: 10),
        Text(
          _pingOk ? 'SERVER ONLINE' : 'SERVER OFFLINE',
          style: TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: _pingOk
                  ? const Color(0xFF25D366)
                  : const Color(0xFFFF4757)),
        ),
        const Spacer(),
        Text('PING',
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 9, color: Color(0xFF4A5280), letterSpacing: 2)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (_pingOk
                ? const Color(0xFF25D366)
                : const Color(0xFFFF4757)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_pingOk ? 'OK' : 'FAIL',
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _pingOk
                      ? const Color(0xFF25D366)
                      : const Color(0xFFFF4757))),
        ),
      ]),
    ),
    const SizedBox(height: 10),
    Row(children: [
      _stat('⏱️', 'RUNTIME',  _fmt(_liveRt),  const Color(0xFF00E5FF), live: true),
      const SizedBox(width: 10),
      _stat('⚡', l.commands, '$_cmds+',        const Color(0xFFFFD93D)),
      const SizedBox(width: 10),
      _stat('🛡️', l.antiBan, 'ON',             const Color(0xFF25D366)),
    ]),
  ]);

  Widget _stat(String emoji, String label, String val, Color c,
      {bool live = false}) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.12)),
        ),
        child: Column(children: [
          Stack(alignment: Alignment.topRight, children: [
            Center(child: Text(emoji,
                style: const TextStyle(fontSize: 20))),
            if (live) Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF25D366),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.8),
                    blurRadius: 6)],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontFamily: 'monospace',
              fontSize: 13, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
              fontSize: 9, color: Color(0xFF4A5280),
              fontFamily: 'monospace', letterSpacing: 1)),
        ]),
      ));

  // ── Quick action buttons ───────────────────────────────────
  Widget _quickActions(l) => Row(children: [
    _actionBtn(
      icon: Icons.tune_rounded,
      label: 'Settings',
      color: const Color(0xFFA259FF),
      onTap: _openSettings,
    ),
    const SizedBox(width: 10),
    _actionBtn(
      icon: Icons.chat_bubble_rounded,
      label: 'Chat',
      color: const Color(0xFF25D366),
      onTap: _openChat,
    ),
    const SizedBox(width: 10),
    _actionBtn(
      icon: Icons.restart_alt_rounded,
      label: 'Restart',
      color: const Color(0xFFFFD93D),
      onTap: _restart,
    ),
    const SizedBox(width: 10),
    _actionBtn(
      icon: Icons.link_off_rounded,
      label: 'Disconnect',
      color: const Color(0xFFFF4757),
      onTap: _confirmDisconnect,
    ),
  ]);

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
            color: color, fontSize: 9,
            fontFamily: 'monospace', fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      ]),
    ),
  ));

  // ── Feature cards ──────────────────────────────────────────
  List<Widget> _featureCards(l) =>
      l.featureCards.asMap().entries.map<Widget>((e) {
        final i = e.key;
        final v = e.value;
        final c = _fColors[i % _fColors.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withOpacity(0.13)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            leading: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.withOpacity(0.2))),
              child: Center(child: Text(v.$1,
                  style: const TextStyle(fontSize: 22)))),
            title: Text(v.$2, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Colors.white)),
            subtitle: Text(v.$3, style: const TextStyle(
                fontSize: 11, color: Color(0xFF4A5280))),
            trailing: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: c.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: c.withOpacity(0.6))),
          ),
        );
      }).toList();

  Widget _tipCard(l) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF25D366).withOpacity(0.04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: const Color(0xFF25D366).withOpacity(0.1)),
    ),
    child: Row(children: [
      const Icon(Icons.tips_and_updates_rounded,
          color: Color(0xFF25D366), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(l.menuTip, style: const TextStyle(
          fontSize: 12, color: Colors.white54, height: 1.5))),
    ]),
  );

  Widget _contactBtn(l) => GestureDetector(
    onTap: _openContact,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A0533), Color(0xFF060A14)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFA259FF).withOpacity(0.25)),
        boxShadow: [BoxShadow(
            color: const Color(0xFFA259FF).withOpacity(0.07),
            blurRadius: 20)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFFA259FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.people_alt_rounded,
              color: Color(0xFFA259FF), size: 18)),
        const SizedBox(width: 12),
        Text(l.contactUs, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: Colors.white)),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: Color(0xFFA259FF)),
      ]),
    ),
  );

  Widget _glow(Color c, double s) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [c.withOpacity(0.07), Colors.transparent])),
  );
}

// ─── Settings Sheet ───────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final String phone;
  const _SettingsSheet({required this.phone});
  @override State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String _mode    = 'public';
  bool   _maint   = false;
  bool   _loading = false;
  String? _error;

  Map<String, List<Map<String, dynamic>>> _groups = {};
  Map<String, dynamic> _features = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ── Load settings ────────────────────────────────────────
  Future<void> _loadSettings() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getSettings(widget.phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() {
          _mode     = res['mode'] ?? 'public';
          _maint    = res['maintenance'] ?? false;
          _groups   = (res['groups'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k,
                  (v as List).map((e) => Map<String, dynamic>.from(e)).toList()));
          _features = Map<String, dynamic>.from(res['features'] ?? {});
          _loading  = false;
        });
      } else {
        setState(() { _error = res['error']; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Failed to load settings.'; _loading = false;
      });
    }
  }

  // ── Save + restart ───────────────────────────────────────
  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Build commands map
      final cmds = <String, bool>{};
      for (final group in _groups.values) {
        for (final cmd in group) {
          cmds[cmd['cmd'] as String] = cmd['enabled'] as bool;
        }
      }
      final res = await ApiService.saveSettings(
        widget.phone,
        mode: _mode,
        maintenance: _maint,
        features: _features,
        commands: cmds,
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Settings saved & bot restarting!',
              style: TextStyle(fontFamily: 'monospace')),
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        setState(() { _error = res['error'] ?? 'Save failed.'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Server unreachable.'; _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Header
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFFA259FF), Color(0xFF00E5FF)])
                .createShader(r),
            child: const Text('BOT SETTINGS',
                style: TextStyle(fontFamily: 'monospace',
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 3)),
          ),
          const SizedBox(height: 4),
          Text('+${widget.phone}',
              style: const TextStyle(fontFamily: 'monospace',
                  fontSize: 12, color: Color(0xFF4A5280))),
          const SizedBox(height: 20),
          if (_error != null) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFF4757).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFFF4757), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(
                    color: Color(0xFFFF4757), fontSize: 12))),
              ]),
            ),
          ),
          if (_error != null) const SizedBox(height: 12),
          Expanded(child: Stack(children: [
            _loading && _groups.isEmpty
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFFA259FF)))
                : _settingsStep(scroll),
            // Floating Save button
            if (!_loading || _groups.isNotEmpty) Positioned(
              bottom: 16, left: 24, right: 24,
              child: GestureDetector(
                onTap: _loading ? null : _save,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _loading
                        ? [Colors.white12, Colors.white12]
                        : const [Color(0xFF25D366), Color(0xFF00C853)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _loading ? [] : [BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.35),
                        blurRadius: 18, spreadRadius: 1)],
                  ),
                  child: Center(child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.save_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Save & Restart Bot',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ])),
                ),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  // ── Settings step ────────────────────────────────────────
  Widget _settingsStep(ScrollController scroll) => SingleChildScrollView(
    controller: scroll,
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selector
        _settingsLabel('BOT MODE'),
        const SizedBox(height: 8),
        Row(children: [
          _modeChip('public',  '🌐 Public',  const Color(0xFF25D366)),
          const SizedBox(width: 10),
          _modeChip('private', '🔒 Private', const Color(0xFFFFD93D)),
          const SizedBox(width: 10),
          _modeChip('inbox',   '📬 Inbox',   const Color(0xFF00E5FF)),
        ]),
        const SizedBox(height: 20),

        // Maintenance toggle
        _settingsLabel('MAINTENANCE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            const Icon(Icons.construction_rounded,
                color: Color(0xFFFFD93D), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Maintenance Mode',
                  style: TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Text('Pauses bot responses',
                  style: TextStyle(color: Color(0xFF4A5280),
                      fontSize: 11)),
            ])),
            Switch(
              value: _maint,
              onChanged: (v) => setState(() => _maint = v),
              activeColor: const Color(0xFFFFD93D),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Features toggles
        if (_features.isNotEmpty) ...[
          _settingsLabel('FEATURES'),
          const SizedBox(height: 8),
          ..._features.entries
              .where((e) => e.value is bool)
              .map((e) => _featureToggle(e.key, e.value as bool)),
          const SizedBox(height: 20),
        ],

        // Command groups
        if (_groups.isNotEmpty) ...[
          _settingsLabel('COMMANDS'),
          const SizedBox(height: 8),
          ..._groups.entries.map((e) => _commandGroup(e.key, e.value)),
        ],
      ],
    ),
  );

  Widget _settingsLabel(String t) => Text(t,
      style: const TextStyle(fontFamily: 'monospace',
          fontSize: 10, letterSpacing: 3, color: Color(0xFF4A5280)));

  Widget _modeChip(String val, String label, Color c) =>
      Expanded(child: GestureDetector(
        onTap: () => setState(() => _mode = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _mode == val ? c.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _mode == val ? c : Colors.white10,
                width: _mode == val ? 1.5 : 1),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _mode == val ? c : const Color(0xFF4A5280))),
        ),
      ));

  Widget _featureToggle(String key, bool val) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF060A14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(children: [
      const Icon(Icons.electric_bolt_rounded,
          color: Color(0xFF00E5FF), size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(key,
          style: const TextStyle(color: Colors.white70,
              fontSize: 13, fontFamily: 'monospace'))),
      Switch(
        value: val,
        onChanged: (v) => setState(() => _features[key] = v),
        activeColor: const Color(0xFF00E5FF),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]),
  );

  Widget _commandGroup(String name, List<Map<String, dynamic>> cmds) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text(name.toUpperCase(),
              style: const TextStyle(fontFamily: 'monospace',
                  fontSize: 12, color: Colors.white70,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
          iconColor: const Color(0xFFA259FF),
          collapsedIconColor: Colors.white38,
          children: cmds.map((cmd) {
            final idx = cmds.indexOf(cmd);
            return SwitchListTile(
              dense: true,
              title: Text('.${cmd['cmd']}',
                  style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 13, color: Colors.white60)),
              value: cmd['enabled'] as bool,
              onChanged: (v) => setState(() => _groups[name]![idx]['enabled'] = v),
              activeColor: const Color(0xFF25D366),
            );
          }).toList(),
        ),
      );
}

// ─── Contact Sheet ────────────────────────────────────────────
class _ContactSheet extends StatelessWidget {
  final dynamic l;
  const _ContactSheet({required this.l});

  static const _contacts = [
    (icon:'👑', color:Color(0xFFFFD93D), en:'Owner',     si:'හිමිකරු',
     handle:'@Hello_200ABC',    url:'https://t.me/Hello_200ABC'),
    (icon:'💻', color:Color(0xFF00E5FF), en:'Developer', si:'සංවර්ධක',
     handle:'@nmd_coder',       url:'https://t.me/nmd_coder'),
    (icon:'🤝', color:Color(0xFF25D366), en:'Supporter', si:'සහාය',
     handle:'@shashen_ayantha', url:'https://t.me/shashen_ayantha'),
  ];

  Future<void> _open(String url) async {
    try { await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isSi = l.isSinhala as bool;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF060A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white12,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFA259FF), Color(0xFF00E5FF)])
              .createShader(r),
          child: Text(l.contactUs as String,
              style: const TextStyle(fontFamily: 'monospace',
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 2)),
        ),
        const SizedBox(height: 4),
        const Text('UNITY-MD', style: TextStyle(
            fontFamily: 'monospace', fontSize: 10,
            color: Color(0xFF4A5280), letterSpacing: 3)),
        const SizedBox(height: 28),
        ..._contacts.map<Widget>((c) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [c.color.withOpacity(0.07),
                  const Color(0xFF060A14)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.color.withOpacity(0.2)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: c.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.color.withOpacity(0.25)),
                boxShadow: [BoxShadow(
                    color: c.color.withOpacity(0.15), blurRadius: 12)],
              ),
              child: Center(child: Text(c.icon,
                  style: const TextStyle(fontSize: 22)))),
            title: Text(isSi ? c.si : c.en, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: c.color)),
            subtitle: Text(c.handle, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13,
                color: Colors.white70, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: c.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.send_rounded, color: c.color, size: 17)),
            onTap: () => _open(c.url),
          ),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D1117),
              foregroundColor: Colors.white54,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white10)),
            ),
            child: Text(l.closeBtn as String,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
