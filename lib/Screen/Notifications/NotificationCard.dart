import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project_2/Screen/Notifications/NotificationScreenStationOwner.dart';

class StationOwnerNotificationCard extends StatelessWidget {
  const StationOwnerNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final stationOwnerId = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                left: 0,
                child: Icon(Icons.notifications, size: 30, color: Colors.teal),
              ),
              if (stationOwnerId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('to', isEqualTo: stationOwnerId)
                      .where('status', isEqualTo: 'unread')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final count = snapshot.data!.docs.length;
                    return Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        title: const Text("Booking Notifications"),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StationOwnerNotificationScreen(),
            ),
          );
        },
      ),
    );
  }
}