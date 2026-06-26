import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show navigatorKey;
import '../screens/api_service.dart';
import '../screens/control_panel_screen.dart';

/// Global FAB — injected into Overlay so it floats above every screen.
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
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<String?> _savedPhone() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString('phone');
    } catch (_) {
      return null;
    }
  }

  void _onTap() async {
    HapticFeedback.mediumImpact();
    final phone = await _savedPhone();
    if (!mounted) return;
    showDialog(
      context: navigatorKey.currentContext!,
      barrierColor: Colors.black87,
      builder: (_) => _PasswordDialog(phone: phone),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// ── Password Dialog ────────────────────────────────────────────
class _PasswordDialog extends StatefulWidget {
  final String? phone;
  const _PasswordDialog({this.phone});
  @override State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _resendSent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pw = _ctrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _error = 'Password enter කරන්න');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final phone = widget.phone ?? '';
      if (phone.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ControlPanelScreen()));
        return;
      }

      final res = await ApiService.verifySettingsPassword(phone, pw);
      if (!mounted) return;

      if (res['ok'] == true) {
        Navigator.pop(context);
        navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ControlPanelScreen()));
      } else {
        setState(() {
          _error = res['error'] ?? 'Password වැරදියි.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Server reach වෙන්නේ නැහැ.'; _loading = false; });
    }
  }

  Future<void> _resend() async {
    final phone = widget.phone ?? '';
    if (phone.isEmpty) {
      setState(() => _error = 'Phone number නැහැ.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.resendSettingsPassword(phone);
      if (mounted) setState(() { _resendSent = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Resend fail.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF080D14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.25)),
          boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.12), blurRadius: 32)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            const Text('Control Panel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Password enter කරන්න',
                style: TextStyle(fontSize: 13, color: Colors.white54)),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _error != null
                      ? const Color(0xFFFF4757).withOpacity(0.6)
                      : const Color(0xFF25D366).withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _ctrl,
                obscureText: _obscure,
                enabled: !_loading,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Enter password...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.white38, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _verify(),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4757), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12))),
              ]),
            ],

            if (_resendSent) ...[
              const SizedBox(height: 10),
              const Row(children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF25D366), size: 14),
                SizedBox(width: 6),
                Text('Password WhatsApp එකට send කළා!',
                    style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
              ]),
            ],

            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Resend',
                      style: TextStyle(color: Color(0xFF25D366), fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Open Panel',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),

            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
