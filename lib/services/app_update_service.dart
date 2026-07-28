import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
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

/// Service for checking and managing GitHub Releases In-App Update
class AppUpdateService {
  static const String repoUrl = 'https://api.github.com/repos/ridhoarmand/finoteku/releases/latest';

  /// Check GitHub Releases for latest version
  Future<AppUpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version; // e.g. "0.4.0"

      final response = await http.get(
        Uri.parse(repoUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final release = AppRelease.fromGitHubJson(data);

        final isNewer = _isVersionNewer(release.tagName, currentVersionStr);

        return AppUpdateInfo(
          isUpdateAvailable: isNewer,
          currentVersion: currentVersionStr,
          latestRelease: isNewer ? release : null,
        );
      } else {
        return AppUpdateInfo(
          isUpdateAvailable: false,
          currentVersion: currentVersionStr,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking update: $e');
      final packageInfo = await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
        appName: 'Finoteku',
        packageName: 'com.finoteku.app',
        version: '0.4.0',
        buildNumber: '8',
      ));
      return AppUpdateInfo(
        isUpdateAvailable: false,
        currentVersion: packageInfo.version,
      );
    }
  }

  /// Launch APK download URL or Release page
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

  /// Compare Semantic Versions (e.g. "0.5.0" vs "0.4.0")
  bool _isVersionNewer(String latestTag, String currentVersion) {
    try {
      final cleanLatest = latestTag.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');

      final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Provider for AppUpdateService
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// FutureProvider to check update status on-demand or auto-check
final checkForUpdateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  final service = ref.watch(appUpdateServiceProvider);
  return await service.checkForUpdate();
});
