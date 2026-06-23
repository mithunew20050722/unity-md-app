import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'api_service.dart';
import 'setup_screen.dart';
import 'home_screen.dart';
import 'update_service.dart';
import 'update_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fade, _scale, _pulse;
  String _msg = '';
  double _progress = 0.0;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _logoCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fade  = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.65, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _logoCtrl.forward();
    _boot();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _orbitCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
    if (!mounted) return;
    setState(() { _msg = langNotifier.lang.starting; _progress = 0.2; });

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) { _go(const SetupScreen()); return; }

    setState(() => _progress = 0.5);
    final phone = prefs.getString('phone');

    // ── Check for update ───────────────────────────────────
    setState(() { _msg = 'Checking for updates...'; _progress = 0.6; });
    final updateInfo = await UpdateService.checkForUpdate();
    if (!mounted) return;

    if (phone == null) {
      setState(() { _progress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 400));
      if (updateInfo != null) {
        _go(UpdateScreen(info: updateInfo, nextScreen: const SetupScreen()));
      } else {
        _go(const SetupScreen());
      }
      return;
    }

    if (mounted) setState(() { _msg = langNotifier.lang.reconnecting; _progress = 0.8; });
    try {
      final res = await ApiService.reconnect(phone);
      if (!mounted) return;
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      Widget next;
      if (res['status'] == 'pairing') {
        next = SetupScreen(savedPhone: phone, pairCode: res['pairCode']);
      } else {
        next = HomeScreen(phone: phone);
      }

      if (updateInfo != null) {
        _go(UpdateScreen(info: updateInfo, nextScreen: next));
      } else {
        _go(next);
      }
    } catch (_) {
      setState(() => _progress = 1.0);
      final next = HomeScreen(phone: phone);
      if (updateInfo != null) {
        _go(UpdateScreen(info: updateInfo, nextScreen: next));
      } else {
        _go(next);
      }
    }
  }

  void _go(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(children: [
        // Hex grid background
        Positioned.fill(child: CustomPaint(painter: _HexGridPainter())),

        // Background glows
        Positioned(top: -100, left: -100,
            child: _glow(const Color(0xFF25D366), 320)),
        Positioned(bottom: -120, right: -80,
            child: _glow(const Color(0xFF00E5FF), 280)),
        Positioned(top: sz.height * 0.35, left: sz.width * 0.45,
            child: _glow(const Color(0xFFA259FF), 200)),

        // Main content
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Orbital rings + logo
                SizedBox(width: 220, height: 220,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_orbitCtrl, _pulse]),
                    builder: (_, __) => Stack(alignment: Alignment.center, children: [
                      // Ring 3 — outer, slow, purple
                      CustomPaint(size: const Size(220, 220),
                        painter: _RingPainter(_orbitCtrl.value * 0.6,
                            const Color(0xFFA259FF), 100, 3.0)),
                      // Ring 2 — medium, cyan, reverse
                      CustomPaint(size: const Size(220, 220),
                        painter: _RingPainter(1.0 - _orbitCtrl.value * 0.9,
                            const Color(0xFF00E5FF), 78, 2.5)),
                      // Ring 1 — inner, green, fast
                      CustomPaint(size: const Size(220, 220),
                        painter: _RingPainter(_orbitCtrl.value * 1.4,
                            const Color(0xFF25D366), 57, 2.0)),
                      // Pulse halo
                      Container(
                        width: 110 + _pulse.value * 8,
                        height: 110 + _pulse.value * 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF25D366)
                              .withOpacity(0.04 + _pulse.value * 0.03),
                        ),
                      ),
                      // Logo circle
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0A1A0E),
                              const Color(0xFF030610),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                              color: const Color(0xFF25D366).withOpacity(0.35),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366)
                                  .withOpacity(0.2 + _pulse.value * 0.1),
                              blurRadius: 30 + _pulse.value * 10,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(child: Image.asset('assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(colors: [
                                const Color(0xFF25D366).withOpacity(0.2),
                                Colors.transparent,
                              ]),
                            ),
                            child: const Icon(Icons.smart_toy_rounded,
                                color: Color(0xFF25D366), size: 48)))),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 36),

                // Title
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF00E5FF), Color(0xFFA259FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(r),
                  child: const Text('UNITY-MD', style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w900,
                    letterSpacing: 8, color: Colors.white,
                    fontFamily: 'monospace')),
                ),
                const SizedBox(height: 8),
                // Divider line
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 24, height: 1,
                      color: const Color(0xFF25D366).withOpacity(0.3)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Text('® UNITY TEAM', style: TextStyle(
                      fontSize: 10, color: Color(0xFF4A5280),
                      letterSpacing: 3, fontFamily: 'monospace')),
                  ),
                  Container(width: 24, height: 1,
                      color: const Color(0xFF25D366).withOpacity(0.3)),
                ]),

                const SizedBox(height: 56),

                // Progress section
                SizedBox(width: 220, child: Column(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                    child: Text(_msg, key: ValueKey(_msg),
                      style: const TextStyle(fontSize: 11,
                          color: Color(0xFF4A5280), fontFamily: 'monospace',
                          letterSpacing: 1)),
                  ),
                  const SizedBox(height: 14),
                  // Progress bar with glow
                  Stack(children: [
                    Container(height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(4),
                        )),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      height: 3,
                      width: 220 * _progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF00E5FF)]),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(
                          color: const Color(0xFF25D366).withOpacity(0.6),
                          blurRadius: 6, spreadRadius: 1,
                        )],
                      ),
                    ),
                  ]),
                ])),
              ]),
            ),
          ),
        ),

        // Version tag
        Positioned(bottom: 28, left: 0, right: 0,
          child: FadeTransition(opacity: _fade,
            child: Text('v\$_version', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xFF1A2030),
                letterSpacing: 3, fontFamily: 'monospace')))),
      ]),
    );
  }

  Widget _glow(Color c, double size) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [c.withOpacity(0.08), Colors.transparent])));
}

// ── Orbital ring painter ──────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double t;
  final Color color;
  final double radius;
  final double dotRadius;
  const _RingPainter(this.t, this.color, this.radius, this.dotRadius);

  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);

    // Track
    c.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Orbiting dot + glow
    final angle = t * 2 * pi;
    final pos = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    c.drawCircle(pos, dotRadius + 4, Paint()..color = color.withOpacity(0.15));
    c.drawCircle(pos, dotRadius + 2, Paint()..color = color.withOpacity(0.3));
    c.drawCircle(pos, dotRadius, Paint()..color = color);

    // Trailing arc
    final startAngle = angle - 0.8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    c.drawArc(rect, startAngle, 0.8, false, Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round);
  }

  @override bool shouldRepaint(_) => true;
}

// ── Hex grid background ───────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFF25D366).withOpacity(0.018)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const r = 28.0;
    final h = r * sqrt(3);
    var col = 0;
    for (double x = -r; x < s.width + r; x += r * 1.5) {
      final yo = col.isOdd ? h / 2 : 0.0;
      for (double y = -h; y < s.height + h; y += h) {
        _hex(c, p, Offset(x, y + yo), r);
      }
      col++;
    }
  }

  void _hex(Canvas c, Paint p, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 3 * i - pi / 6;
      final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    c.drawPath(path, p);
  }

  @override bool shouldRepaint(_) => false;
}
