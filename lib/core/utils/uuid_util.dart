import 'dart:math';

/// Generates a RFC 4122 compliant UUID v4 string
String generateUuidV4() {
  final Random random = Random.secure();
  final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));

  // Set version to 4 (0100)
  values[6] = (values[6] & 0x0f) | 0x40;
  // Set variant to 10xx (RFC 4122)
  values[8] = (values[8] & 0x3f) | 0x80;

  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) {
      buffer.write('-');
    }
    buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
