import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/NotificationService.dart';
import 'Screen/Notifications/NotificationScreenStationOwner.dart';

// Screens
import 'Screen/Auth/Ev_Station_Owner_login.dart';
import 'Screen/Splash/SPlashScreen1.dart';
import 'Screen/Stations/My_station.dart';
import 'Screen/Stations/station_detail_form_screen.dart';
import 'Screen/Stations/station_detail_screen.dart';
import 'Screen/Booking/editstationscreen.dart';
import 'Screen/Booking/BookingDetail.dart';
import 'Screen/Dashboard/Ev_station_owner_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔔 Background FCM handler (must be a top-level function!)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Always init Firebase here in background isolate
  await Firebase.initializeApp();

  print("📩 Background message received: ${message.messageId}");
  await StationOwnerNotificationService.showBackground(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env
  await dotenv.load(fileName: ".env");

  // Init Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  // 🔹 Register background handler BEFORE using FirebaseMessaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔹 Init local + foreground/resumed handling
  await StationOwnerNotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EV Station Owner App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SplashScreen(),
      routes: {
        '/login': (context) => const Ev_Station_Owner_login(),
        '/myStations': (_) => const MyStationsScreen(),
        '/addStation': (context) => const StationDetailFormScreen(),
        '/stationDetail': (context) => const StationDetailScreen(),
        '/stationBookings': (_) => const BookingSummaryScreen(),
        '/stationNotifications': (_) =>
        const StationOwnerNotificationScreen(),
        '/editStation': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return EditStationScreen(stationId: args['stationId']);
        },
      },
    );
  }
}
