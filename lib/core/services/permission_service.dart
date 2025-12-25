import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request Notification Permissions
  /// Handles Android 13+ POST_NOTIFICATIONS and Schedule Exact Alarm
  Future<Map<Permission, PermissionStatus>>
  requestNotificationPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      // 1. Basic Notification Permission
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+: Force request to trigger dialog if needed
        final status = await Permission.notification.request();
        statuses[Permission.notification] = status;
        debugPrint('🔔 Notification Permission Status after request: $status');
      } else {
        // Android 12-: Notification permission is implied/granted by default
        statuses[Permission.notification] = PermissionStatus.granted;
        debugPrint('🔔 Notification Permission Implied (Android < 13)');
      }

      // 2. Exact Alarm Permission (Android 12+)
      // Note: exact_alarm is a sensitive permission.
      // permission_handler might return PermissionStatus.granted automatically on some devices
      // or require user to go to settings manually.
      // We check if it's restricted first.
      if (await Permission.scheduleExactAlarm.isDenied) {
        final status = await Permission.scheduleExactAlarm.request();
        statuses[Permission.scheduleExactAlarm] = status;
      }

      // Also check critical alerts if relevant (usually iOS)
    }

    return statuses;
  }

  /// Request Storage Permissions
  /// Handles the difference between Android 12- and Android 13+ (Photos/Videos/Audio)
  Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+: Request specific media permissions
        final photos = await Permission.photos.request();
        // If you need videos/audio too:
        // final videos = await Permission.videos.request();
        // final audio = await Permission.audio.request();

        return photos.isGranted; // || videos.isGranted ...
      } else {
        // Android 12 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS usually handles this via Photo Gallery access
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Request all fundamental permissions (Notification + Storage)
  Future<Map<Permission, PermissionStatus>>
  requestAllFundamentalPermissions() async {
    Map<Permission, PermissionStatus> results = {};

    // 1. Notifications
    results.addAll(await requestNotificationPermissions());

    // 2. Storage
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final photos = await Permission.photos.request();
        results[Permission.photos] = photos;
      } else {
        final storage = await Permission.storage.request();
        results[Permission.storage] = storage;
      }
    }

    return results;
  }

  /// Request Camera Permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Open App Settings
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
