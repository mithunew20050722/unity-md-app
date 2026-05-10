import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';

// ─── Particle painter ─────────────────────────────────────────────────────────
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

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final String phone;
  const HomeScreen({super.key, required this.phone});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'connecting';
  int?   _uptime;
  int    _cmds = 0;

  Timer? _pollTimer, _particleTimer;
  final _rng = Random();
  late List<_Particle> _particles;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(28, (_) => _Particle(_rng));

    _glowCtrl = AnimationController(
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
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _particleTimer?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await ApiService.botInfo(widget.phone);
      if (!mounted) return;
      setState(() {
        _status = info['status'] ?? 'disconnected';
        _uptime = info['uptime'];
        _cmds   = info['commandCount'] ?? 0;
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'disconnected');
    }
  }

  Future<void> _confirmDisconnect() async {
    final l  = langNotifier.lang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF060A14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(l.disconnectTitle,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(l.disconnectBody,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel,
                  style: const TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.disconnect,
                  style: const TextStyle(
                      color: Color(0xFFFF4757),
                      fontWeight: FontWeight.w700))),
        ],
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

  void _openContact() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactSheet(l: langNotifier.lang),
  );

  Color get _col {
    switch (_status) {
      case 'connected':  return const Color(0xFF25D366);
      case 'pairing':    return const Color(0xFFFFD93D);
      case 'error':      return const Color(0xFFFF4757);
      default:           return const Color(0xFF4A5280);
    }
  }

  String _fmt(int? s) {
    if (s == null) return '--';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
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
            // Particles
            Positioned.fill(
                child: CustomPaint(painter: _ParticlePainter(_particles))),
            // Animated glows
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Stack(children: [
                Positioned(
                    top: -80 + _glowAnim.value * 20,
                    left: -80,
                    child: _glow(const Color(0xFF25D366),
                        240 + _glowAnim.value * 20)),
                Positioned(
                    bottom: -80,
                    right: -80,
                    child: _glow(const Color(0xFF00E5FF),
                        180 + _glowAnim.value * 20)),
                Positioned(
                    top: MediaQuery.of(context).size.height * 0.45,
                    left: MediaQuery.of(context).size.width * 0.3,
                    child: _glow(const Color(0xFFA259FF),
                        100 + _glowAnim.value * 10)),
              ]),
            ),
            // Scrollable content
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
                  const SizedBox(height: 28),
                  const Text('FEATURES',
                      style: TextStyle(fontFamily: 'monospace',
                          fontSize: 10, letterSpacing: 3,
                          color: Color(0xFF4A5280))),
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

  PreferredSizeWidget _buildAppBar(l) => AppBar(
    backgroundColor: const Color(0xFF030610).withOpacity(0.92),
    elevation: 0,
    leading: Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
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
          if (v == 'dc')      _confirmDisconnect();
          if (v == 'contact') _openContact();
          if (v == 'refresh') _load();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'refresh',
              child: _menuRow(Icons.refresh_rounded,
                  const Color(0xFF00E5FF), 'Refresh')),
          PopupMenuItem(value: 'contact',
              child: _menuRow(Icons.people_alt_rounded,
                  const Color(0xFFA259FF), l.contactUs)),
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
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]);

  Widget _statusCard(l) => AnimatedBuilder(
    animation: _glowAnim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
        const SizedBox(height: 16),
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

  Widget _statsRow(l) => Row(children: [
    _stat('⏱️', l.uptime,   _fmt(_uptime), const Color(0xFF00E5FF)),
    const SizedBox(width: 10),
    _stat('⚡', l.commands, '$_cmds+',      const Color(0xFFFFD93D)),
    const SizedBox(width: 10),
    _stat('🛡️', l.antiBan, 'ON',           const Color(0xFF25D366)),
  ]);

  Widget _stat(String emoji, String label, String val, Color c) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.12)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontFamily: 'monospace',
              fontSize: 14, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
              fontSize: 10, color: Color(0xFF4A5280))),
        ]),
      ));

  List<Widget> _featureCards(l) =>
      l.featureCards.asMap().entries.map<Widget>((e) {
        final i = e.key;
        final v = e.value;
        final c = _fColors[i];
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
      Expanded(child: Text(l.menuTip,
          style: const TextStyle(
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
        Text(l.contactUs,
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w700, color: Colors.white)),
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

// ─── Contact Sheet ────────────────────────────────────────────────────────────
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
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
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
        const Text('UNITY-MD',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10,
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
            title: Text(isSi ? c.si : c.en,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: c.color)),
            subtitle: Text(c.handle,
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 13, color: Colors.white70,
                    fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: c.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.send_rounded,
                  color: c.color, size: 17)),
            onTap: () => _open(c.url),
          ),
        )),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('UNITY-MD ${l.version}',
                  style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 11, color: Color(0xFF4A5280))),
              Text(l.builtWith as String,
                  style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 10, color: Color(0xFF4A5280))),
            ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 50,
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
