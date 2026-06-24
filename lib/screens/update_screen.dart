import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'update_service.dart';

class UpdateScreen extends StatefulWidget {
  final UpdateInfo info;
  final Widget nextScreen;

  const UpdateScreen({
    super.key,
    required this.info,
    required this.nextScreen,
  });

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late Animation<double>   _pulse;

  _Phase _phase = _Phase.prompt;
  double _progress  = 0.0;
  String _statusMsg = '';
  File?  _apkFile;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _orbitCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  // ── Skip update → go to app ───────────────────────────────
  void _skip() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ── Start download ────────────────────────────────────────
  Future<void> _startDownload() async {
    // Request install permission on Android
    final installPerm = await Permission.requestInstallPackages.request();
    if (!installPerm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Install permission required to update.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _phase     = _Phase.downloading;
      _progress  = 0.0;
      _statusMsg = 'Preparing download...';
    });

    final file = await UpdateService.downloadApk(
      widget.info.downloadUrl,
      (p) {
        if (mounted) {
          setState(() {
            _progress  = p;
            _statusMsg = 'Downloading... ${(p * 100).toStringAsFixed(0)}%';
          });
        }
      },
    );

    if (!mounted) return;

    if (file == null) {
      setState(() {
        _phase     = _Phase.prompt;
        _statusMsg = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _apkFile   = file;
      _phase     = _Phase.done;
      _statusMsg = 'Download complete!';
    });

    // Auto-launch installer
    await _installApk(file);
  }

  Future<void> _installApk(File file) async {
    await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // back button disable — mandatory update
      child: Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(children: [
        // Background hex grid
        Positioned.fill(child: CustomPaint(painter: _HexBg())),

        // Glows
        Positioned(top: -80, left: -80,
            child: _glow(const Color(0xFF25D366), 280)),
        Positioned(bottom: -100, right: -60,
            child: _glow(const Color(0xFF00E5FF), 240)),

        // Content
        SafeArea(
          child: _phase == _Phase.downloading
              ? _buildDownloading()
              : _phase == _Phase.done
                  ? _buildDone()
                  : _buildPrompt(),
        ),
      ]),
    ),
    );
  }

  // ── Prompt screen ─────────────────────────────────────────
  Widget _buildPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Animated icon
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A1A0E),
                border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.4), width: 2),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF25D366)
                      .withOpacity(0.15 + _pulse.value * 0.15),
                  blurRadius: 30 + _pulse.value * 15,
                  spreadRadius: 4,
                )],
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Color(0xFF25D366), size: 48),
            ),
          ),

          const SizedBox(height: 28),

          // Title
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
            ).createShader(r),
            child: const Text('Update Available',
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1,
              )),
          ),

          const SizedBox(height: 12),

          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
              color: const Color(0xFF25D366).withOpacity(0.06),
            ),
            child: Text(
              'v$_currentVersion  →  v${widget.info.version}',
              style: const TextStyle(
                color: Color(0xFF25D366), fontSize: 13,
                fontFamily: 'monospace', letterSpacing: 1,
              ),
            ),
          ),

          // Release notes (if any)
          if (widget.info.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF060A14),
                border: Border.all(color: const Color(0xFF0D1425)),
              ),
              child: Text(
                widget.info.releaseNotes.length > 200
                    ? '${widget.info.releaseNotes.substring(0, 200)}...'
                    : widget.info.releaseNotes,
                style: const TextStyle(
                  color: Color(0xFF6A7290), fontSize: 12, height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Update button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF00C853)],
                ),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(0.35),
                  blurRadius: 16, offset: const Offset(0, 4),
                )],
              ),
              child: TextButton(
                onPressed: _startDownload,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Download & Install',
                      style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5,
                      )),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Mandatory notice
          Text(
            'Update required to continue using the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 11,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Downloading screen ────────────────────────────────────
  Widget _buildDownloading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Orbit animation
          SizedBox(width: 120, height: 120,
            child: AnimatedBuilder(
              animation: _orbitCtrl,
              builder: (_, __) => Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(120, 120),
                  painter: _OrbitRing(_orbitCtrl.value,
                      const Color(0xFF25D366), 50, 3.0)),
                CustomPaint(size: const Size(120, 120),
                  painter: _OrbitRing(1 - _orbitCtrl.value * 0.7,
                      const Color(0xFF00E5FF), 36, 2.0)),
                const Icon(Icons.download_rounded,
                    color: Color(0xFF25D366), size: 36),
              ]),
            ),
          ),

          const SizedBox(height: 32),

          const Text('Downloading Update',
            style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
            )),

          const SizedBox(height: 8),

          Text(_statusMsg,
            style: const TextStyle(
              color: Color(0xFF4A5280), fontSize: 13, fontFamily: 'monospace',
            )),

          const SizedBox(height: 28),

          // Progress bar
          Stack(children: [
            Container(height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
              )),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 6,
              width: (MediaQuery.of(context).size.width - 80) * _progress,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF00E5FF)]),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(0.5),
                  blurRadius: 8, spreadRadius: 1,
                )],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          Text('${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Color(0xFF25D366), fontSize: 28,
              fontWeight: FontWeight.w800, fontFamily: 'monospace',
            )),
        ]),
      ),
    );
  }

  // ── Done screen ───────────────────────────────────────────
  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A1A0E),
              border: Border.all(
                  color: const Color(0xFF25D366).withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF25D366), size: 48),
          ),

          const SizedBox(height: 24),

          const Text('Download Complete!',
            style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700,
            )),

          const SizedBox(height: 10),

          const Text('Installer is opening...',
            style: TextStyle(color: Color(0xFF4A5280), fontSize: 13)),

          const SizedBox(height: 32),

          // Manual install button (if auto didn't trigger)
          SizedBox(
            width: double.infinity, height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF00C853)],
                ),
              ),
              child: TextButton(
                onPressed: () {
                  if (_apkFile != null) _installApk(_apkFile!);
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Install Now',
                  style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
              ),
            ),
          ),
        ]),
      ),
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

enum _Phase { prompt, downloading, done }

// ── Painters ──────────────────────────────────────────────────

class _OrbitRing extends CustomPainter {
  final double t;
  final Color color;
  final double radius;
  final double dotR;
  const _OrbitRing(this.t, this.color, this.radius, this.dotR);

  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    final a   = t * 2 * pi;
    final pos = Offset(center.dx + radius * cos(a), center.dy + radius * sin(a));
    c.drawCircle(pos, dotR + 3, Paint()..color = color.withOpacity(0.2));
    c.drawCircle(pos, dotR,     Paint()..color = color);
    c.drawArc(Rect.fromCircle(center: center, radius: radius),
        a - 0.9, 0.9, false,
        Paint()..color = color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override bool shouldRepaint(_) => true;
}

class _HexBg extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFF25D366).withOpacity(0.015)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const r = 28.0;
    final h = r * sqrt(3);
    var col = 0;
    for (double x = -r; x < s.width + r; x += r * 1.5) {
      final yo = col.isOdd ? h / 2 : 0.0;
      for (double y = -h; y < s.height + h; y += h) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a  = pi / 3 * i - pi / 6;
          final pt = Offset(x + r * cos(a), y + yo + r * sin(a));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        c.drawPath(path, p);
      }
      col++;
    }
  }

  @override bool shouldRepaint(_) => false;
}
