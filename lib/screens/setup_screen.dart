import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

// ─── Country data ─────────────────────────────────────────────────────────────
class _Country {
  final String flag, name, code;
  const _Country(this.flag, this.name, this.code);
}

const _countries = [
  _Country('🇱🇰', 'Sri Lanka',    '94'),
  _Country('🇮🇳', 'India',        '91'),
  _Country('🇵🇰', 'Pakistan',     '92'),
  _Country('🇧🇩', 'Bangladesh',   '880'),
  _Country('🇬🇧', 'UK',           '44'),
  _Country('🇺🇸', 'USA',          '1'),
  _Country('🇦🇺', 'Australia',    '61'),
  _Country('🇩🇪', 'Germany',      '49'),
  _Country('🇸🇦', 'Saudi Arabia', '966'),
  _Country('🇦🇪', 'UAE',          '971'),
  _Country('🇲🇾', 'Malaysia',     '60'),
  _Country('🇸🇬', 'Singapore',    '65'),
  _Country('🇯🇵', 'Japan',        '81'),
  _Country('🇰🇷', 'South Korea',  '82'),
  _Country('🇧🇷', 'Brazil',       '55'),
  _Country('🇿🇦', 'South Africa', '27'),
];

// ─── Shared text style helpers ────────────────────────────────────────────────
const _kLabel = TextStyle(
  fontFamily: 'monospace', fontSize: 11,
  letterSpacing: 3, color: Color(0xFF4A5280));

const _kBody = TextStyle(
  fontFamily: 'sans-serif', fontSize: 13,
  color: Colors.white70, height: 1.6);

const _kMono = TextStyle(
  fontFamily: 'monospace', fontSize: 18, color: Colors.white);

class SetupScreen extends StatefulWidget {
  final String? savedPhone;
  final String? pairCode;
  const SetupScreen({super.key, this.savedPhone, this.pairCode});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ctrl   = TextEditingController();
  _Country _country = _countries.first;
  String _step  = 'phone';
  String? _pairCode;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.savedPhone != null) {
      final saved = widget.savedPhone!;
      for (final c in _countries) {
        if (saved.startsWith(c.code)) {
          _country = c;
          _ctrl.text = saved.substring(c.code.length);
          break;
        }
      }
      if (_ctrl.text.isEmpty) _ctrl.text = saved;
    }
    if (widget.pairCode != null) {
      _pairCode = widget.pairCode;
      _step = 'pairing';
      _poll(_fullPhone());
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fullPhone() =>
      '${_country.code}${_ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')}';

  Future<void> _getCode() async {
    final l     = langNotifier.lang;
    final local = _ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (local.length < 6) { setState(() => _error = l.invalidPhone); return; }
    final phone = _fullPhone();
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.register(phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        if (res['status'] == 'connected') {
          await _save(phone); _go(HomeScreen(phone: phone)); return;
        }
        if (res['pairCode'] != null) {
          setState(() { _pairCode = res['pairCode']; _step = 'pairing'; _loading = false; });
          _poll(phone); return;
        }
      }
      setState(() { _error = res['error'] ?? 'Failed. Try again.'; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = l.serverError; _loading = false; });
    }
  }

  void _poll(String phone) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final st = await ApiService.status(phone);
        if (st['status'] == 'connected') {
          await _save(phone); _go(HomeScreen(phone: phone)); return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _error = langNotifier.lang.timeout; _step = 'phone'; });
  }

  Future<void> _save(String phone) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('phone', phone);
    } catch (_) {}
  }

  void _go(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _pairCode?.replaceAll('-', '') ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(langNotifier.lang.copied,
        style: const TextStyle(fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF25D366),
      duration: const Duration(seconds: 2),
    ));
  }

  void _pickCountry() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF060A14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        final l = langNotifier.lang;
        return Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(l.selectCountry,
            style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: ListView.separated(
            itemCount: _countries.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (_, i) {
              final c = _countries[i];
              final sel = c.code == _country.code;
              return ListTile(
                leading: Text(c.flag,
                  style: const TextStyle(fontSize: 22)),
                title: Text(c.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                trailing: Text('+${c.code}',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    color: sel
                        ? const Color(0xFF25D366)
                        : const Color(0xFF4A5280))),
                selected: sel,
                selectedTileColor: const Color(0xFF25D366).withOpacity(0.06),
                onTap: () { setState(() => _country = c); Navigator.pop(context); },
              );
            },
          )),
        ]);
      },
    );
  }

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
            title: Row(children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                ).createShader(r),
                child: const Text('UNITY-MD',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Text(l.setupTitle,
                style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4A5280))),
            ]),
            actions: [_langToggle()],
          ),
          body: Stack(children: [
            Positioned(top: -60, right: -60,
              child: _glow(const Color(0xFF25D366), 200)),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _step == 'phone' ? _phoneUI(l) : _pairUI(l),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _langToggle() => GestureDetector(
    onTap: () => langNotifier.toggle(),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF060A14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF25D366).withOpacity(0.3)),
      ),
      child: Text(
        langNotifier.lang.isSinhala ? '🇱🇰 SI' : '🇬🇧 EN',
        style: const TextStyle(
          fontFamily: 'monospace', fontSize: 11,
          color: Color(0xFF25D366))),
    ),
  );

  Widget _phoneUI(l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF25D366).withOpacity(0.2), width: 2),
          boxShadow: [BoxShadow(
            color: const Color(0xFF25D366).withOpacity(0.15),
            blurRadius: 24, spreadRadius: 4)],
        ),
        child: ClipOval(child: Image.asset('assets/icon.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF25D366).withOpacity(0.15),
            child: const Icon(Icons.smart_toy_rounded,
              color: Color(0xFF25D366), size: 50)))),
      ).animate().fadeIn().scaleXY(begin: 0.85, end: 1.0)),

      const SizedBox(height: 32),
      Text(l.whatsappNumber, style: _kLabel),
      const SizedBox(height: 10),

      // Country + number
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: _pickCountry,
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF060A14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_country.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text('+${_country.code}',
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF25D366))),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded,
                color: Color(0xFF4A5280), size: 18),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.phone,
          style: _kMono,
          decoration: InputDecoration(
            hintText: '7XXXXXXXX',
            hintStyle: _kMono.copyWith(color: const Color(0xFF4A5280)),
            filled: true, fillColor: const Color(0xFF060A14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: const Color(0xFF25D366).withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: const Color(0xFF25D366).withOpacity(0.15))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF25D366), width: 1.5)),
          ),
        )),
      ]),

      const SizedBox(height: 6),
      Text(l.phoneHelper,
        style: const TextStyle(fontSize: 11, color: Color(0xFF4A5280))),
      const SizedBox(height: 28),

      // Steps
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF25D366).withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: l.setupSteps.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(e.value, style: _kBody)
                  .animate().fadeIn(
                    delay: Duration(milliseconds: 120 * (e.key as int))),
            )).toList(),
        ),
      ),

      const SizedBox(height: 20),

      if (_error != null) Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4757).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF4757).withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!,
            style: const TextStyle(color: Color(0xFFFF4757), fontSize: 13))),
        ]),
      ),

      SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton(
          onPressed: _loading ? null : _getCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          ),
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.link_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(l.connectBtn,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
        ),
      ).animate().fadeIn(delay: 400.ms),

      const SizedBox(height: 20),
    ],
  );

  Widget _pairUI(l) {
    final parts = (_pairCode ?? '').split('-');
    return Column(children: [
      const SizedBox(height: 16),
      Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF25D366).withOpacity(0.08),
          border: Border.all(
            color: const Color(0xFF25D366).withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(
            color: const Color(0xFF25D366).withOpacity(0.15),
            blurRadius: 20, spreadRadius: 4)],
        ),
        child: const Icon(Icons.link_rounded,
          color: Color(0xFF25D366), size: 36),
      ).animate(onPlay: (c) => c.repeat())
          .scaleXY(end: 1.07, duration: 900.ms)
          .then().scaleXY(end: 1.0, duration: 900.ms),

      const SizedBox(height: 22),
      Text(l.pairingCode, style: _kLabel),
      const SizedBox(height: 18),

      // Code boxes
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: parts.asMap().entries.map((e) => Row(children: [
          ...e.value.split('').map((c) => Container(
            width: 44, height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.25))),
            child: Center(child: Text(c,
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF25D366)))),
          )),
          if (e.key < parts.length - 1)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text('-', style: TextStyle(
                fontFamily: 'monospace', fontSize: 18,
                color: Color(0xFF4A5280)))),
        ])).toList(),
      ),

      const SizedBox(height: 14),
      TextButton.icon(
        onPressed: _copy,
        icon: const Icon(Icons.copy_rounded,
          size: 16, color: Color(0xFF25D366)),
        label: Text(l.copy,
          style: const TextStyle(
            fontFamily: 'monospace', color: Color(0xFF25D366))),
      ),
      const SizedBox(height: 24),

      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF060A14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF25D366).withOpacity(0.1)),
        ),
        child: Column(children: l.pairingSteps.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Text(s.$1, style: const TextStyle(
              fontFamily: 'monospace', color: Color(0xFF25D366),
              fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text(s.$2, style: const TextStyle(
              color: Colors.white70, fontSize: 13)),
          ]),
        )).toList()),
      ),

      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: const Color(0xFF25D366).withOpacity(0.7))),
        const SizedBox(width: 12),
        Text(l.waitingScan, style: _kLabel),
      ]),
      const SizedBox(height: 20),
    ]);
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
