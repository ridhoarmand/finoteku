import 'package:flutter/material.dart';

class NotificationSettings {
  final bool morningEnabled;
  final TimeOfDay morningTime;
  final String morningMessage;
  final bool eveningEnabled;
  final TimeOfDay eveningTime;
  final String eveningMessage;

  const NotificationSettings({
    this.morningEnabled = true,
    this.morningTime = const TimeOfDay(hour: 12, minute: 0),
    this.morningMessage = 'Jangan lupa catat pengeluaran kamu ya! 💰',
    this.eveningEnabled = true,
    this.eveningTime = const TimeOfDay(hour: 19, minute: 0),
    this.eveningMessage = 'Sudah catat transaksi hari ini? 📝',
  });

  Map<String, dynamic> toJson() => {
        'morningEnabled': morningEnabled,
        'morningHour': morningTime.hour,
        'morningMinute': morningTime.minute,
        'morningMessage': morningMessage,
        'eveningEnabled': eveningEnabled,
        'eveningHour': eveningTime.hour,
        'eveningMinute': eveningTime.minute,
        'eveningMessage': eveningMessage,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        morningEnabled: json['morningEnabled'] ?? true,
        morningTime: TimeOfDay(
          hour: json['morningHour'] ?? 12,
          minute: json['morningMinute'] ?? 0,
        ),
        morningMessage: json['morningMessage'] ??
            'Jangan lupa catat pengeluaran kamu ya! 💰',
        eveningEnabled: json['eveningEnabled'] ?? true,
        eveningTime: TimeOfDay(
          hour: json['eveningHour'] ?? 19,
          minute: json['eveningMinute'] ?? 0,
        ),
        eveningMessage:
            json['eveningMessage'] ?? 'Sudah catat transaksi hari ini? 📝',
      );

  NotificationSettings copyWith({
    bool? morningEnabled,
    TimeOfDay? morningTime,
    String? morningMessage,
    bool? eveningEnabled,
    TimeOfDay? eveningTime,
    String? eveningMessage,
  }) =>
      NotificationSettings(
        morningEnabled: morningEnabled ?? this.morningEnabled,
        morningTime: morningTime ?? this.morningTime,
        morningMessage: morningMessage ?? this.morningMessage,
        eveningEnabled: eveningEnabled ?? this.eveningEnabled,
        eveningTime: eveningTime ?? this.eveningTime,
        eveningMessage: eveningMessage ?? this.eveningMessage,
      );
}
