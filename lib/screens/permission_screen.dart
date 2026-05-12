import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'splash_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  @override State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<double>   _pulse;
  late Animation<Offset>   _slide;
  late Animation<double>   _fade;

  bool _requesting = false;

  // Permission definitions
  static const _perms = [
    _PermDef(
      icon:     Icons.notifications_rounded,
      color:    Color(0xFF25D366),
      title:    'Notifications',
      titleSi:  'දැනුම්දීම්',
      desc:     'Bot status alerts & startup messages',
      descSi:   'Bot status + startup message දැනගන්න',
      required: true,
    ),
    _PermDef(
      icon:     Icons.folder_rounded,
      color:    Color(0xFF00E5FF),
      title:    'Storage',
      titleSi:  'ගබඩාව',
      desc:     'Save chat history & voice notes locally',
      descSi:   'Chat history + voice notes save කරන්න',
      required: false,
    ),
    _PermDef(
      icon:     Icons.battery_charging_full_rounded,
      color:    Color(0xFFFFD93D),
      title:    'Battery Optimization',
      titleSi:  'Battery',
      desc:     'Keep bot running in background',
      descSi:   'Bot background ලෙ run කරන්න',
      required: false,
    ),
    _PermDef(
      icon:     Icons.power_settings_new_rounded,
      color:    Color(0xFFA259FF),
      title:    'Auto Start',
      titleSi:  'Auto Start',
      desc:     'Reconnect bot after phone restarts',
      descSi:   'Phone restart ලෙ bot reconnect',
      required: false,
    ),
  ];

  final Map<String, bool> _status = {};

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fade  = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn);

    _slideCtrl.forward();
    _checkAll();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAll() async {
    final n = await Permission.notification.status;
    final s = await _storageStatus();
    if (mounted) setState(() {
      _status['notification'] = n.isGranted;
      _status['storage']      = s;
      _status['battery']      = false; // can't check easily, assume no
      _status['autostart']    = false;
    });
  }

  Future<bool> _storageStatus() async {
    if (await Permission.storage.status.isGranted)              return true;
    if (await Permission.manageExternalStorage.status.isGranted) return true;
    if (await Permission.photos.status.isGranted)               return true;
    return false;
  }

  Future<void> _requestAll() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    HapticFeedback.mediumImpact();

    // 1. Notifications
    await Permission.notification.request();

    // 2. Storage (version-aware)
    final sdkVer = await _getSdkVersion();
    if (sdkVer >= 33) {
      await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
    } else if (sdkVer >= 30) {
      await Permission.manageExternalStorage.request();
    } else {
      await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
    }

    // 3. Battery optimization — opens system settings
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}

    await _checkAll();

    if (mounted) setState(() => _requesting = false);

    // Navigate if notifications granted (minimum required)
    final notifOk = await Permission.notification.status.isGranted;
    if (notifOk && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      _goNext();
    }
  }

  Future<int> _getSdkVersion() async {
    try {
      // Parse from platform
      final v = await const MethodChannel('flutter/platform').invokeMethod<String>('getVersion');
      return int.tryParse(v ?? '') ?? 33;
    } catch (_) { return 33; }
  }

  void _goNext() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SplashScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(children: [
        // Background glows
        Positioned(top: -100, left: -80,
            child: _glow(const Color(0xFF25D366), 280)),
        Positioned(bottom: -100, right: -80,
            child: _glow(const Color(0xFF00E5FF), 220)),

        // Content
        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(children: [
                const SizedBox(height: 32),

                // Icon
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 100 + _pulse.value * 8,
                      height: 100 + _pulse.value * 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF25D366)
                            .withOpacity(0.04 + _pulse.value * 0.03),
                      ),
                    ),
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A1A0E), Color(0xFF030610)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color: const Color(0xFF25D366)
                                .withOpacity(0.3 + _pulse.value * 0.2),
                            width: 2),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFF25D366)
                                .withOpacity(0.15 + _pulse.value * 0.1),
                            blurRadius: 24, spreadRadius: 4)],
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Color(0xFF25D366), size: 36),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // Title
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
                  ).createShader(r),
                  child: const Text('App Permissions', style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: Colors.white)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'UNITY-MD needs these to work properly.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF3A4270)),
                ),

                const SizedBox(height: 32),

                // Permission cards
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _perms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _permCard(_perms[i]),
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(children: [
                    // Grant button
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => ElevatedButton(
                          onPressed: _requesting ? null : _requestAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            shadowColor: const Color(0xFF25D366)
                                .withOpacity(0.4 + _pulse.value * 0.2),
                          ),
                          child: _requesting
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_open_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text('Grant Permissions',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Skip button
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Skip for now',
                          style: TextStyle(
                              color: Color(0xFF3A4270),
                              fontSize: 13)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _permCard(_PermDef p) {
    final key = p.title.toLowerCase().replaceAll(' ', '');
    final granted = _status[key.contains('notif') ? 'notification'
        : key.contains('stor') ? 'storage'
        : key.contains('batt') ? 'battery'
        : 'autostart'] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            p.color.withOpacity(granted ? 0.1 : 0.04),
            const Color(0xFF060A14),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: granted
              ? p.color.withOpacity(0.35)
              : Colors.white.withOpacity(0.06),
          width: 1.2,
        ),
        boxShadow: granted ? [BoxShadow(
            color: p.color.withOpacity(0.08), blurRadius: 12)] : [],
      ),
      child: Row(children: [
        // Icon container
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.color.withOpacity(0.15), p.color.withOpacity(0.05)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.color.withOpacity(0.2)),
          ),
          child: Icon(p.icon, color: p.color, size: 22),
        ),
        const SizedBox(width: 14),

        // Text
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(p.title, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              if (p.required) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFFF4757).withOpacity(0.3)),
                  ),
                  child: const Text('Required', style: TextStyle(
                      fontSize: 8, color: Color(0xFFFF4757),
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(p.desc, style: const TextStyle(
                fontSize: 11, color: Color(0xFF3A4270), height: 1.4)),
          ],
        )),

        const SizedBox(width: 12),

        // Status badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: granted
                ? p.color.withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: granted
                  ? p.color.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: granted ? [BoxShadow(
                color: p.color.withOpacity(0.25), blurRadius: 8)] : [],
          ),
          child: Icon(
            granted ? Icons.check_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: granted ? p.color : Colors.white24,
          ),
        ),
      ]),
    );
  }

  Widget _glow(Color c, double s) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [c.withOpacity(0.07), Colors.transparent])),
  );
}

class _PermDef {
  final IconData icon;
  final Color    color;
  final String   title, titleSi, desc, descSi;
  final bool     required;
  const _PermDef({
    required this.icon, required this.color,
    required this.title, required this.titleSi,
    required this.desc,  required this.descSi,
    required this.required,
  });
}
