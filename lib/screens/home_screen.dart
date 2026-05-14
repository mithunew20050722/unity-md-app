import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'api_service.dart';
import 'setup_screen.dart';
import 'chat_screen.dart';

// ─── Particle ─────────────────────────────────────────────────
class _Particle {
  double x, y, r, speed, opacity;
  _Particle(Random rng)
      : x       = rng.nextDouble(),
        y       = rng.nextDouble(),
        r       = rng.nextDouble() * 2 + 0.5,
        speed   = rng.nextDouble() * 0.0006 + 0.0002,
        opacity = rng.nextDouble() * 0.25 + 0.05;
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
    with TickerProviderStateMixin {
  // State
  String _status  = 'connecting';
  int?   _uptime;
  int    _cmds    = 0;
  bool   _pingOk  = false;
  int    _liveRt  = 0;
  DateTime? _rtBase;
  int    _tab     = 1; // 0=chat, 1=home, 2=settings

  // Timers
  Timer? _pollTimer, _particleTimer, _pingTimer, _rtTimer;

  // Animations
  final _rng = Random();
  late List<_Particle> _particles;
  late AnimationController _glowCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late Animation<double>   _glowAnim;
  late Animation<double>   _pulseAnim;

  static const _fColors = [
    Color(0xFF25D366), Color(0xFF00E5FF),
    Color(0xFFA259FF), Color(0xFFFFD93D),
  ];

  @override
  void initState() {
    super.initState();
    _particles = List.generate(32, (_) => _Particle(_rng));

    _glowCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    _glowAnim  = CurvedAnimation(parent: _glowCtrl,  curve: Curves.easeInOut);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      for (final p in _particles) p.tick();
      setState(() {});
    });

    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _doPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _doPing());
    _rtTimer   = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_rtBase != null) {
        setState(() {
          _liveRt = (_uptime ?? 0) + DateTime.now().difference(_rtBase!).inSeconds;
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
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final info = await ApiService.botInfo(widget.phone);
      if (!mounted) return;
      setState(() {
        _status = info['status'] ?? 'disconnected';
        _uptime = info['uptime'];
        _cmds   = info['commandCount'] ?? 0;
        _rtBase = DateTime.now();
        _liveRt = _uptime ?? 0;
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'disconnected');
    }
  }

  Future<void> _doPing() async {
    final ok = await ApiService.ping();
    if (mounted) setState(() => _pingOk = ok);
  }

  // ── Actions ────────────────────────────────────────────────
  Future<void> _restart() async {
    final confirmed = await _confirm(
      title: 'Restart Bot',
      body: 'Bot will restart. Startup message & audio will play (~10s).',
      confirmLabel: 'Restart',
      confirmColor: const Color(0xFF00E5FF),
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
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

  Future<void> _confirmDisconnect() async {
    final ok = await _confirm(
      title: langNotifier.lang.disconnectTitle,
      body: langNotifier.lang.disconnectBody,
      confirmLabel: langNotifier.lang.disconnect,
      confirmColor: const Color(0xFFFF4757),
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

  void _openSettings() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsSheet(phone: widget.phone),
  ).whenComplete(() {
    if (mounted) setState(() => _tab = 1);
  });

  void _openChat() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(phone: widget.phone)));
  }

  void _openContact() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactSheet(l: langNotifier.lang),
  );

  void _onTabTapped(int i) {
    HapticFeedback.selectionClick();
    if (i == 0) { _openChat(); return; }
    if (i == 2) {
      setState(() => _tab = 2);
      _openSettings();
      return;
    }
    setState(() => _tab = i);
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'monospace',
          fontWeight: FontWeight.w600)),
      backgroundColor: c,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<bool?> _confirm({
    required String title, required String body,
    required String confirmLabel, required Color confirmColor,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0D1117),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: confirmColor.withOpacity(0.2)),
      ),
      title: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: confirmColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.warning_amber_rounded, color: confirmColor, size: 20)),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
      content: Text(body,
          style: const TextStyle(color: Colors.white60, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(langNotifier.lang.cancel,
              style: const TextStyle(color: Colors.white38))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor.withOpacity(0.15),
            foregroundColor: confirmColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: confirmColor.withOpacity(0.3))),
          ),
          child: Text(confirmLabel,
              style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700))),
      ],
    ),
  );

  // ── Helpers ────────────────────────────────────────────────
  Color get _col {
    switch (_status) {
      case 'connected':  return const Color(0xFF25D366);
      case 'pairing':    return const Color(0xFFFFD93D);
      case 'error':      return const Color(0xFFFF4757);
      default:           return const Color(0xFF3A4270);
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

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langNotifier,
      builder: (_, __) {
        final l = langNotifier.lang;
        return Scaffold(
          backgroundColor: const Color(0xFF020408),
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: _buildAppBar(l),
          bottomNavigationBar: _buildNavBar(),
          body: Stack(children: [
            // Particles
            Positioned.fill(child: CustomPaint(painter: _ParticlePainter(_particles))),
            // Glows
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Stack(children: [
                Positioned(top: -80 + _glowAnim.value * 20, left: -80,
                    child: _glow(const Color(0xFF25D366), 260 + _glowAnim.value * 20)),
                Positioned(bottom: -80, right: -80,
                    child: _glow(const Color(0xFF00E5FF), 200 + _glowAnim.value * 15)),
                Positioned(
                    top: MediaQuery.of(context).size.height * 0.45,
                    left: MediaQuery.of(context).size.width * 0.25,
                    child: _glow(const Color(0xFFA259FF), 120 + _glowAnim.value * 10)),
              ]),
            ),
            // Content
            RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF25D366),
              backgroundColor: const Color(0xFF060A14),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.of(context).padding.top + 72,
                    16,
                    MediaQuery.of(context).padding.bottom + 90),
                children: [
                  _heroCard(l),
                  const SizedBox(height: 12),
                  _pingBar(),
                  const SizedBox(height: 12),
                  _statsGrid(l),
                  const SizedBox(height: 20),
                  _sectionHeader('QUICK ACTIONS'),
                  const SizedBox(height: 12),
                  _quickActions(l),
                  const SizedBox(height: 24),
                  _sectionHeader('FEATURES'),
                  const SizedBox(height: 12),
                  ..._featureCards(l),
                  const SizedBox(height: 16),
                  _tipCard(l),
                  const SizedBox(height: 12),
                  _contactBtn(l),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(l) => AppBar(
    backgroundColor: const Color(0xFF020408).withOpacity(0.93),
    elevation: 0,
    leading: Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
          boxShadow: [BoxShadow(
              color: const Color(0xFF25D366).withOpacity(0.2), blurRadius: 8)],
        ),
        child: ClipOval(child: Image.asset('assets/icon.png', fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF060A14),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF25D366), size: 22)))),
      ),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF00E5FF)]).createShader(r),
        child: const Text('UNITY-MD', style: TextStyle(
            fontFamily: 'monospace', fontSize: 16,
            fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
      ),
      const Text('® UNITY TEAM', style: TextStyle(
          fontFamily: 'monospace', fontSize: 9,
          color: Color(0xFF3A4270), letterSpacing: 2)),
    ]),
    actions: [
      // Lang toggle
      GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); langNotifier.toggle(); },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2)),
          ),
          child: Text(
            langNotifier.lang.isSinhala ? '🇱🇰 SI' : '🇬🇧 EN',
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 10, color: Color(0xFF25D366))),
        ),
      ),
      // Refresh
      IconButton(
        onPressed: () { HapticFeedback.lightImpact(); _load(); },
        icon: const Icon(Icons.refresh_rounded, color: Colors.white30, size: 20),
      ),
    ],
  );

  // ── Bottom nav ─────────────────────────────────────────────
  Widget _buildNavBar() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF030610),
      border: const Border(top: BorderSide(color: Color(0xFF0D1425), width: 1)),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          _navItem(0, Icons.chat_bubble_rounded, 'Chat', const Color(0xFF25D366)),
          _navItem(1, Icons.dashboard_rounded,  'Home', const Color(0xFF00E5FF)),
          _navItem(2, Icons.tune_rounded,        'Settings', const Color(0xFFA259FF)),
        ]),
      ),
    ),
  );

  Widget _navItem(int i, IconData icon, String label, Color c) => Expanded(
    child: GestureDetector(
      onTap: () => _onTabTapped(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _tab == i ? c.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _tab == i ? c.withOpacity(0.25) : Colors.transparent,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _tab == i ? c : const Color(0xFF3A4270),
              size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 9,
              fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w400,
              color: _tab == i ? c : const Color(0xFF3A4270),
              letterSpacing: 0.5)),
        ]),
      ),
    ),
  );

  // ── Hero status card ───────────────────────────────────────
  Widget _heroCard(l) => AnimatedBuilder(
    animation: Listenable.merge([_glowAnim, _pulseAnim, _orbitCtrl]),
    builder: (_, __) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _col.withOpacity(0.1 + _glowAnim.value * 0.04),
            const Color(0xFF060A14),
            _col.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _col.withOpacity(0.2)),
        boxShadow: [BoxShadow(
            color: _col.withOpacity(0.07 + _pulseAnim.value * 0.05),
            blurRadius: 40, spreadRadius: 4)],
      ),
      child: Row(children: [
        // Status orb
        SizedBox(width: 80, height: 80,
          child: Stack(alignment: Alignment.center, children: [
            // Outer pulse ring
            Container(
              width: 80 + _pulseAnim.value * 6,
              height: 80 + _pulseAnim.value * 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _col.withOpacity(0.05 + _pulseAnim.value * 0.04),
              ),
            ),
            // Middle ring
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _col.withOpacity(0.08),
                border: Border.all(color: _col.withOpacity(0.15), width: 1),
              ),
            ),
            // Core dot
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _col,
                boxShadow: [BoxShadow(
                    color: _col.withOpacity(0.8),
                    blurRadius: 12 + _pulseAnim.value * 6,
                    spreadRadius: 2)],
              ),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        // Status text
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.statusLabel(_status),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _col)),
          const SizedBox(height: 4),
          Text('+${widget.phone}',
              style: const TextStyle(fontFamily: 'monospace',
                  fontSize: 12, color: Color(0xFF3A4270), letterSpacing: 1)),
          const SizedBox(height: 8),
          // Mini status chips
          Wrap(spacing: 6, children: [
            _chip('${_cmds}+', Icons.bolt_rounded, const Color(0xFFFFD93D)),
            _chip(_status == 'connected' ? 'LIVE' : 'OFFLINE',
                Icons.circle, _col, small: true),
          ]),
        ])),
        // Bot avatar
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _col.withOpacity(0.3), width: 2),
            boxShadow: [BoxShadow(
                color: _col.withOpacity(0.15), blurRadius: 12)],
          ),
          child: ClipOval(child: Image.asset('assets/icon.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF060A14),
              child: Icon(Icons.smart_toy_rounded, color: _col, size: 28)))),
        ),
      ]),
    ),
  );

  Widget _chip(String label, IconData icon, Color c, {bool small = false}) =>
      Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c, size: small ? 8 : 10),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'monospace',
              fontSize: small ? 8 : 9, color: c, fontWeight: FontWeight.w700)),
        ]),
      );

  // ── Ping bar ───────────────────────────────────────────────
  Widget _pingBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF060A14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: (_pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757))
              .withOpacity(0.15)),
    ),
    child: Row(children: [
      // Animated dot
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757),
            boxShadow: [BoxShadow(
                color: (_pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757))
                    .withOpacity(_pulseAnim.value * 0.9),
                blurRadius: 8, spreadRadius: 2)],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(_pingOk ? 'SERVER ONLINE' : 'SERVER OFFLINE',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: _pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757))),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (_pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757))
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: (_pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757))
                  .withOpacity(0.25)),
        ),
        child: Text(_pingOk ? '● PING OK' : '✕ OFFLINE',
            style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _pingOk ? const Color(0xFF25D366) : const Color(0xFFFF4757))),
      ),
    ]),
  );

  // ── Stats grid 2×2 ─────────────────────────────────────────
  Widget _statsGrid(l) => Row(children: [
    Expanded(child: Column(children: [
      _statCard('⏱️', 'RUNTIME', _fmt(_liveRt), const Color(0xFF00E5FF), live: true),
      const SizedBox(height: 10),
      _statCard('🛡️', l.antiBan, 'ON', const Color(0xFF25D366)),
    ])),
    const SizedBox(width: 10),
    Expanded(child: Column(children: [
      _statCard('⚡', l.commands, '$_cmds+', const Color(0xFFFFD93D)),
      const SizedBox(height: 10),
      _statCard('🔒', 'SESSION', 'SECURE', const Color(0xFFA259FF)),
    ])),
  ]);

  Widget _statCard(String emoji, String label, String val, Color c,
      {bool live = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: c.withOpacity(0.04), blurRadius: 12)],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.15)),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(val, style: TextStyle(fontFamily: 'monospace',
                fontSize: 15, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9,
                color: Color(0xFF3A4270), fontFamily: 'monospace', letterSpacing: 1)),
          ])),
          if (live) AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF25D366),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(_pulseAnim.value),
                    blurRadius: 6)],
              ),
            ),
          ),
        ]),
      );

  // ── Section header ─────────────────────────────────────────
  Widget _sectionHeader(String t) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter),
      borderRadius: BorderRadius.circular(2),
    )),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontFamily: 'monospace',
        fontSize: 10, letterSpacing: 3, color: Color(0xFF3A4270),
        fontWeight: FontWeight.w700)),
  ]);

  // ── Quick actions ──────────────────────────────────────────
  Widget _quickActions(l) => Row(children: [
    _actionBtn(Icons.tune_rounded,      'Settings',   const Color(0xFFA259FF), _openSettings),
    const SizedBox(width: 10),
    _actionBtn(Icons.chat_bubble_rounded,'Chat',      const Color(0xFF25D366), _openChat),
    const SizedBox(width: 10),
    _actionBtn(Icons.restart_alt_rounded,'Restart',  const Color(0xFF00E5FF), _restart),
    const SizedBox(width: 10),
    _actionBtn(Icons.link_off_rounded,   'Disconnect', const Color(0xFFFF4757), _confirmDisconnect),
  ]);

  Widget _actionBtn(IconData icon, String label, Color c, VoidCallback onTap) =>
      Expanded(child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withOpacity(0.12), c.withOpacity(0.04)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(0.2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.12),
                border: Border.all(color: c.withOpacity(0.2)),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: c.withOpacity(0.9), fontSize: 9,
                fontFamily: 'monospace', fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.withOpacity(0.15), c.withOpacity(0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withOpacity(0.2)),
              ),
              child: Center(child: Text(v.$1, style: const TextStyle(fontSize: 22)))),
            title: Text(v.$2, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            subtitle: Text(v.$3, style: const TextStyle(
                fontSize: 11, color: Color(0xFF3A4270), height: 1.4)),
            trailing: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withOpacity(0.2))),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c)),
          ),
        );
      }).toList();

  // ── Tip card ───────────────────────────────────────────────
  Widget _tipCard(l) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF061A0E), Color(0xFF020408)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF25D366).withOpacity(0.1)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.tips_and_updates_rounded,
            color: Color(0xFF25D366), size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(l.menuTip, style: const TextStyle(
          fontSize: 12, color: Colors.white54, height: 1.6))),
    ]),
  );

  // ── Contact btn ────────────────────────────────────────────
  Widget _contactBtn(l) => GestureDetector(
    onTap: _openContact,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF120828), Color(0xFF060A14)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA259FF).withOpacity(0.2)),
        boxShadow: [BoxShadow(
            color: const Color(0xFFA259FF).withOpacity(0.06), blurRadius: 20)],
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
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 12, color: Color(0xFFA259FF)),
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
  Map<String, List<Map<String, dynamic>>> _groups  = {};
  Map<String, dynamic>                   _features = {};

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getSettings(widget.phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() {
          _mode     = res['mode'] ?? 'public';
          _maint    = res['maintenance'] ?? false;
          _groups   = (res['groups'] as Map<String, dynamic>? ?? {}).map((k, v) =>
              MapEntry(k, (v as List).map((e) => Map<String, dynamic>.from(e)).toList()));
          _features = Map<String, dynamic>.from(res['features'] ?? {});
          _loading  = false;
        });
      } else {
        setState(() { _error = res['error']; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load settings.'; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cmds = <String, bool>{};
      for (final group in _groups.values) {
        for (final cmd in group) {
          cmds[cmd['cmd'] as String] = cmd['enabled'] as bool;
        }
      }
      final res = await ApiService.saveSettings(widget.phone,
        mode: _mode, maintenance: _maint, features: _features, commands: cmds);
      if (!mounted) return;
      if (res['ok'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✓ Settings saved & bot restarting!',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      } else {
        setState(() { _error = res['error'] ?? 'Save failed.'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Server unreachable.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.87,
      maxChildSize: 0.96,
      minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080D14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white10,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFA259FF), Color(0xFF6E3FBB)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFFA259FF).withOpacity(0.3),
                      blurRadius: 12)],
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BOT SETTINGS', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 16,
                    fontWeight: FontWeight.w900, color: Colors.white,
                    letterSpacing: 2)),
                Text('+${widget.phone}', style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11,
                    color: Color(0xFF3A4270))),
              ]),
            ]),
          ),
          const SizedBox(height: 4),

          // Error
          if (_error != null) Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(
                    color: Color(0xFFFF4757), fontSize: 12))),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.04)),

          Expanded(child: Stack(children: [
            _loading && _groups.isEmpty
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFFA259FF), strokeWidth: 2))
                : _settingsContent(scroll),

            // Save button
            if (!_loading || _groups.isNotEmpty)
              Positioned(bottom: 16, left: 24, right: 24,
                child: GestureDetector(
                  onTap: _loading ? null : _save,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _loading
                          ? [Colors.white10, Colors.white10]
                          : const [Color(0xFF25D366), Color(0xFF00C853)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _loading ? [] : [BoxShadow(
                          color: const Color(0xFF25D366).withOpacity(0.4),
                          blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: Center(child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Save & Restart Bot', style: TextStyle(
                                color: Colors.white, fontSize: 15,
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

  Widget _settingsContent(ScrollController sc) => SingleChildScrollView(
    controller: sc,
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('BOT MODE'),
      const SizedBox(height: 10),
      Row(children: [
        _modeChip('public',  '🌐', 'Public',  const Color(0xFF25D366)),
        const SizedBox(width: 8),
        _modeChip('private', '🔒', 'Private', const Color(0xFFFFD93D)),
        const SizedBox(width: 8),
        _modeChip('inbox',   '📬', 'Inbox',   const Color(0xFF00E5FF)),
      ]),
      const SizedBox(height: 20),

      _label('MAINTENANCE'),
      const SizedBox(height: 10),
      _toggleCard(
        icon: Icons.construction_rounded,
        iconColor: const Color(0xFFFFD93D),
        title: 'Maintenance Mode',
        subtitle: 'Pauses all bot responses',
        value: _maint,
        onChanged: (v) => setState(() => _maint = v),
        activeColor: const Color(0xFFFFD93D),
      ),
      const SizedBox(height: 20),

      if (_features.isNotEmpty) ...[ 
        _label('FEATURES'),
        const SizedBox(height: 10),
        ..._features.entries
            .where((e) => e.value is bool)
            .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _toggleCard(
                icon: Icons.electric_bolt_rounded,
                iconColor: const Color(0xFF00E5FF),
                title: e.key,
                value: e.value as bool,
                onChanged: (v) => setState(() => _features[e.key] = v),
                activeColor: const Color(0xFF00E5FF),
              ),
            )),
        const SizedBox(height: 20),
      ],

      if (_groups.isNotEmpty) ...[
        _label('COMMANDS'),
        const SizedBox(height: 10),
        ..._groups.entries.map((e) => _cmdGroup(e.key, e.value)),
      ],
    ]),
  );

  Widget _label(String t) => Row(children: [
    Container(width: 3, height: 12,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFA259FF), Color(0xFF00E5FF)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(2),
      )),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontFamily: 'monospace',
        fontSize: 10, letterSpacing: 3, color: Color(0xFF3A4270),
        fontWeight: FontWeight.w700)),
  ]);

  Widget _toggleCard({
    required IconData icon, required Color iconColor,
    required String title, String? subtitle,
    required bool value, required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF060A14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
        if (subtitle != null) Text(subtitle, style: const TextStyle(
            color: Color(0xFF3A4270), fontSize: 11)),
      ])),
      Switch(value: value, onChanged: onChanged,
        activeColor: activeColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]),
  );

  Widget _modeChip(String val, String emoji, String label, Color c) =>
      Expanded(child: GestureDetector(
        onTap: () => setState(() => _mode = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _mode == val ? c.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _mode == val ? c : Colors.white.withOpacity(0.07),
                width: _mode == val ? 1.5 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _mode == val ? c : const Color(0xFF3A4270))),
          ]),
        ),
      ));

  Widget _cmdGroup(String name, List<Map<String, dynamic>> cmds) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(name.toUpperCase(), style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: Colors.white60,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            iconColor: const Color(0xFFA259FF),
            collapsedIconColor: Colors.white24,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: cmds.map((cmd) {
              final idx = cmds.indexOf(cmd);
              return SwitchListTile(
                dense: true,
                title: Text('.${cmd['cmd']}', style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: Colors.white54)),
                value: cmd['enabled'] as bool,
                onChanged: (v) => setState(() => _groups[name]![idx]['enabled'] = v),
                activeColor: const Color(0xFF25D366),
              );
            }).toList(),
          ),
        ),
      );
}

// ─── Contact Sheet ────────────────────────────────────────────
class _ContactSheet extends StatelessWidget {
  final dynamic l;
  const _ContactSheet({required this.l});

  static const _contacts = [
    (icon: '👑', color: Color(0xFFFFD93D), en: 'Owner',     si: 'හිමිකරු',
     handle: '@Hello_200ABC',    url: 'https://t.me/Hello_200ABC'),
    (icon: '💻', color: Color(0xFF00E5FF), en: 'Developer', si: 'සංවර්ධක',
     handle: '@nmd_coder',       url: 'https://t.me/nmd_coder'),
    (icon: '🤝', color: Color(0xFF25D366), en: 'Supporter', si: 'සහාය',
     handle: '@shashen_ayantha', url: 'https://t.me/shashen_ayantha'),
    (icon: '▶️', color: Color(0xFFFF0000), en: 'YouTube',   si: 'යූටියුබ්',
     handle: '@team_astral_yt',  url: 'https://www.youtube.com/@team_astral_yt'),
  ];

  Future<void> _open(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isSi = l.isSinhala as bool;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF060A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white10,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 28),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF12082A), Color(0xFF060A14)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFA259FF).withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFA259FF), Color(0xFF6E3FBB)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.contactUs as String, style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 16,
                  fontWeight: FontWeight.w900, color: Colors.white)),
              const Text('UNITY-MD', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 10,
                  color: Color(0xFF3A4270), letterSpacing: 2)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        ..._contacts.map<Widget>((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _open(c.url),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [c.color.withOpacity(0.08), const Color(0xFF060A14)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.color.withOpacity(0.18)),
              ),
              child: Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: c.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.color.withOpacity(0.25)),
                    boxShadow: [BoxShadow(
                        color: c.color.withOpacity(0.12), blurRadius: 12)],
                  ),
                  child: Center(child: Text(c.icon,
                      style: const TextStyle(fontSize: 22)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isSi ? c.si : c.en, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: c.color)),
                  Text(c.handle, style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: Colors.white70, fontWeight: FontWeight.w600)),
                ])),
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.send_rounded, color: c.color, size: 16)),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D1117),
              foregroundColor: Colors.white38,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10)),
            ),
            child: Text(l.closeBtn as String,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
