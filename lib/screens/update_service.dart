import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  // ── GitHub repo details ────────────────────────────────────
  static const String _owner   = 'mithunew20050722';
  static const String _repo    = 'unity-md-app';
  static const String _apiUrl  =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  // ── Auto-detect current version from pubspec.yaml ─────────
  static Future<String> get currentVersion async {
    final info = await PackageInfo.fromPlatform();
    return info.version; // e.g. "1.0.4"
  }

  // ── Check GitHub for latest release ───────────────────────
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = await currentVersion;

      final res = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body);

      // Tag format: "v1.0.1" → strip "v"
      final latestRaw = (json['tag_name'] as String? ?? '').replaceAll('v', '').trim();
      if (latestRaw.isEmpty) return null;

      // Compare versions — if latest > current, update available
      if (!_isNewer(latestRaw, current)) return null;

      // Find APK asset in release
      final assets = json['assets'] as List? ?? [];
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => null,
      );
      if (apkAsset == null) return null;

      return UpdateInfo(
        version:      latestRaw,
        downloadUrl:  apkAsset['browser_download_url'] as String,
        releaseNotes: json['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Download APK with progress callback ───────────────────
  static Future<File?> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    try {
      final dir  = await getExternalStorageDirectory() ??
                   await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/unity_md_update.apk');

      // Delete old file if exists
      if (await file.exists()) await file.delete();

      final req = http.Request('GET', Uri.parse(url));
      final res = await req.send().timeout(const Duration(minutes: 10));

      final total    = res.contentLength ?? 0;
      var   received = 0;
      final sink     = file.openWrite();

      await res.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }).asFuture();

      await sink.flush();
      await sink.close();
      return file;
    } catch (_) {
      return null;
    }
  }

  // ── Simple semantic version compare ───────────────────────
  // Returns true if [latest] is newer than [current]
  static bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final lv = i < l.length ? l[i] : 0;
        final cv = i < c.length ? c[i] : 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
