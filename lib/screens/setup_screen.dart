import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

// ─── Countries ────────────────────────────────────────────────
class _C { final String f,n,c; const _C(this.f,this.n,this.c); }
const _countries = [
  // ── Popular / Top ──
  _C('🇱🇰','Sri Lanka','94'),
  _C('🇮🇳','India','91'),
  _C('🇵🇰','Pakistan','92'),
  _C('🇧🇩','Bangladesh','880'),
  _C('🇬🇧','United Kingdom','44'),
  _C('🇺🇸','USA','1'),
  _C('🇦🇺','Australia','61'),
  _C('🇩🇪','Germany','49'),
  _C('🇸🇦','Saudi Arabia','966'),
  _C('🇦🇪','UAE','971'),
  _C('🇲🇾','Malaysia','60'),
  _C('🇸🇬','Singapore','65'),
  _C('🇯🇵','Japan','81'),
  _C('🇰🇷','South Korea','82'),
  _C('🇧🇷','Brazil','55'),
  _C('🇿🇦','South Africa','27'),
  // ── A ──
  _C('🇦🇫','Afghanistan','93'),
  _C('🇦🇱','Albania','355'),
  _C('🇩🇿','Algeria','213'),
  _C('🇦🇩','Andorra','376'),
  _C('🇦🇴','Angola','244'),
  _C('🇦🇬','Antigua and Barbuda','1268'),
  _C('🇦🇷','Argentina','54'),
  _C('🇦🇲','Armenia','374'),
  _C('🇦🇹','Austria','43'),
  _C('🇦🇿','Azerbaijan','994'),
  // ── B ──
  _C('🇧🇸','Bahamas','1242'),
  _C('🇧🇭','Bahrain','973'),
  _C('🇧🇧','Barbados','1246'),
  _C('🇧🇾','Belarus','375'),
  _C('🇧🇪','Belgium','32'),
  _C('🇧🇿','Belize','501'),
  _C('🇧🇯','Benin','229'),
  _C('🇧🇹','Bhutan','975'),
  _C('🇧🇴','Bolivia','591'),
  _C('🇧🇦','Bosnia & Herzegovina','387'),
  _C('🇧🇼','Botswana','267'),
  _C('🇧🇳','Brunei','673'),
  _C('🇧🇬','Bulgaria','359'),
  _C('🇧🇫','Burkina Faso','226'),
  _C('🇧🇮','Burundi','257'),
  // ── C ──
  _C('🇨🇻','Cabo Verde','238'),
  _C('🇰🇭','Cambodia','855'),
  _C('🇨🇲','Cameroon','237'),
  _C('🇨🇦','Canada','1'),
  _C('🇨🇫','Central African Rep.','236'),
  _C('🇹🇩','Chad','235'),
  _C('🇨🇱','Chile','56'),
  _C('🇨🇳','China','86'),
  _C('🇨🇴','Colombia','57'),
  _C('🇰🇲','Comoros','269'),
  _C('🇨🇬','Congo','242'),
  _C('🇨🇩','Congo (DRC)','243'),
  _C('🇨🇷','Costa Rica','506'),
  _C('🇭🇷','Croatia','385'),
  _C('🇨🇺','Cuba','53'),
  _C('🇨🇾','Cyprus','357'),
  _C('🇨🇿','Czech Republic','420'),
  // ── D ──
  _C('🇩🇰','Denmark','45'),
  _C('🇩🇯','Djibouti','253'),
  _C('🇩🇲','Dominica','1767'),
  _C('🇩🇴','Dominican Republic','1809'),
  // ── E ──
  _C('🇪🇨','Ecuador','593'),
  _C('🇪🇬','Egypt','20'),
  _C('🇸🇻','El Salvador','503'),
  _C('🇬🇶','Equatorial Guinea','240'),
  _C('🇪🇷','Eritrea','291'),
  _C('🇪🇪','Estonia','372'),
  _C('🇸🇿','Eswatini','268'),
  _C('🇪🇹','Ethiopia','251'),
  // ── F ──
  _C('🇫🇯','Fiji','679'),
  _C('🇫🇮','Finland','358'),
  _C('🇫🇷','France','33'),
  // ── G ──
  _C('🇬🇦','Gabon','241'),
  _C('🇬🇲','Gambia','220'),
  _C('🇬🇪','Georgia','995'),
  _C('🇬🇭','Ghana','233'),
  _C('🇬🇷','Greece','30'),
  _C('🇬🇩','Grenada','1473'),
  _C('🇬🇹','Guatemala','502'),
  _C('🇬🇳','Guinea','224'),
  _C('🇬🇼','Guinea-Bissau','245'),
  _C('🇬🇾','Guyana','592'),
  // ── H ──
  _C('🇭🇹','Haiti','509'),
  _C('🇭🇳','Honduras','504'),
  _C('🇭🇺','Hungary','36'),
  // ── I ──
  _C('🇮🇸','Iceland','354'),
  _C('🇮🇩','Indonesia','62'),
  _C('🇮🇷','Iran','98'),
  _C('🇮🇶','Iraq','964'),
  _C('🇮🇪','Ireland','353'),
  _C('🇮🇱','Israel','972'),
  _C('🇮🇹','Italy','39'),
  _C('🇯🇲','Jamaica','1876'),
  _C('🇯🇴','Jordan','962'),
  // ── K ──
  _C('🇰🇿','Kazakhstan','7'),
  _C('🇰🇪','Kenya','254'),
  _C('🇰🇮','Kiribati','686'),
  _C('🇽🇰','Kosovo','383'),
  _C('🇰🇼','Kuwait','965'),
  _C('🇰🇬','Kyrgyzstan','996'),
  // ── L ──
  _C('🇱🇦','Laos','856'),
  _C('🇱🇻','Latvia','371'),
  _C('🇱🇧','Lebanon','961'),
  _C('🇱🇸','Lesotho','266'),
  _C('🇱🇷','Liberia','231'),
  _C('🇱🇾','Libya','218'),
  _C('🇱🇮','Liechtenstein','423'),
  _C('🇱🇹','Lithuania','370'),
  _C('🇱🇺','Luxembourg','352'),
  // ── M ──
  _C('🇲🇬','Madagascar','261'),
  _C('🇲🇼','Malawi','265'),
  _C('🇲🇻','Maldives','960'),
  _C('🇲🇱','Mali','223'),
  _C('🇲🇹','Malta','356'),
  _C('🇲🇭','Marshall Islands','692'),
  _C('🇲🇷','Mauritania','222'),
  _C('🇲🇺','Mauritius','230'),
  _C('🇲🇽','Mexico','52'),
  _C('🇫🇲','Micronesia','691'),
  _C('🇲🇩','Moldova','373'),
  _C('🇲🇨','Monaco','377'),
  _C('🇲🇳','Mongolia','976'),
  _C('🇲🇪','Montenegro','382'),
  _C('🇲🇦','Morocco','212'),
  _C('🇲🇿','Mozambique','258'),
  _C('🇲🇲','Myanmar','95'),
  // ── N ──
  _C('🇳🇦','Namibia','264'),
  _C('🇳🇷','Nauru','674'),
  _C('🇳🇵','Nepal','977'),
  _C('🇳🇱','Netherlands','31'),
  _C('🇳🇿','New Zealand','64'),
  _C('🇳🇮','Nicaragua','505'),
  _C('🇳🇪','Niger','227'),
  _C('🇳🇬','Nigeria','234'),
  _C('🇲🇰','North Macedonia','389'),
  _C('🇳🇴','Norway','47'),
  // ── O ──
  _C('🇴🇲','Oman','968'),
  // ── P ──
  _C('🇵🇼','Palau','680'),
  _C('🇵🇸','Palestine','970'),
  _C('🇵🇦','Panama','507'),
  _C('🇵🇬','Papua New Guinea','675'),
  _C('🇵🇾','Paraguay','595'),
  _C('🇵🇪','Peru','51'),
  _C('🇵🇭','Philippines','63'),
  _C('🇵🇱','Poland','48'),
  _C('🇵🇹','Portugal','351'),
  // ── Q ──
  _C('🇶🇦','Qatar','974'),
  // ── R ──
  _C('🇷🇴','Romania','40'),
  _C('🇷🇺','Russia','7'),
  _C('🇷🇼','Rwanda','250'),
  // ── S ──
  _C('🇰🇳','Saint Kitts & Nevis','1869'),
  _C('🇱🇨','Saint Lucia','1758'),
  _C('🇻🇨','Saint Vincent','1784'),
  _C('🇼🇸','Samoa','685'),
  _C('🇸🇲','San Marino','378'),
  _C('🇸🇹','Sao Tome & Principe','239'),
  _C('🇸🇳','Senegal','221'),
  _C('🇷🇸','Serbia','381'),
  _C('🇸🇨','Seychelles','248'),
  _C('🇸🇱','Sierra Leone','232'),
  _C('🇸🇧','Solomon Islands','677'),
  _C('🇸🇴','Somalia','252'),
  _C('🇸🇸','South Sudan','211'),
  _C('🇪🇸','Spain','34'),
  _C('🇸🇩','Sudan','249'),
  _C('🇸🇷','Suriname','597'),
  _C('🇸🇪','Sweden','46'),
  _C('🇨🇭','Switzerland','41'),
  _C('🇸🇾','Syria','963'),
  // ── T ──
  _C('🇹🇼','Taiwan','886'),
  _C('🇹🇯','Tajikistan','992'),
  _C('🇹🇿','Tanzania','255'),
  _C('🇹🇭','Thailand','66'),
  _C('🇹🇱','Timor-Leste','670'),
  _C('🇹🇬','Togo','228'),
  _C('🇹🇴','Tonga','676'),
  _C('🇹🇹','Trinidad & Tobago','1868'),
  _C('🇹🇳','Tunisia','216'),
  _C('🇹🇷','Turkey','90'),
  _C('🇹🇲','Turkmenistan','993'),
  _C('🇹🇻','Tuvalu','688'),
  // ── U ──
  _C('🇺🇬','Uganda','256'),
  _C('🇺🇦','Ukraine','380'),
  _C('🇺🇾','Uruguay','598'),
  _C('🇺🇿','Uzbekistan','998'),
  // ── V ──
  _C('🇻🇺','Vanuatu','678'),
  _C('🇻🇪','Venezuela','58'),
  _C('🇻🇳','Vietnam','84'),
  // ── Y ──
  _C('🇾🇪','Yemen','967'),
  // ── Z ──
  _C('🇿🇲','Zambia','260'),
  _C('🇿🇼','Zimbabwe','263'),
];

// ─── Orbit ring painter ───────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double angle;
  final Color color;
  _OrbitPainter(this.angle, this.color);
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final r  = s.width / 2 - 1;
    c.drawCircle(Offset(cx, cy), r,
      Paint()..color = color.withOpacity(0.2)
             ..style  = PaintingStyle.stroke
             ..strokeWidth = 1);
    final dx = cx + r * cos(angle), dy = cy + r * sin(angle);
    final glow = Paint()
      ..color     = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    c.drawCircle(Offset(dx, dy), 4, glow);
    c.drawCircle(Offset(dx, dy), 3,
      Paint()..color = color);
  }
  @override bool shouldRepaint(_OrbitPainter o) => o.angle != angle;
}

// ─── Setup Screen ─────────────────────────────────────────────
class SetupScreen extends StatefulWidget {
  final String? savedPhone;
  final String? pairCode;
  const SetupScreen({super.key, this.savedPhone, this.pairCode});
  @override State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  _C _country = _countries.first;
  String _step = 'phone';
  String? _pairCode;
  String? _error;
  bool _loading = false;

  // animations
  late AnimationController _orbitCtrl, _fadeCtrl, _pulseCtrl;
  late Animation<double>   _fadeAnim,  _pulseAnim;

  @override
  void initState() {
    super.initState();

    _orbitCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _fadeCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeCtrl.forward();

    if (widget.savedPhone != null) {
      final s = widget.savedPhone!;
      for (final c in _countries) {
        if (s.startsWith(c.c)) {
          _country  = c;
          _ctrl.text = s.substring(c.c.length);
          break;
        }
      }
      if (_ctrl.text.isEmpty) _ctrl.text = s;
    }
    if (widget.pairCode != null) {
      _pairCode = widget.pairCode;
      _step     = 'pairing';
      _poll(_fullPhone());
    }
  }

  @override
  void dispose() {
    _orbitCtrl.dispose(); _fadeCtrl.dispose(); _pulseCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String _fullPhone() =>
      '${_country.c}${_ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')}';

  Future<void> _connect() async {
    final l     = langNotifier.lang;
    final local = _ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (local.length < 6) { setState(() => _error = l.invalidPhone); return; }
    final phone = _fullPhone();
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.register(phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        if (res['status'] == 'connected') { await _save(phone); _go(HomeScreen(phone: phone)); return; }
        if (res['pairCode'] != null) {
          setState(() { _pairCode = res['pairCode']; _step = 'pairing'; _loading = false; });
          _poll(phone); return;
        }
      }
      setState(() { _error = res['error'] ?? 'Failed.'; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = langNotifier.lang.serverError; _loading = false; });
    }
  }

  void _poll(String phone) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final st = await ApiService.status(phone);
        if (st['status'] == 'connected') { await _save(phone); _go(HomeScreen(phone: phone)); return; }
      } catch (_) {}
    }
    if (mounted) setState(() { _error = langNotifier.lang.timeout; _step = 'phone'; });
  }

  Future<void> _save(String p) async {
    try { final sp = await SharedPreferences.getInstance(); await sp.setString('phone', p); } catch (_) {}
  }

  void _go(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _pairCode?.replaceAll('-', '') ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Copied!', style: TextStyle(fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF25D366),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _pickCountry() => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF060A14),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Column(children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white12,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      Text(langNotifier.lang.selectCountry,
          style: const TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w700)),
      const Divider(color: Colors.white10),
      Expanded(child: ListView.separated(
        itemCount: _countries.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (_, i) {
          final c = _countries[i]; final sel = c.c == _country.c;
          return ListTile(
            leading: Text(c.f, style: const TextStyle(fontSize: 22)),
            title: Text(c.n, style: TextStyle(color: Colors.white,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
            trailing: Text('+${c.c}', style: TextStyle(
                fontFamily: 'monospace', fontSize: 13,
                color: sel ? const Color(0xFF25D366) : const Color(0xFF4A5280))),
            selected: sel,
            selectedTileColor: const Color(0xFF25D366).withOpacity(0.06),
            onTap: () { setState(() => _country = c); Navigator.pop(context); },
          );
        },
      )),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langNotifier,
      builder: (_, __) => Scaffold(
        backgroundColor: const Color(0xFF020408),
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          title: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF00E5FF)]).createShader(r),
            child: const Text('UNITY-MD', style: TextStyle(
                fontFamily: 'monospace', fontSize: 16,
                fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
          ),
          actions: [
            GestureDetector(
              onTap: () => langNotifier.toggle(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF060A14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                ),
                child: Text(langNotifier.lang.isSinhala ? '🇱🇰 SI' : '🇬🇧 EN',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11,
                        color: Color(0xFF25D366))),
              ),
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(children: [
            // Grid background
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            // Glow top-left
            Positioned(top: -100, left: -100,
                child: _glow(const Color(0xFF25D366), 300)),
            // Glow bottom-right
            Positioned(bottom: -80, right: -80,
                child: _glow(const Color(0xFF00E5FF), 220)),
            // Corner decorations
            ..._corners(),
            // Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: _step == 'phone' ? _phoneUI() : _pairUI(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _phoneUI() {
    final l = langNotifier.lang;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Logo with orbit ring ──────────────────────────────
      Center(child: SizedBox(width: 160, height: 160,
        child: AnimatedBuilder(
          animation: _orbitCtrl,
          builder: (_, __) => Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(160, 160),
              painter: _OrbitPainter(_orbitCtrl.value * 2 * pi,
                  const Color(0xFF25D366))),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.25), width: 1.5),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.15),
                    blurRadius: 24, spreadRadius: 4)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: Image.asset('assets/icon.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF060A14),
                      child: const Icon(Icons.smart_toy_rounded,
                          color: Color(0xFF25D366), size: 50)))),
            ),
          ]),
        ),
      )),
      const SizedBox(height: 20),

      // Title
      Center(child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF00E5FF), Color(0xFFA259FF)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
        ).createShader(r),
        child: const Text('CONNECT BOT', style: TextStyle(
            fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w900,
            letterSpacing: 4, color: Colors.white)),
      )),
      const SizedBox(height: 4),
      const Center(child: Text('Link your WhatsApp number', style: TextStyle(
          fontSize: 12, color: Color(0xFF4A5280)))),
      const SizedBox(height: 28),

      // ── Glass card ────────────────────────────────────────
      _glassCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.3),
                    blurRadius: 12)],
              ),
              child: const Icon(Icons.phone_android_rounded,
                  color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.whatsappNumber, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(l.phoneHelper, style: const TextStyle(
                  fontSize: 10, color: Color(0xFF4A5280))),
            ]),
          ]),
          const SizedBox(height: 20),

          // Country + number
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: _pickCountry,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF25D366).withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_country.f, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('+${_country.c}', style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 15,
                      fontWeight: FontWeight.w700, color: Color(0xFF25D366))),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      color: Color(0xFF4A5280), size: 18),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _neonField(_ctrl, '7XXXXXXXX')),
          ]),
          const SizedBox(height: 16),

          // Steps
          ...l.setupSteps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFF25D366), shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF25D366).withOpacity(0.6),
                          blurRadius: 6)])),
              Expanded(child: Text(s, style: const TextStyle(
                  fontSize: 12, color: Colors.white60, height: 1.5))),
            ]),
          )),
        ],
      )),

      if (_error != null) ...[
        const SizedBox(height: 14),
        _errorCard(_error!),
      ],

      const SizedBox(height: 20),

      // Connect button
      _neonButton(
        label: l.connectBtn,
        icon: Icons.link_rounded,
        loading: _loading,
        onTap: _connect,
        gradient: const [Color(0xFF25D366), Color(0xFF00B894)],
        glowColor: const Color(0xFF25D366),
      ),
      const SizedBox(height: 20),
    ]);
  }

  Widget _pairUI() {
    final parts = (_pairCode ?? '').split('-');
    return Column(children: [
      const SizedBox(height: 16),

      // Pulsing icon
      Center(child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF25D366).withOpacity(0.08 * _pulseAnim.value),
            border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.4 * _pulseAnim.value),
                width: 2),
            boxShadow: [BoxShadow(
                color: const Color(0xFF25D366).withOpacity(0.25 * _pulseAnim.value),
                blurRadius: 20 + 10 * _pulseAnim.value, spreadRadius: 4)],
          ),
          child: const Icon(Icons.link_rounded,
              color: Color(0xFF25D366), size: 36),
        ),
      )),
      const SizedBox(height: 20),

      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF00E5FF)]).createShader(r),
        child: const Text('PAIRING CODE', style: TextStyle(
            fontFamily: 'monospace', fontSize: 11,
            letterSpacing: 4, color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 18),

      // Code boxes
      _glassCard(child: Column(children: [
        // Top shimmer line
        Container(height: 1, decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Colors.transparent, Color(0xFF25D366), Color(0xFF00E5FF), Colors.transparent]),
        )),
        const SizedBox(height: 20),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6, runSpacing: 6,
          children: parts.expand((part) => part.split('').map((ch) =>
            Container(
              width: 48, height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.1), blurRadius: 8)],
              ),
              child: Center(child: Text(ch, style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 24,
                  fontWeight: FontWeight.w900, color: Color(0xFF25D366)))),
            ),
          )).toList(),
        ),

        const SizedBox(height: 16),

        // Copy button
        GestureDetector(
          onTap: _copy,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.copy_rounded, color: Color(0xFF25D366), size: 15),
              SizedBox(width: 8),
              Text('Copy Code', style: TextStyle(fontFamily: 'monospace',
                  fontSize: 12, color: Color(0xFF25D366), fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ])),

      const SizedBox(height: 16),

      _glassCard(accentColor: const Color(0xFF00E5FF), child: Column(
        children: langNotifier.lang.pairingSteps.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(width: 26, height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(s.$1, style: const TextStyle(
                  fontFamily: 'monospace', color: Color(0xFF25D366),
                  fontSize: 11, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 12),
            Text(s.$2, style: const TextStyle(
                color: Colors.white70, fontSize: 13)),
          ]),
        )).toList(),
      )),

      const SizedBox(height: 24),

      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2,
                color: const Color(0xFF25D366).withOpacity(0.5 + 0.5 * _pulseAnim.value))),
        ),
        const SizedBox(width: 12),
        Text(langNotifier.lang.waitingScan, style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12, color: Color(0xFF4A5280))),
      ]),
      const SizedBox(height: 20),
    ]);
  }

  // ── Reusable widgets ──────────────────────────────────────────

  Widget _glassCard({required Widget child, Color? accentColor}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF060A14).withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (accentColor ?? const Color(0xFF25D366)).withOpacity(0.12)),
      boxShadow: [BoxShadow(
          color: (accentColor ?? const Color(0xFF25D366)).withOpacity(0.04),
          blurRadius: 24)],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(children: [
        // Top gradient line
        Positioned(top: 0, left: 0, right: 0, child: Container(height: 1,
          decoration: BoxDecoration(gradient: LinearGradient(
              colors: [Colors.transparent,
                (accentColor ?? const Color(0xFF25D366)).withOpacity(0.5),
                Colors.transparent])))),
        Padding(padding: const EdgeInsets.all(20), child: child),
      ]),
    ),
  );

  Widget _neonField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    keyboardType: TextInputType.phone,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'monospace',
          fontSize: 18, color: Color(0xFF4A5280)),
      filled: true,
      fillColor: const Color(0xFF25D366).withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF25D366).withOpacity(0.15))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF25D366).withOpacity(0.15))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF25D366), width: 1.5)),
    ),
  );

  Widget _neonButton({
    required String label, required IconData icon,
    required bool loading, required VoidCallback onTap,
    required List<Color> gradient, required Color glowColor,
  }) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        width: double.infinity, height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: glowColor.withOpacity(0.3 + 0.1 * _pulseAnim.value),
              blurRadius: 16 + 8 * _pulseAnim.value, spreadRadius: 1)],
        ),
        child: loading
          ? const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
      ),
    ),
  );

  Widget _errorCard(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFF4757).withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(
          color: Color(0xFFFF4757), fontSize: 13))),
    ]),
  );

  List<Widget> _corners() => [
    Positioned(top: 60, left: 16, child: _cornerBracket(true, true, const Color(0xFF25D366))),
    Positioned(top: 60, right: 16, child: _cornerBracket(true, false, const Color(0xFF00E5FF))),
    Positioned(bottom: 16, left: 16, child: _cornerBracket(false, true, const Color(0xFFA259FF))),
    Positioned(bottom: 16, right: 16, child: _cornerBracket(false, false, const Color(0xFF25D366))),
  ];

  Widget _cornerBracket(bool top, bool left, Color c) => SizedBox(width: 28, height: 28,
    child: CustomPaint(painter: _CornerPainter(top, left, c)));

  Widget _glow(Color c, double s) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c.withOpacity(0.08), Colors.transparent])));
}

// ─── Grid painter ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFF25D366).withOpacity(0.025)
        ..strokeWidth = 0.5;
    const step = 64.0;
    for (double x = 0; x < s.width; x += step)
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    for (double y = 0; y < s.height; y += step)
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }
  @override bool shouldRepaint(_) => false;
}

// ─── Corner bracket painter ───────────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool top, left;
  final Color color;
  const _CornerPainter(this.top, this.left, this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color.withOpacity(0.4)
        ..strokeWidth = 1.5 ..style = PaintingStyle.stroke;
    final x1 = left ? 0.0 : s.width, x2 = left ? s.width * 0.6 : s.width * 0.4;
    final y1 = top  ? 0.0 : s.height, y2 = top  ? s.height * 0.6 : s.height * 0.4;
    c.drawLine(Offset(x1, y1), Offset(x2, y1), p);
    c.drawLine(Offset(x1, y1), Offset(x1, y2), p);
    // Dot at corner
    c.drawCircle(Offset(x1, y1), 2,
        Paint()..color = color.withOpacity(0.4));
  }
  @override bool shouldRepaint(_) => false;
}
