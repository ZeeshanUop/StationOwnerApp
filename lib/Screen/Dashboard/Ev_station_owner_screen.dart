import 'dart:async';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Splash/Splash Screen.dart';

class StationOwnerDashboardMain extends StatefulWidget {
  const StationOwnerDashboardMain({super.key});

  @override
  State<StationOwnerDashboardMain> createState() =>
      _StationOwnerDashboardMainState();
}

class _StationOwnerDashboardMainState
    extends State<StationOwnerDashboardMain>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _badgeController;
  late AnimationController _flashController;

  final String ownerId = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _previousUnread = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.3,
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 0.0,
      upperBound: 0.3,
    );


  }

  @override
  void dispose() {
    _animationController.dispose();
    _badgeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  // Stream: Count of stations for this owner
  Stream<int> _stationsCountStream() {
    return FirebaseFirestore.instance
        .collection('ev_stations')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // Stream: Today's booking summary
  Stream<Map<String, dynamic>> _bookingSummaryStream() {
    final controller = StreamController<Map<String, dynamic>>();

    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    FirebaseFirestore.instance
        .collection('ev_stations')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .listen((stationSnap) {
      final stationIds = stationSnap.docs.map((e) => e.id).toList();
      if (stationIds.isEmpty) {
        controller.add({'bookings': 0, 'revenue': 0.0});
        return;
      }

      FirebaseFirestore.instance
          .collection('bookings')
          .where(
        'stationId',
        whereIn: stationIds.length > 10 ? stationIds.sublist(0, 10) : stationIds,
      )
          .where('bookingTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('bookingTime', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((bookingSnap) {
        int totalBookings = bookingSnap.size;

        double totalRevenue = bookingSnap.docs.fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['amount'] ?? 0).toDouble());
        });

        controller.add({'bookings': totalBookings, 'revenue': totalRevenue});
      });
    });

    return controller.stream;
  }

  // Stream: unread notifications
  Stream<int> _unreadNotificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'unread')
        .where('type', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          elevation: 6,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              child: Center(
                child: Text(
                  'Station Owner Dashboard',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => SplashScreen1()),
                        (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats Panel
            StreamBuilder<int>(
              stream: _stationsCountStream(),
              builder: (context, stationSnapshot) {
                final stationsCount = stationSnapshot.data ?? 0;
                return StreamBuilder<Map<String, dynamic>>(
                  stream: _bookingSummaryStream(),
                  builder: (context, bookingSnapshot) {
                    final bookings = bookingSnapshot.data?['bookings'] ?? 0;
                    final revenue = bookingSnapshot.data?['revenue'] ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [Colors.green.shade200, Colors.green.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade300.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(4, 6),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('Stations', stationsCount.toString(),
                              Icons.ev_station, Colors.blue.shade600),
                          _statItem('Bookings', bookings.toString(),
                              Icons.book_online, Colors.deepPurple.shade600),
                          _statItem('Revenue',
                              'PKR ${revenue.toStringAsFixed(0)}',
                              Icons.attach_money,
                              Colors.amber.shade700),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            // Dashboard Cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _neumorphicDashboardCard(
                    icon: Icons.ev_station,
                    label: 'My Stations',
                    color: Colors.blue.shade600,
                    onTap: () => Navigator.pushNamed(context, '/myStations'),
                  ),
                  _neumorphicDashboardCard(
                    icon: Icons.add_location_alt,
                    label: 'Add Station',
                    color: Colors.green.shade600,
                    onTap: () => Navigator.pushNamed(context, '/addStation'),
                  ),
                  _neumorphicDashboardCard(
                    icon: Icons.book_online,
                    label: 'Bookings',
                    color: Colors.deepPurple.shade600,
                    onTap: () =>
                        Navigator.pushNamed(context, '/stationBookings'),
                  ),
                  // Notifications Card wrapped in StreamBuilder
                  StreamBuilder<int>(
                    stream: _unreadNotificationsStream(),
                    builder: (context, notifSnapshot) {
                      final unread = notifSnapshot.data ?? 0;

                      // Trigger flash animation when unread count increases
                      if (unread > _previousUnread) {
                        _flashController.forward(from: 0.0);
                      }
                      _previousUnread = unread;

                      return _neumorphicDashboardCard(
                        icon: Icons.notifications_active,
                        label: 'Notifications',
                        color: Colors.teal.shade600,
                        onTap: () =>
                            Navigator.pushNamed(context, '/stationNotifications'),
                        badgeCount: unread,
                        badgeColor: Colors.orange,
                      );
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54)),
      ],
    );
  }

  Widget _neumorphicDashboardCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
    Color badgeColor = Colors.red,
  }) {
    return badges.Badge(
      showBadge: badgeCount > 0,
      badgeContent: Text(
        badgeCount.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: badgeColor,
        padding: const EdgeInsets.all(6),
      ),
      position: badges.BadgePosition.topEnd(top: -8, end: -6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.85), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
