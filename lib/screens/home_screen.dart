import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';

// ─── Floating particle painter ────────────────────────────────────────────────
class _Particle {
  double x, y, r, speed, opacity;
  _Particle(Random rng)
      : x       = rng.nextDouble(),
        y       = rng.nextDouble(),
        r       = rng.nextDouble() * 2 + 1,
        speed   = rng.nextDouble() * 0.0008 + 0.0003,
        opacity = rng.nextDouble() * 0.4 + 0.1;
  void tick() { y -= speed; if (y < -0.02) y = 1.02; }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  _ParticlePainter(this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.r,
        Paint()..color = color.withOpacity(p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final String phone;
  const HomeScreen({super.key, required this.phone});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _status  = 'connecting';
  int?   _uptime;
  int    _cmds    = 0;
  Timer? _pollTimer;

  // particles
  final _rng       = Random();
  late List<_Particle> _particles;
  Timer? _particleTimer;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(28, (_) => _Particle(_rng));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _particleTimer = Timer.periodic(
      const Duration(milliseconds: 40), (_) {
      for (final p in _particles) p.tick();
      if (mounted) setState(() {});
    });

    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15), (_) => _load());
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
    } catch (_) {}
  }

  Future<void> _confirmDisconnect() async {
    final l  = langNotifier.lang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DisconnectDialog(l: l),
    );
    if (ok != true) return;
    await ApiService.disconnect(widget.phone);
    final p = await SharedPreferences.getInstance();
    await p.remove('phone');
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  void _openContactSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactSheet(lang: langNotifier.lang),
    );
  }

  Color get _statusColor {
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

  static const _featureColors = [
    Color(0xFF25D366),
    Color(0xFF00E5FF),
    Color(0xFFA259FF),
    Color(0xFFFFD93D),
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
            // ── Particle layer
            Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(
                  _particles, const Color(0xFF25D366)),
              ),
            ),

            // ── Ambient glows
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => Stack(children: [
                Positioned(
                  top: -80 + _glowCtrl.value * 20,
                  left: -80,
                  child: _glow(const Color(0xFF25D366),
                    240 + _glowCtrl.value * 20),
                ),
                Positioned(
                  bottom: -80 + _glowCtrl.value * 15,
                  right: -80,
                  child: _glow(const Color(0xFF00E5FF),
                    180 + _glowCtrl.value * 20),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.4,
                  left: MediaQuery.of(context).size.width * 0.3,
                  child: _glow(const Color(0xFFA259FF),
                    120 + _glowCtrl.value * 10),
                ),
              ]),
            ),

            // ── Content
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
                  _sectionLabel(l.features),
                  const SizedBox(height: 12),
                  ..._featuresList(l),
                  const SizedBox(height: 20),
                  _tipCard(l),
                  const SizedBox(height: 16),
                  _contactButton(l),
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
    backgroundColor: const Color(0xFF030610).withOpacity(0.85),
    elevation: 0,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF25D366).withOpacity(0.08)))),
    ),
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
        child: ClipOval(
          child: Image.asset(
            'assets/icon.png', fit: BoxFit.cover)),
      ),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
        ).createShader(r),
        child: Text('UNITY-MD',
          style: GoogleFonts.orbitron(
            fontSize: 16, fontWeight: FontWeight.w900,
            letterSpacing: 3, color: Colors.white)),
      ),
      Text('® UNITY TEAM',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9, color: const Color(0xFF4A5280),
          letterSpacing: 2)),
    ]),
    actions: [
      // Lang toggle
      GestureDetector(
        onTap: () => langNotifier.toggle(),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 4, vertical: 10),
          padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.25)),
          ),
          child: Text(
            l.isSinhala ? '🇱🇰 SI' : '🇬🇧 EN',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, color: const Color(0xFF25D366))),
        ),
      ),
      // Menu
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert,
          color: Colors.white38, size: 20),
        color: const Color(0xFF060A14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: const Color(0xFF25D366).withOpacity(0.1))),
        onSelected: (v) {
          if (v == 'dc')      _confirmDisconnect();
          if (v == 'contact') _openContactSheet();
          if (v == 'refresh') _load();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'refresh',
            child: _menuItem(Icons.refresh_rounded,
              const Color(0xFF00E5FF), l.isSinhala ? 'Refresh' : 'Refresh')),
          PopupMenuItem(value: 'contact',
            child: _menuItem(Icons.people_alt_rounded,
              const Color(0xFFA259FF), l.contactUs)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'dc',
            child: _menuItem(Icons.link_off_rounded,
              const Color(0xFFFF4757), l.disconnect)),
        ],
      ),
    ],
  );

  Widget _menuItem(IconData icon, Color c, String label) =>
    Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: c, size: 17)),
      const SizedBox(width: 12),
      Text(label,
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white, fontSize: 14)),
    ]);

  // ── Status card ─────────────────────────────────────────────────────────────
  Widget _statusCard(l) {
    final col   = _statusColor;
    final label = l.statusLabel(_status);
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              col.withOpacity(0.09 + _glowCtrl.value * 0.03),
              const Color(0xFF060A14),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: col.withOpacity(0.22)),
          boxShadow: [BoxShadow(
            color: col.withOpacity(0.08 + _glowCtrl.value * 0.04),
            blurRadius: 32, spreadRadius: 4)],
        ),
        child: Column(children: [
          // Pulsing dot
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: col.withOpacity(
                  0.06 + _glowCtrl.value * 0.06)),
            ),
            Container(width: 14, height: 14,
              decoration: BoxDecoration(
                color: col, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: col.withOpacity(0.7),
                  blurRadius: 12, spreadRadius: 2)]),
            ),
          ]),
          const SizedBox(height: 16),
          Text(label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: col)),
          const SizedBox(height: 4),
          Text('+${widget.phone}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13, color: Colors.white24,
              letterSpacing: 1)),
        ]),
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  // ── Stats row ───────────────────────────────────────────────────────────────
  Widget _statsRow(l) => Row(children: [
    _statCard('⏱️', l.uptime,   _fmt(_uptime), const Color(0xFF00E5FF)),
    const SizedBox(width: 10),
    _statCard('⚡', l.commands, '$_cmds+',      const Color(0xFFFFD93D)),
    const SizedBox(width: 10),
    _statCard('🛡️', l.antiBan, 'ON',           const Color(0xFF25D366)),
  ]).animate().fadeIn(delay: 100.ms);

  Widget _statCard(String emoji, String label, String val, Color c) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF060A14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.12)),
        boxShadow: [BoxShadow(
          color: c.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(val,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: c)),
        const SizedBox(height: 2),
        Text(label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10, color: const Color(0xFF4A5280))),
      ]),
    ));

  // ── Feature list ────────────────────────────────────────────────────────────
  List<Widget> _featuresList(l) =>
    l.featureCards.asMap().entries.map((e) {
      final i = e.key;
      final v = e.value;
      final c = _featureColors[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.withOpacity(0.13)),
          boxShadow: [BoxShadow(
            color: c.withOpacity(0.04), blurRadius: 16)],
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
          title: Text(v.$2,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white)),
          subtitle: Text(v.$3,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11, color: const Color(0xFF4A5280))),
          trailing: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: c.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: c.withOpacity(0.6))),
        ),
      ).animate()
          .fadeIn(delay: Duration(milliseconds: 150 + i * 80))
          .slideX(begin: 0.06);
    }).toList();

  // ── Tip card ────────────────────────────────────────────────────────────────
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
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12, color: Colors.white54, height: 1.5))),
    ]),
  ).animate().fadeIn(delay: 500.ms);

  // ── Contact button ──────────────────────────────────────────────────────────
  Widget _contactButton(l) => GestureDetector(
    onTap: _openContactSheet,
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
          color: const Color(0xFFA259FF).withOpacity(0.06),
          blurRadius: 20)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFA259FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.people_alt_rounded,
              color: Color(0xFFA259FF), size: 18)),
          const SizedBox(width: 12),
          Text(l.contactUs,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: Colors.white)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: Color(0xFFA259FF)),
        ]),
    ),
  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05);

  Widget _sectionLabel(String t) => Text(t,
    style: GoogleFonts.jetBrainsMono(
      fontSize: 10, letterSpacing: 3,
      color: const Color(0xFF4A5280)));

  Widget _glow(Color c, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c.withOpacity(0.07), Colors.transparent]),
    ),
  );
}

// ─── Disconnect dialog ────────────────────────────────────────────────────────
class _DisconnectDialog extends StatelessWidget {
  final dynamic l;
  const _DisconnectDialog({required this.l});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF060A14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20)),
    title: Text(l.disconnectTitle,
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white, fontWeight: FontWeight.w700)),
    content: Text(l.disconnectBody,
      style: GoogleFonts.spaceGrotesk(color: Colors.white70)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false),
        child: Text(l.cancel,
          style: GoogleFonts.spaceGrotesk(color: Colors.white38))),
      TextButton(onPressed: () => Navigator.pop(context, true),
        child: Text(l.disconnect,
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFFFF4757),
            fontWeight: FontWeight.w700))),
    ],
  );
}

// ─── Contact Bottom Sheet ─────────────────────────────────────────────────────
class _ContactSheet extends StatelessWidget {
  final dynamic l;
  const _ContactSheet({required this.l});

  static const _contacts = [
    (
      icon: '👑',
      color: Color(0xFFFFD93D),
      keyEn: 'Owner',
      keySi: 'හිමිකරු',
      handle: '@Hello_200ABC',
      url: 'https://t.me/Hello_200ABC',
    ),
    (
      icon: '💻',
      color: Color(0xFF00E5FF),
      keyEn: 'Developer',
      keySi: 'සංවර්ධක',
      handle: '@nmd_coder',
      url: 'https://t.me/nmd_coder',
    ),
    (
      icon: '🤝',
      color: Color(0xFF25D366),
      keyEn: 'Supporter',
      keySi: 'සහාය',
      handle: '@shashen_ayantha',
      url: 'https://t.me/shashen_ayantha',
    ),
  ];

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = l.isSinhala as bool;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF060A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),

        // Header
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFA259FF), Color(0xFF00E5FF)],
            ).createShader(r),
            child: Text(l.contactUs as String,
              style: GoogleFonts.orbitron(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 2)),
          ),
        ]).animate().fadeIn().slideY(begin: -0.1),

        const SizedBox(height: 6),
        Text('UNITY-MD',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10, color: const Color(0xFF4A5280),
            letterSpacing: 3)),

        const SizedBox(height: 28),

        // Contact cards
        ..._contacts.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final label = isSinhala ? c.keySi : c.keyEn;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.color.withOpacity(0.07),
                  const Color(0xFF060A14),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: c.color.withOpacity(0.2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: c.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.color.withOpacity(0.25)),
                  boxShadow: [BoxShadow(
                    color: c.color.withOpacity(0.15),
                    blurRadius: 12)],
                ),
                child: Center(child: Text(c.icon,
                  style: const TextStyle(fontSize: 22)))),
              title: Text(label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: c.color)),
              subtitle: Text(c.handle,
                style: GoogleFonts.jetBrainsMono(
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
          ).animate()
              .fadeIn(delay: Duration(milliseconds: 100 + i * 100))
              .slideX(begin: 0.08);
        }),

        const SizedBox(height: 8),

        // About row
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: const Color(0xFF4A5280))),
              Text(l.builtWith as String,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, color: const Color(0xFF4A5280))),
            ]),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 16),

        // Close button
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
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ).animate().fadeIn(delay: 450.ms),
      ]),
    );
  }
}
