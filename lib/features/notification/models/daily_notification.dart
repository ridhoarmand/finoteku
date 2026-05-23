import 'package:flutter/material.dart';
import 'package:finoteku/core/utils/uuid_util.dart';

class DailyNotification {
  final String id;
  final String title;
  final String body; // Konsisten dengan screen yang menggunakan 'body'
  final TimeOfDay time;
  final bool isEnabled; // Konsisten dengan screen yang menggunakan 'isEnabled'
  final DateTime createdAt;

  const DailyNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isEnabled = true,
    required this.createdAt,
  });

  // Factory untuk membuat notifikasi default
  factory DailyNotification.defaultReminder() {
    return DailyNotification(
      id: generateUuidV4(),
      title: 'Pengingat Harian',
      body: 'Jangan lupa catat pengeluaran kamu ya! 💰',
      time: const TimeOfDay(hour: 19, minute: 0),
      isEnabled: true,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'hour': time.hour,
        'minute': time.minute,
        'isEnabled': isEnabled,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory DailyNotification.fromJson(Map<String, dynamic> json) =>
      DailyNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        time: TimeOfDay(
          hour: json['hour'] as int,
          minute: json['minute'] as int,
        ),
        isEnabled: json['isEnabled'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  DailyNotification copyWith({
    String? id,
    String? title,
    String? body,
    TimeOfDay? time,
    bool? isEnabled,
    DateTime? createdAt,
  }) =>
      DailyNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        time: time ?? this.time,
        isEnabled: isEnabled ?? this.isEnabled,
        createdAt: createdAt ?? this.createdAt,
      );

  // Generate unique notification ID for scheduling
  int get notificationId => id.hashCode.abs() % 2147483647;
}
