import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _versionUrl =
    'https://raw.githubusercontent.com/AdnanRaza88/Helix/main/mobile/version.json';

class AppUpdateInfo {
  AppUpdateInfo({
    required this.version,
    required this.build,
    required this.notes,
    this.apkUrl,
  });

  final String version;
  final int build;
  final String notes;
  final String? apkUrl;
}

class UpdateChecker {
  Future<AppUpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final currentVersion = info.version;

      final res = await http.get(Uri.parse(_versionUrl)).timeout(
            const Duration(seconds: 8),
          );
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteVersion = (data['version'] as String?) ?? '';
      final remoteBuild = (data['build'] as num?)?.toInt() ?? 0;
      final notes = (data['notes'] as String?) ?? 'Bug fixes and improvements';
      final apkUrl = data['apk_url'] as String?;

      if (remoteBuild > currentBuild ||
          (remoteBuild == currentBuild &&
              remoteVersion != currentVersion &&
              remoteVersion.isNotEmpty)) {
        return AppUpdateInfo(
          version: remoteVersion,
          build: remoteBuild,
          notes: notes,
          apkUrl: apkUrl,
        );
      }
    } catch (_) {}
    return null;
  }
}

class UpdateInstaller {
  /// Downloads APK then opens system installer.
  /// Same package name + signing key keeps SQLite + SharedPreferences intact.
  static Future<String> downloadAndInstall(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final url = info.apkUrl;
    if (url == null || url.isEmpty) {
      throw Exception('No APK URL in version.json');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/helix-update.apk');
    if (await file.exists()) {
      await file.delete();
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req).timeout(const Duration(minutes: 5));
      if (res.statusCode != 200) {
        throw Exception('Download failed HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();
    } finally {
      client.close();
    }

    final uri = Uri.file(file.path);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      final web = Uri.parse(url);
      await launchUrl(web, mode: LaunchMode.externalApplication);
      return file.path;
    }
    return file.path;
  }

  static Future<void> openReleasePage(AppUpdateInfo info) async {
    final url = info.apkUrl ??
        'https://github.com/AdnanRaza88/Helix/releases/latest';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
