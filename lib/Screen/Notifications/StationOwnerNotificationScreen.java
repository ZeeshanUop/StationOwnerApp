import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../BookingSlipScreen.dart';

class StationOwnerNotificationScreen extends StatefulWidget {
  const StationOwnerNotificationScreen({super.key});

  @override
  State<StationOwnerNotificationScreen> createState() =>
      _StationOwnerNotificationScreenState();
}

class _StationOwnerNotificationScreenState
    extends State<StationOwnerNotificationScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final Set<String> _updatingBookings = {};

  Future<void> deleteNotification(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  Future<void> updateBookingStatus(String bookingId, String status, String notificationId) async {
    if (_updatingBookings.contains(bookingId)) return;

    setState(() => _updatingBookings.add(bookingId));

    try {
      // Update booking status
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': status});

      // Update notification type
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'type': status, 'status': 'unread'}); // mark unread for visibility

      // Send notification to EV owner
      final bookingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      final evOwnerId = bookingSnap.data()?['userId'];
      if (evOwnerId != null) {
        await FirebaseFirestore.instance.collection('notifications_to_send').add({
          'bookingId': bookingId,
          'to': evOwnerId,
          'message': status == 'accepted'
              ? "Your booking request has been accepted"
              : "Your booking request has been rejected",
          'status': 'unread',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Booking $status successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _updatingBookings.remove(bookingId));
    }
  }

  Color _getStatusColor(String type) {
    switch (type.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_bottom;
    }
  }

  String _getDisplayMessage(String type) {
    switch (type.toLowerCase()) {
      case 'accepted':
        return "Customer booking has been accepted";
      case 'rejected':
        return "Customer booking has been rejected";
      case 'pending':
      default:
        return "Customer booking is pending approval";
    }
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text(
                'Notifications',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('to', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    "No notifications",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "You’ll see updates about your bookings here",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final bookingId = data['bookingId'] as String?;
              final type = data['type'] ?? 'pending';
              final timestamp = data['timestamp'] as Timestamp?;
              final status = data['status'] ?? 'unread';

              final bool isUnread = status == 'unread';
              final displayMessage = _getDisplayMessage(type);
              final statusColor = _getStatusColor(type);
              final statusIcon = _getStatusIcon(type);

              final messageStyle = TextStyle(
                fontSize: 16,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                color: isUnread ? Colors.black87 : Colors.grey.shade700,
              );

              final timeStyle = TextStyle(
                fontSize: 13,
                color: isUnread ? Colors.teal.shade700 : Colors.grey.shade500,
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
              );

              return GestureDetector(
                onTap: () {
                  if (bookingId != null) {
                    doc.reference.update({'status': 'read'});
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingSlipScreen(bookingId: bookingId),
                      ),
                    );
                  }
                },
                child: Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) => deleteNotification(doc.id),
                  child: Card(
                    elevation: isUnread ? 6 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: isUnread
                              ? [Colors.teal.shade50, Colors.white]
                              : [Colors.white, Colors.grey.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 100,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(statusIcon, color: statusColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayMessage,
                                    style: messageStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTimeAgo(timestamp),
                                    style: timeStyle,
                                  ),
                                  const SizedBox(height: 10),
                                  if (bookingId != null && type.toLowerCase() == 'pending')
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _updatingBookings.contains(bookingId)
                                              ? null
                                              : () => updateBookingStatus(
                                              bookingId, 'accepted', doc.id),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text("Accept"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade600,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                            textStyle: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: _updatingBookings.contains(bookingId)
                                              ? null
                                              : () => updateBookingStatus(
                                              bookingId, 'rejected', doc.id),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text("Reject"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade600,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                            textStyle: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
