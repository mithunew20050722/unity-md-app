import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'api_service.dart';

class ControlPanelScreen extends StatefulWidget {
  const ControlPanelScreen({super.key});
  @override State<ControlPanelScreen> createState() => _ControlPanelScreenState();
}

class _ControlPanelScreenState extends State<ControlPanelScreen> {
  InAppWebViewController? _webCtrl;
  double _progress = 0;
  bool _loading = true;
  bool _canGoBack = false;

  // Control panel root URL (dashboard index)
  static const String _panelUrl = 'http://158.178.246.29:3000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020408),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF00E5FF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('CONTROL PANEL',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1)),
          ),
        ]),
        actions: [
          // Back in webview
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white54, size: 18),
              onPressed: () => _webCtrl?.goBack(),
            ),
          // Reload
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: () => _webCtrl?.reload(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF25D366)),
                  minHeight: 2,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_panelUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          useShouldOverrideUrlLoading: false,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          supportZoom: false,
          userAgent:
              'Mozilla/5.0 (Linux; Android 12; Unity-MD-App) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        ),
        onWebViewCreated: (ctrl) => _webCtrl = ctrl,
        onLoadStart: (_, url) {
          setState(() { _loading = true; _progress = 0.1; });
        },
        onProgressChanged: (_, p) {
          setState(() => _progress = p / 100.0);
        },
        onLoadStop: (_, url) async {
          final canBack = await _webCtrl?.canGoBack() ?? false;
          if (mounted) setState(() { _loading = false; _canGoBack = canBack; });
        },
        onReceivedError: (_, __, error) {
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
  }
}
