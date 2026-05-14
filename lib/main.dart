import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n.dart';
import 'screens/permission_screen.dart';
import 'screens/splash_screen.dart';

class LangNotifier extends ChangeNotifier {
  L10n _lang = L10n.en;
  L10n get lang => _lang;

  LangNotifier() { _load(); }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _lang = L10n.fromCode(p.getString('lang'));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle() async {
    _lang = _lang.isSinhala ? L10n.en : L10n.si;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', _lang.code);
    } catch (_) {}
    notifyListeners();
  }
}

final langNotifier = LangNotifier();

Future<Widget> _startScreen() async {
  try {
    final prefs  = await SharedPreferences.getInstance();
    final done   = prefs.getBool('perms_done') ?? false;

    if (done) return const SplashScreen();

    // Check if essential permission already granted
    final notifOk = await Permission.notification.status.isGranted;
    if (notifOk) {
      await prefs.setBool('perms_done', true);
      return const SplashScreen();
    }

    return const PermissionScreen();
  } catch (_) {
    return const SplashScreen();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    systemNavigationBarColor: Color(0xFF020408),
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final home = await _startScreen();

  runApp(UnityMdApp(home: home));
}

class UnityMdApp extends StatelessWidget {
  final Widget home;
  const UnityMdApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langNotifier,
      builder: (_, __) => MaterialApp(
        title: 'UNITY-MD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF020408),
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF25D366),
            secondary: Color(0xFF00E5FF),
            surface:   Color(0xFF060A14),
          ),
          useMaterial3: true,
        ),
        home: home,
      ),
    );
  }
}
