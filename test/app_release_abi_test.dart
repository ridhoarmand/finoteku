import 'package:finoteku/models/app_update_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = {
    'tag_name': 'v0.5.4',
    'html_url': 'https://github.com/x/y/releases/tag/v0.5.4',
    'assets': [
      for (final n in ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'universal'])
        {'name': 'finoteku-v0.5.4-$n.apk', 'browser_download_url': 'https://dl/$n.apk'},
    ],
  };

  test('picks the APK for the phone ABI, in the phone preference order', () {
    expect(AppRelease.fromGitHubJson(json, abis: ['arm64-v8a', 'armeabi-v7a']).downloadUrl, 'https://dl/arm64-v8a.apk');
    expect(AppRelease.fromGitHubJson(json, abis: ['armeabi-v7a', 'armeabi']).downloadUrl, 'https://dl/armeabi-v7a.apk');
    // "armeabi" must not match "armeabi-v7a"
    expect(AppRelease.fromGitHubJson(json, abis: ['armeabi']).downloadUrl, 'https://dl/universal.apk');
  });

  test('unknown ABI or none: universal, then the release page', () {
    expect(AppRelease.fromGitHubJson(json).downloadUrl, 'https://dl/universal.apk');
    expect(AppRelease.fromGitHubJson({...json, 'assets': []}).downloadUrl, json['html_url']);
  });
}
