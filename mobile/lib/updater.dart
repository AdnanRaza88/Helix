import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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
