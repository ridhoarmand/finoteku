import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_model.dart';
import 'supabase_service.dart';

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

/// Service for checking and managing Supabase & GitHub Releases In-App Update
class AppUpdateService {
  final SupabaseClient _supabase;

  AppUpdateService(this._supabase);

  /// Check for latest version via Supabase `app_versions` table
  Future<AppUpdateInfo> checkForUpdate() async {
    String currentVersionStr = '0.5.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersionStr = packageInfo.version;
    } catch (_) {}

    // 1. Try fetching latest release from Supabase `app_versions` table
    try {
      final response = await _supabase
          .from('app_versions')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final release = AppRelease.fromSupabaseJson(response);
        final isNewer = _isVersionNewer(release.tagName, currentVersionStr);

        return AppUpdateInfo(
          isUpdateAvailable: isNewer,
          currentVersion: currentVersionStr,
          latestRelease: isNewer ? release : null,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Supabase version check fallback: $e');
    }

    // 2. Fallback: GitHub Releases Public API
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/ridhoarmand/finoteku/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final release = AppRelease.fromGitHubJson(data);
        final isNewer = _isVersionNewer(release.tagName, currentVersionStr);

        return AppUpdateInfo(
          isUpdateAvailable: isNewer,
          currentVersion: currentVersionStr,
          latestRelease: isNewer ? release : null,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] GitHub fallback error: $e');
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
  final supabase = ref.watch(supabaseProvider);
  return AppUpdateService(supabase);
});

/// FutureProvider to check update status on-demand or auto-check
final checkForUpdateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  final service = ref.watch(appUpdateServiceProvider);
  return await service.checkForUpdate();
});
