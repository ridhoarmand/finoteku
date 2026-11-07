import 'package:finoteku/features/notification/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  test('Indonesian offsets map to WIB, WITA, WIT', () {
    expect(
      NotificationService.zoneForOffset(const Duration(hours: 7)).name,
      'Asia/Jakarta',
    );
    expect(
      NotificationService.zoneForOffset(const Duration(hours: 8)).name,
      'Asia/Makassar',
    );
    expect(
      NotificationService.zoneForOffset(const Duration(hours: 9)).name,
      'Asia/Jayapura',
    );
  });

  test(
    'other offsets get a zone with that offset; unknown falls back to Jakarta',
    () {
      final z = NotificationService.zoneForOffset(
        const Duration(hours: 5, minutes: 30),
      );
      expect(z.currentTimeZone.offset, const Duration(hours: 5, minutes: 30));
      expect(
        NotificationService.zoneForOffset(const Duration(minutes: 7)).name,
        'Asia/Jakarta',
      );
    },
  );
}
