import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_model.dart';

/// Result state for In-App Update check
class AppUpdateInfo {
  final bool isUpdateAvailable;
  final String currentVersion;
  final AppRelease? latestRelease;

  const AppUpdateInfo({
    required this.isUpdateAvailable,
    required this.currentVersion,
    this.latestRelease,
  });
}

/// In-app update from GitHub Releases.
class AppUpdateService {
  const AppUpdateService();

  static const _lastCheckKey = 'app_update_last_check';

  /// Automatic check, at most once per [interval]; null when skipped.
  Future<AppUpdateInfo?> checkForUpdateDaily({
    Duration interval = const Duration(hours: 24),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastCheckKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < interval.inMilliseconds) return null;
    await prefs.setInt(_lastCheckKey, now);
    return checkForUpdate();
  }

  /// Check GitHub Releases for a newer version.
  Future<AppUpdateInfo> checkForUpdate() async {
    String currentVersionStr = '0.0.0';
    int currentBuild = 0;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersionStr = packageInfo.version;
      currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    } catch (_) {}

    // Latest release from the public GitHub Releases API (CI publishes it from a v* tag).
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/ridhoarmand/finoteku/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final release = AppRelease.fromGitHubJson(data);
        final isNewer = isNewerRelease(
          release.tagName,
          release.buildNumber,
          currentVersionStr,
          currentBuild,
        );

        return AppUpdateInfo(
          isUpdateAvailable: isNewer,
          currentVersion: currentVersionStr,
          latestRelease: isNewer ? release : null,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] GitHub check failed: $e');
    }

    return AppUpdateInfo(
      isUpdateAvailable: false,
      currentVersion: currentVersionStr,
    );
  }

  /// Launch APK download URL or Storage link
  Future<bool> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('[AppUpdateService] Error launching download URL: $e');
      return false;
    }
  }
}

/// Provider for AppUpdateService
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) => const AppUpdateService());

/// True when [latest] (+ optional build) is newer than the installed version.
/// Names compare part by part ("0.10.0" > "0.9.9"); with equal names the build
/// number decides. Anything after "+" or "-" in a name is ignored.
bool isNewerRelease(
  String latest,
  int? latestBuild,
  String current,
  int currentBuild,
) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp(r'^v'), '')
      .split(RegExp(r'[+-]'))
      .first
      .split('.')
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final a = parts(latest), b = parts(current);
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return latestBuild != null && latestBuild > currentBuild;
}
