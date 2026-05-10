import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF060A14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disconnect?', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Bot disconnect වෙනවා.', style: GoogleFonts.spaceGrotesk(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Disconnect', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF4757)))),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.disconnect(widget.phone);
    final p = await SharedPreferences.getInstance();
    await p.remove('phone');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
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

  String get _label {
    switch (_status) {
      case 'connected':    return '● Bot Active';
      case 'pairing':      return '○ Pairing...';
      case 'connecting':   return '○ Connecting...';
      case 'disconnected': return '○ Offline';
      default:             return _status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030610), elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/icon.png'),
          ),
        ),
        title: Text('UNITY-MD',
          style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w900,
            letterSpacing: 3, foreground: Paint()..shader = const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
            ).createShader(const Rect.fromLTWH(0,0,120,20)))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _load,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF060A14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (v) { if (v == 'dc') _disconnect(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'dc', child: Row(children: [
                const Icon(Icons.link_off, color: Color(0xFFFF4757), size: 18),
                const SizedBox(width: 10),
                Text('Disconnect', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ])),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load, color: const Color(0xFF25D366),
        child: ListView(padding: const EdgeInsets.all(20), children: [

          // ── Status card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF060A14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _col.withOpacity(0.25)),
              boxShadow: [BoxShadow(color: _col.withOpacity(0.08), blurRadius: 20)],
            ),
            child: Column(children: [
              Container(width: 12, height: 12,
                decoration: BoxDecoration(color: _col, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _col.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]),
              ).animate(onPlay: (c) => c.repeat())
                  .scaleXY(end: 1.4, duration: 800.ms).then().scaleXY(end: 1.0, duration: 800.ms),
              const SizedBox(height: 12),
              Text(_label, style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w800, color: _col)),
              const SizedBox(height: 4),
              Text('+${widget.phone}',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, color: Colors.white38, letterSpacing: 1)),
            ]),
          ).animate().fadeIn().slideY(begin: -0.1),

          const SizedBox(height: 14),

          // ── Stats ─────────────────────────────────────────────
          Row(children: [
            _stat('⏱️', 'Uptime', _fmt(_uptime)),
            const SizedBox(width: 10),
            _stat('⚡', 'Commands', '$_cmds+'),
            const SizedBox(width: 10),
            _stat('🛡️', 'Anti-Ban', 'ON'),
          ]).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 22),

          Text('FEATURES', style: GoogleFonts.jetBrainsMono(
            fontSize: 10, letterSpacing: 3, color: const Color(0xFF4A5280))),
          const SizedBox(height: 10),

          // ── Feature cards ─────────────────────────────────────
          ...[
            ('🤖', 'AI Mode', 'Gemini Pro powered', const Color(0xFF25D366)),
            ('📥', 'Downloader', 'YT, TikTok, FB & more', const Color(0xFF00E5FF)),
            ('🎮', 'Games', 'Fun group games', const Color(0xFFA259FF)),
            ('⚙️', 'Settings', 'Configure via WhatsApp (.settings)', const Color(0xFFFFD93D)),
          ].asMap().entries.map((e) {
            final i = e.key; final v = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF060A14), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: v.$4.withOpacity(0.12)),
              ),
              child: ListTile(
                leading: Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: v.$4.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(v.$1, style: const TextStyle(fontSize: 20)))),
                title: Text(v.$2, style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                subtitle: Text(v.$3, style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: const Color(0xFF4A5280))),
                trailing: Icon(Icons.arrow_forward_ios, size: 13, color: v.$4.withOpacity(0.4)),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 150 + i * 80)).slideX(begin: 0.05);
          }),

          const SizedBox(height: 16),

          // ── Info ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.12)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFF25D366), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'WhatsApp ල .menu type කරලා all commands බලන්න.',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white54, height: 1.5),
              )),
            ]),
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _stat(String e, String l, String v) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF060A14), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25D366).withOpacity(0.08)),
      ),
      child: Column(children: [
        Text(e, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(v, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(l, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: const Color(0xFF4A5280))),
      ]),
    ),
  );
}
