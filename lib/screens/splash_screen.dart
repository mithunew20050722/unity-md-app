import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _boot();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _msg = langNotifier.lang.starting);

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _go(const SetupScreen()); return;
    }

    final phone = prefs.getString('phone');
    if (phone == null) { _go(const SetupScreen()); return; }

    if (mounted) setState(() => _msg = langNotifier.lang.reconnecting);
    try {
      final res = await ApiService.reconnect(phone);
      if (!mounted) return;
      if (res['status'] == 'pairing') {
        _go(SetupScreen(savedPhone: phone, pairCode: res['pairCode']));
      } else {
        _go(HomeScreen(phone: phone));
      }
    } catch (_) {
      _go(HomeScreen(phone: phone));
    }
  }

  void _go(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, c) =>
          FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(children: [
        // Glow top-left
        Positioned(top: -80, left: -80, child: _glow(const Color(0xFF25D366), 260)),
        // Glow bottom-right
        Positioned(bottom: -100, right: -80, child: _glow(const Color(0xFF00E5FF), 220)),

        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Logo ring
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF25D366).withOpacity(0.35), width: 2),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF25D366).withOpacity(0.25),
                      blurRadius: 30, spreadRadius: 6)],
                  ),
                  child: ClipOval(child: Image.asset(
                    'assets/icon.png', width: 120, height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF25D366).withOpacity(0.2),
                      child: const Icon(Icons.smart_toy_rounded,
                        color: Color(0xFF25D366), size: 60)),
                  )),
                ),

                const SizedBox(height: 28),

                // App name — gradient via ShaderMask
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                  ).createShader(r),
                  child: const Text('UNITY-MD',
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      letterSpacing: 5, color: Colors.white,
                      fontFamily: 'monospace')),
                ),

                const SizedBox(height: 6),
                const Text('® UNITY TEAM',
                  style: TextStyle(
                    fontSize: 11, color: Color(0xFF4A5280),
                    letterSpacing: 3, fontFamily: 'monospace')),

                const SizedBox(height: 56),

                const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF25D366))),
                const SizedBox(height: 16),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_msg,
                    key: ValueKey(_msg),
                    style: const TextStyle(
                      fontSize: 12, color: Color(0xFF4A5280),
                      fontFamily: 'monospace')),
                ),
              ]),
            ),
          ),
        ),

        // Version
        Positioned(bottom: 28, left: 0, right: 0,
          child: FadeTransition(opacity: _fade,
            child: const Text('v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10, color: Color(0xFF1E2235),
                letterSpacing: 2, fontFamily: 'monospace')))),
      ]),
    );
  }

  Widget _glow(Color c, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c.withOpacity(0.08), Colors.transparent]),
    ),
  );
}
