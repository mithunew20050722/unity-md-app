import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  final String phone;
  const HomeScreen({super.key, required this.phone});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = 'connecting';
  int? _uptime;
  int _cmds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

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

  Future<void> _disconnect() async {
    final l  = langNotifier.lang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF060A14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.disconnectTitle,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(l.disconnectBody,
          style: GoogleFonts.spaceGrotesk(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel,
              style: GoogleFonts.spaceGrotesk(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.disconnect,
              style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF4757)))),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.disconnect(widget.phone);
    final p = await SharedPreferences.getInstance();
    await p.remove('phone');
    if (!mounted) return;
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  String _fmt(int? s) {
    if (s == null) return '--';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Color get _col {
    switch (_status) {
      case 'connected':    return const Color(0xFF25D366);
      case 'pairing':      return const Color(0xFFFFD93D);
      case 'error':        return const Color(0xFFFF4757);
      default:             return const Color(0xFF4A5280);
    }
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
          appBar: AppBar(
            backgroundColor: const Color(0xFF030610), elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.3)),
                ),
                child: ClipOval(
                  child: Image.asset('assets/icon.png', fit: BoxFit.cover)),
              ),
            ),
            title: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
              ).createShader(r),
              child: Text('UNITY-MD',
                style: GoogleFonts.orbitron(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  letterSpacing: 3, color: Colors.white)),
            ),
            actions: [
              // Language toggle
              GestureDetector(
                onTap: () => langNotifier.toggle(),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 10),
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
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 20),
                onPressed: _load,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                  color: Colors.white38, size: 20),
                color: const Color(0xFF060A14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
                onSelected: (v) { if (v == 'dc') _disconnect(); },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'dc',
                    child: Row(children: [
                      const Icon(Icons.link_off,
                        color: Color(0xFFFF4757), size: 18),
                      const SizedBox(width: 10),
                      Text(l.disconnect,
                        style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                    ])),
                ],
              ),
            ],
          ),
          body: Stack(children: [
            // Background glows
            Positioned(top: -60, left: -60,
              child: _glow(const Color(0xFF25D366), 200)),
            Positioned(bottom: -60, right: -60,
              child: _glow(const Color(0xFF00E5FF), 160)),

            RefreshIndicator(
              onRefresh: _load, color: const Color(0xFF25D366),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [

                  // ── Status card ────────────────────────────────
                  _statusCard(l),
                  const SizedBox(height: 14),

                  // ── Stats row ──────────────────────────────────
                  Row(children: [
                    _stat('⏱️', l.uptime,   _fmt(_uptime)),
                    const SizedBox(width: 10),
                    _stat('⚡', l.commands, '$_cmds+'),
                    const SizedBox(width: 10),
                    _stat('🛡️', l.antiBan,  'ON'),
                  ]).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),

                  // ── Features heading ───────────────────────────
                  Text(l.features,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, letterSpacing: 3,
                      color: const Color(0xFF4A5280))),
                  const SizedBox(height: 12),

                  // ── Feature cards ──────────────────────────────
                  ...l.featureCards.asMap().entries.map((e) {
                    final i = e.key;
                    final v = e.value;
                    final c = _featureColors[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060A14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.withOpacity(0.12)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.withOpacity(0.2)),
                          ),
                          child: Center(child: Text(v.$1,
                            style: const TextStyle(fontSize: 20)))),
                        title: Text(v.$2,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                        subtitle: Text(v.$3,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: const Color(0xFF4A5280))),
                        trailing: Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: c.withOpacity(0.4)),
                      ),
                    ).animate()
                        .fadeIn(delay: Duration(milliseconds: 150 + i * 80))
                        .slideX(begin: 0.05);
                  }),

                  const SizedBox(height: 16),

                  // ── Tip ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF25D366).withOpacity(0.1)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                        color: Color(0xFF25D366), size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.menuTip,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, color: Colors.white54, height: 1.5))),
                    ]),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _statusCard(l) {
    final label = l.statusLabel(_status);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _col.withOpacity(0.08),
            const Color(0xFF060A14),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _col.withOpacity(0.2)),
        boxShadow: [BoxShadow(
          color: _col.withOpacity(0.07), blurRadius: 24, spreadRadius: 2)],
      ),
      child: Column(children: [
        // Pulsing dot
        Container(width: 12, height: 12,
          decoration: BoxDecoration(
            color: _col, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: _col.withOpacity(0.6),
              blurRadius: 10, spreadRadius: 2)]),
        ).animate(onPlay: (c) => c.repeat())
            .scaleXY(end: 1.5, duration: 900.ms)
            .then().scaleXY(end: 1.0, duration: 900.ms),

        const SizedBox(height: 14),
        Text(label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 19, fontWeight: FontWeight.w800, color: _col)),
        const SizedBox(height: 4),
        Text('+${widget.phone}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13, color: Colors.white30, letterSpacing: 1)),
      ]),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _stat(String e, String l, String v) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF060A14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF25D366).withOpacity(0.07)),
      ),
      child: Column(children: [
        Text(e, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 5),
        Text(v,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(l,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10, color: const Color(0xFF4A5280))),
      ]),
    ),
  );

  Widget _glow(Color c, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c.withOpacity(0.06), Colors.transparent]),
    ),
  );
}
