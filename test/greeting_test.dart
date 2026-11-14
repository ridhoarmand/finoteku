import 'package:finoteku/features/home/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('greeting follows the hour (pagi / siang / sore / malam)', () {
    expect([3, 4, 10, 11, 14, 15, 17, 18, 23].map(greetingKey), [
      'greeting_night', 'greeting_morning', 'greeting_morning', 'greeting_afternoon', 'greeting_afternoon',
      'greeting_evening', 'greeting_evening', 'greeting_night', 'greeting_night',
    ]);
  });
}
