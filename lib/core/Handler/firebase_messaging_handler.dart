import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Handling a background message: ${message.messageId}");

  final notification = message.notification;
  if (notification != null) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const android = AndroidNotificationDetails(
      "station_channel",
      "Station Notifications",
      channelDescription: "Notifications for Station Owner app",
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}

/// Must be called in `main.dart`
void setupFirebaseMessaging() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}
