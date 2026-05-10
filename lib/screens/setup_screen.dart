import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  final String? savedPhone;
  final String? pairCode;
  const SetupScreen({super.key, this.savedPhone, this.pairCode});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ctrl = TextEditingController();
  String _step = 'phone';
  String? _pairCode;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.savedPhone != null) _ctrl.text = widget.savedPhone!;
    if (widget.pairCode != null) {
      _pairCode = widget.pairCode;
      _step = 'pairing';
      _poll(_ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _getCode() async {
    final phone = _ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 7) { setState(() => _error = 'Valid number enter කරන්න'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.register(phone);
      if (res['ok'] == true) {
        if (res['status'] == 'connected') {
          await _save(phone);
          if (!mounted) return;
          _go(HomeScreen(phone: phone));
          return;
        }
        if (res['pairCode'] != null) {
          setState(() { _pairCode = res['pairCode']; _step = 'pairing'; _loading = false; });
          _poll(phone);
          return;
        }
      }
      setState(() { _error = res['error'] ?? 'Failed. Try again.'; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Server unreachable.'; _loading = false; });
    }
  }

  void _poll(String phone) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final st = await ApiService.status(phone);
        if (st['status'] == 'connected') {
          await _save(phone);
          if (!mounted) return;
          _go(HomeScreen(phone: phone));
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _error = 'Timeout. Try again.'; _step = 'phone'; });
  }

  Future<void> _save(String phone) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('phone', phone);
  }

  void _go(Widget w) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));

  void _copy() {
    Clipboard.setData(ClipboardData(text: _pairCode?.replaceAll('-', '') ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied!', style: GoogleFonts.jetBrainsMono()),
      backgroundColor: const Color(0xFF25D366),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text('UNITY-MD Setup',
          style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 2)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 'phone' ? _phoneUI() : _pairUI(),
        ),
      ),
    );
  }

  Widget _phoneUI() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Logo
    Center(child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset('assets/icon.png', width: 90, height: 90),
    ).animate().fadeIn().scale()),
    const SizedBox(height: 28),

    Text('WhatsApp Number', style: GoogleFonts.jetBrainsMono(
      fontSize: 11, letterSpacing: 3, color: const Color(0xFF4A5280))),
    const SizedBox(height: 10),

    TextField(
      controller: _ctrl,
      keyboardType: TextInputType.phone,
      style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        hintText: '94XXXXXXXXX',
        hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFF4A5280), fontSize: 18),
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF25D366)),
        filled: true, fillColor: const Color(0xFF060A14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF25D366).withOpacity(0.15))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF25D366).withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF25D366))),
      ),
    ),
    const SizedBox(height: 6),
    Text('Country code සමග (eg: 94771234567)',
      style: GoogleFonts.spaceGrotesk(fontSize: 11, color: const Color(0xFF4A5280))),

    const SizedBox(height: 24),

    // Steps
    ...[
      '1️⃣  Number enter කරලා "Connect" press කරන්න',
      '2️⃣  WhatsApp → Settings → Linked Devices',
      '3️⃣  Link a Device → 8-digit code enter කරන්න',
      '4️⃣  Bot active! 🚀',
    ].asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(e.value,
        style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white70, height: 1.5),
      ).animate().fadeIn(delay: Duration(milliseconds: 150 * e.key)),
    )),

    const SizedBox(height: 20),

    if (_error != null) Container(
      padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
      ),
      child: Text(_error!, style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF4757), fontSize: 13)),
    ),

    SizedBox(width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : _getCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            : Text('Connect WhatsApp',
                style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ).animate().fadeIn(delay: 400.ms),
  ]);

  Widget _pairUI() {
    final parts = (_pairCode ?? '').split('-');
    return Column(children: [
      const SizedBox(height: 20),

      // Pulsing icon
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF25D366).withOpacity(0.1),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3), width: 2),
        ),
        child: const Icon(Icons.link_rounded, color: Color(0xFF25D366), size: 34),
      ).animate(onPlay: (c) => c.repeat())
          .scaleXY(end: 1.08, duration: 1000.ms).then().scaleXY(end: 1.0, duration: 1000.ms),

      const SizedBox(height: 20),
      Text('PAIRING CODE', style: GoogleFonts.jetBrainsMono(
        fontSize: 11, letterSpacing: 4, color: const Color(0xFF4A5280))),
      const SizedBox(height: 16),

      // Code boxes
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: parts.asMap().entries.map((e) => Row(children: [
          ...e.value.split('').map((c) => Container(
            width: 44, height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.25)),
            ),
            child: Center(child: Text(c,
              style: GoogleFonts.jetBrainsMono(fontSize: 20,
                fontWeight: FontWeight.w900, color: const Color(0xFF25D366)))),
          )),
          if (e.key < parts.length - 1)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text('-', style: GoogleFonts.jetBrainsMono(
                fontSize: 18, color: const Color(0xFF4A5280)))),
        ])).toList(),
      ),

      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _copy,
        icon: const Icon(Icons.copy, size: 16, color: Color(0xFF25D366)),
        label: Text('Copy', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF25D366))),
      ),

      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.1)),
        ),
        child: Column(children: [
          ...[
            ('1.', 'WhatsApp open කරන්න'),
            ('2.', 'Settings → Linked Devices'),
            ('3.', '"Link a Device" tap'),
            ('4.', 'Code enter කරන්න ✅'),
          ].map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Text(s.$1, style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF25D366), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Text(s.$2, style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 13)),
            ]),
          )),
        ]),
      ),

      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2,
            color: const Color(0xFF25D366).withOpacity(0.6))),
        const SizedBox(width: 12),
        Text('Scan වෙනකං wait කරනවා...',
          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF4A5280))),
      ]),
    ]);
  }
}
