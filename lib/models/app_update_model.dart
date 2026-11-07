import 'package:flutter/foundation.dart';

/// Model representing an App Release for In-App Update
@immutable
class AppRelease {
  final String tagName;

  /// Android versionCode of the release (pubspec `+N`); null for old rows.
  final int? buildNumber;
  final String title;
  final String changelog;
  final String downloadUrl;
  final String publishedAt;
  final bool isMandatory;

  const AppRelease({
    required this.tagName,
    this.buildNumber,
    required this.title,
    required this.changelog,
    required this.downloadUrl,
    required this.publishedAt,
    this.isMandatory = false,
  });

  /// Parse Supabase Database `app_versions` record
  factory AppRelease.fromSupabaseJson(Map<String, dynamic> json) {
    final version = (json['version'] as String?) ?? '';
    final title = (json['title'] as String?) ?? 'Finoteku v$version';
    final changelog =
        (json['changelog'] as String?) ??
        'Pembaruan aplikasi Finoteku dengan fitur terbaru dan perbaikan bug.';
    final downloadUrl = (json['apk_url'] as String?) ?? '';
    final publishedAt = (json['created_at'] as String?) ?? '';
    final isMandatory = (json['is_mandatory'] as bool?) ?? false;

    return AppRelease(
      tagName: version.startsWith('v') ? version.substring(1) : version,
      buildNumber: (json['build_number'] as num?)?.toInt(),
      title: title,
      changelog: changelog,
      downloadUrl: downloadUrl,
      publishedAt: publishedAt,
      isMandatory: isMandatory,
    );
  }

  /// Parse GitHub Releases API JSON response (Fallback)
  factory AppRelease.fromGitHubJson(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String?) ?? '';
    final title = (json['name'] as String?) ?? tagName;
    final body =
        (json['body'] as String?) ??
        'Pembaruan aplikasi terbaru telah tersedia.';
    final publishedAt = (json['published_at'] as String?) ?? '';

    // Find the best matching APK download asset (arm64-v8a > universal > fallback)
    String downloadUrl =
        (json['html_url'] as String?) ??
        'https://github.com/ridhoarmand/finoteku/releases';
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      String? arm64Url;
      String? universalUrl;
      String? fallbackUrl;

      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String?)?.toLowerCase() ?? '';
          final browserUrl = asset['browser_download_url'] as String?;
          if (browserUrl != null && name.endsWith('.apk')) {
            if (name.contains('arm64-v8a')) {
              arm64Url = browserUrl;
            } else if (name.contains('universal') || name == 'finoteku.apk') {
              universalUrl = browserUrl;
            } else {
              fallbackUrl ??= browserUrl;
            }
          }
        }
      }
      downloadUrl = arm64Url ?? universalUrl ?? fallbackUrl ?? downloadUrl;
    }

    final isMandatory =
        body.toLowerCase().contains('[mandatory]') ||
        body.toLowerCase().contains('[wajib]');

    return AppRelease(
      tagName: tagName.startsWith('v') ? tagName.substring(1) : tagName,
      title: title,
      changelog: body,
      downloadUrl: downloadUrl,
      publishedAt: publishedAt,
      isMandatory: isMandatory,
    );
  }
}
