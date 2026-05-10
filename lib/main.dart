import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable network font fetching — use cached/bundled only
  GoogleFonts.config.allowRuntimeFetching = false;

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const UnityMdApp());
}

class UnityMdApp extends StatelessWidget {
  const UnityMdApp({super.key});

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
            primary: Color(0xFF25D366),
            secondary: Color(0xFF00E5FF),
            surface: Color(0xFF060A14),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
