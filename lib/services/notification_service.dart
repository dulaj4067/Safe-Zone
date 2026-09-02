import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alert.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String criticalChannelId = 'sz_critical_alerts';
  static const String criticalChannelName = 'Critical Life-Safety Alerts';
  static const String criticalChannelDescription =
      'Life-threatening emergency alerts that bypass Do Not Disturb and silent mode.';

  static const String generalChannelId = 'sz_general_alerts';
  static const String generalChannelName = 'General Disaster Alerts';
  static const String generalChannelDescription =
      'Standard advisory and informational disaster warnings.';

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      await _setupAndroidChannels();
      await requestPermissions();
    } else if (Platform.isIOS) {
      await requestPermissions();
    }

    _isInitialized = true;
  }

  Future<void> _setupAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return;

    // Critical Channel with DND bypass and alarm audio attributes
    final criticalVibration = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
    final criticalChannel = AndroidNotificationChannel(
      criticalChannelId,
      criticalChannelName,
      description: criticalChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: criticalVibration,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      bypassDnd: true,
    );

    // General Channel
    const generalChannel = AndroidNotificationChannel(
      generalChannelId,
      generalChannelName,
      description: generalChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await android.createNotificationChannel(criticalChannel);
    await android.createNotificationChannel(generalChannel);
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
        return granted ?? false;
      }
    }
    return false;
  }

  /// Request access to bypass Do Not Disturb on Android (opens system settings if needed)
  Future<void> requestNotificationPolicyAccess() async {
    if (!Platform.isAndroid) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await (android as dynamic).requestNotificationPolicyAccess();
      }
    } catch (e) {
      debugPrint('Could not request notification policy access: $e');
    }
  }

  Future<void> showCriticalAlert(DisasterAlert alert) async {
    final criticalVibration = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);

    final androidDetails = AndroidNotificationDetails(
      criticalChannelId,
      criticalChannelName,
      channelDescription: criticalChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: criticalVibration,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'EMERGENCY: ${alert.title}',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: alert.id.hashCode,
      title: '🚨 CRITICAL ALERT: ${alert.title}',
      body: alert.instructions ?? 'Immediate safety action required. Tap for details.',
      notificationDetails: details,
      payload: alert.id,
    );
  }

  Future<void> showNormalAlert(DisasterAlert alert) async {
    const androidDetails = AndroidNotificationDetails(
      generalChannelId,
      generalChannelName,
      channelDescription: generalChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: alert.id.hashCode,
      title: '⚠️ ${alert.severity.label.toUpperCase()}: ${alert.title}',
      body: alert.instructions ?? 'Disaster advisory issued for your area.',
      notificationDetails: details,
      payload: alert.id,
    );
  }

  Future<void> cancelAlert(String alertId) async {
    await _plugin.cancel(id: alertId.hashCode);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
