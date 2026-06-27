import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show navigatorKey;
import '../screens/control_panel_screen.dart';

class ControlPanelFab extends StatefulWidget {
  const ControlPanelFab({super.key});
  @override State<ControlPanelFab> createState() => _ControlPanelFabState();
}

class _ControlPanelFabState extends State<ControlPanelFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _onTap() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: navigatorKey.currentContext!,
      barrierColor: Colors.black87,
      builder: (_) => const ControlPanelPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 90,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF25D366).withOpacity(0.45), blurRadius: 18, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
