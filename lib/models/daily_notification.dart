import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class DailyNotification {
  final String id;
  final String title;
  final String message;
  final TimeOfDay time;
  final bool enabled;
  final DateTime createdAt;

  const DailyNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.enabled = true,
    required this.createdAt,
  });

  // Factory untuk membuat notifikasi default
  factory DailyNotification.defaultReminder() {
    return DailyNotification(
      id: const Uuid().v4(),
      title: 'Pengingat Harian',
      message: 'Jangan lupa catat pengeluaran kamu ya! 💰',
      time: const TimeOfDay(hour: 19, minute: 0),
      enabled: true,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'hour': time.hour,
        'minute': time.minute,
        'enabled': enabled,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory DailyNotification.fromJson(Map<String, dynamic> json) =>
      DailyNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        time: TimeOfDay(
          hour: json['hour'] as int,
          minute: json['minute'] as int,
        ),
        enabled: json['enabled'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  DailyNotification copyWith({
    String? id,
    String? title,
    String? message,
    TimeOfDay? time,
    bool? enabled,
    DateTime? createdAt,
  }) =>
      DailyNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        time: time ?? this.time,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
      );

  // Generate unique notification ID for scheduling
  int get notificationId => id.hashCode.abs() % 2147483647;
}
