import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class StationOwnerNotificationService {
  static final navKey = GlobalKey<NavigatorState>();
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  /// Initialize FCM + local notifications
  static Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Save token to Firestore
    await _saveToken();
    _fcm.onTokenRefresh.listen((t) => _saveToken(t));

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'ch', // must match id in AndroidNotificationDetails
      'Channel',
      description: 'General notifications',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final data = resp.payload == null
            ? <String, dynamic>{}
            : jsonDecode(resp.payload!) as Map<String, dynamic>;
        handleClick(data);
      },
    );

    // Foreground
    FirebaseMessaging.onMessage.listen((m) async {
      await _maybePersistToFirestore(m, toRole: 'station_owner');
      await _showLocal(m);
    });

    // Resumed (app opened via tap)
    FirebaseMessaging.onMessageOpenedApp.listen((m) async {
      await _maybePersistToFirestore(m, toRole: 'station_owner');
      handleClick(m.data);
    });

    // Cold start
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _maybePersistToFirestore(initial, toRole: 'station_owner');
      handleClick(initial.data);
    }
  }

  /// Save token for current user
  static Future<void> _saveToken([String? token]) async {
    token ??= await _fcm.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance
          .collection('ev_station_owners')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  /// Show local notification
  static Future<void> _showLocal(RemoteMessage m) async {
    final title = m.data['title'] ?? 'Notification';
    final body = m.data['message'] ?? '';

    const android = AndroidNotificationDetails(
      'ch',
      'Channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );

    await _local.show(
      m.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(m.data),
    );
  }

  /// Persist notification to Firestore (optional)
  static Future<void> _maybePersistToFirestore(RemoteMessage m,
      {required String toRole}) async {
    if ((m.data['notifId'] ?? '').isNotEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('notifications_$toRole').add({
      'to': user.uid,
      'title': m.data['title'] ?? 'Notification',
      'message': m.data['message'] ?? '',
      'bookingId': m.data['bookingId'],
      'stationId': m.data['stationId'],
      'type': m.data['bookingStatus'] != null ? 'update' : 'new',
      'status': 'unread',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Handle notification click
  static void handleClick(Map<String, dynamic> data) {
    navKey.currentState?.popUntil((r) => r.isFirst);
    navKey.currentState?.pushNamed('/notifications', arguments: {
      'bookingId': data['bookingId'],
      'notifId': data['notifId'],
      'status': data['status'],
    });
  }

  /// Background isolate handler (⚠️ no re-init here!)
  static Future<void> showBackground(RemoteMessage message) async {
    await _showLocal(message);
  }
}
