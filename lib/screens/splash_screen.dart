import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;
  String _msg = 'Starting...';

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _boot();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');

    if (phone == null) {
      _go(const SetupScreen());
      return;
    }

    setState(() => _msg = 'Reconnecting...');
    try {
      final res = await ApiService.reconnect(phone);
      if (!mounted) return;
      if (res['status'] == 'connected') {
        _go(HomeScreen(phone: phone));
      } else if (res['status'] == 'pairing') {
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
    Navigator.pushReplacement(context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => w,
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Center(
        child: FadeTransition(opacity: _fade,
          child: ScaleTransition(scale: _scale,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset('assets/icon.png', width: 110, height: 110),
              ),
              const SizedBox(height: 24),
              Text('UNITY-MD',
                style: GoogleFonts.orbitron(
                  fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4,
                  foreground: Paint()..shader = const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                  ).createShader(const Rect.fromLTWH(0,0,200,40)),
                ),
              ),
              const SizedBox(height: 6),
              Text('® UNITY TEAM',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF4A5280), letterSpacing: 3),
              ),
              const SizedBox(height: 48),
              const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)),
              ),
              const SizedBox(height: 14),
              Text(_msg,
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF4A5280)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
