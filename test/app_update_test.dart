import 'package:finoteku/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version names compare part by part, not as text', () {
    expect(isNewerRelease('0.5.3', null, '0.5.2', 11), isTrue);
    expect(isNewerRelease('0.10.0', null, '0.9.9', 50), isTrue);
    expect(isNewerRelease('0.5.2', null, '0.5.3', 1), isFalse);
    expect(isNewerRelease('v1.0.0', null, '0.9.0', 1), isTrue);
  });

  test('same name: build number decides; "+N" in a name is not glued to the patch', () {
    expect(isNewerRelease('0.5.3', 13, '0.5.3', 12), isTrue);
    expect(isNewerRelease('0.5.3', 12, '0.5.3', 12), isFalse);
    expect(isNewerRelease('0.5.3', null, '0.5.3', 12), isFalse);
    expect(isNewerRelease('0.5.3+12', null, '0.5.12', 1), isFalse);
  });
}
