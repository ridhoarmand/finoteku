import 'package:flutter/foundation.dart';

/// Model representing an App Release for In-App Update
@immutable
class AppRelease {
  final String tagName;

  /// Android versionCode (pubspec `+N`); GitHub releases do not carry it, so null there.
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

  /// Parse a GitHub Releases API response.
  factory AppRelease.fromGitHubJson(Map<String, dynamic> json, {List<String> abis = const []}) {
    final tagName = (json['tag_name'] as String?) ?? '';
    final title = (json['name'] as String?) ?? tagName;
    final body =
        (json['body'] as String?) ??
        'Pembaruan aplikasi terbaru telah tersedia.';
    final publishedAt = (json['published_at'] as String?) ?? '';

    final apks = <String, String>{
      for (final a in (json['assets'] as List<dynamic>? ?? const []))
        if (a is Map<String, dynamic> &&
            a['browser_download_url'] is String &&
            ((a['name'] as String?) ?? '').toLowerCase().endsWith('.apk'))
          (a['name'] as String).toLowerCase(): a['browser_download_url'] as String,
    };
    // the APK built for this phone's ABI (CI names them finoteku-vX-<abi>.apk), in the
    // phone's preference order; else the universal one; else the release page
    String? pick(String part) => apks.entries.where((e) => e.key.contains(part)).firstOrNull?.value;
    final downloadUrl =
        abis.map((abi) => pick('-${abi.toLowerCase()}.apk')).nonNulls.firstOrNull ??
        pick('universal') ??
        (json['html_url'] as String?) ??
        'https://github.com/ridhoarmand/finoteku/releases';

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
