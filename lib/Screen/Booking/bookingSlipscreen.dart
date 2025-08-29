import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BookingSlipScreen extends StatefulWidget {
  final String bookingId;
  const BookingSlipScreen({super.key, required this.bookingId});

  @override
  State<BookingSlipScreen> createState() => _BookingSlipScreenState();
}

class _BookingSlipScreenState extends State<BookingSlipScreen> {
  Map<String, dynamic>? bookingData;
  bool isLoading = true;
  bool updatingStatus = false;

  @override
  void initState() {
    super.initState();
    fetchBookingDetails();
  }

  Future<void> fetchBookingDetails() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();
      if (snapshot.exists) {
        setState(() {
          bookingData = snapshot.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dt);
  }

  Widget infoCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Text(
              "$title: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Update booking status + notifications + availablePoints
  Future<void> updateBookingStatus(String status) async {
    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);

      // Update booking status
      await bookingRef.update({'status': status});

      // 🔑 Only reduce slot if booking is accepted
      if (status == "accepted") {
        final stationRef = FirebaseFirestore.instance
            .collection('ev_stations')
            .doc(bookingData!['stationId']);

        await stationRef.update({
          'availablePoints': FieldValue.increment(-1),
        });
      }

      // Send notification to user
      await FirebaseFirestore.instance.collection('notifications_to_send').add({
        'to': bookingData!['userId'],
        'title': "Booking $status",
        'message':
        "Your booking at ${bookingData!['stationName']} has been $status.",
        'bookingId': widget.bookingId,
        'stationId': bookingData!['stationId'],
        'bookingStatus': status,
        'status': "unread",
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking $status successfully")),
      );
    } catch (e) {
      print("Error updating booking status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update booking status")),
      );
    }
  }

  Widget statusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'accepted':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'rejected':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'pending':
      default:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.teal.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        title: const Text(
          "Booking Slip",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookingData == null
          ? const Center(child: Text("No booking details available"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: bookingData!['stationImageUrl'] ?? '',
                placeholder: (_, __) =>
                    Container(height: 180, color: Colors.grey.shade200),
                errorWidget: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 80),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            infoCard("Customer", bookingData!['userName'] ?? 'N/A'),
            infoCard("Phone", bookingData!['userPhone'] ?? 'N/A'),

            infoCard("Vehicle Type", bookingData!['vehicleType'] ?? 'N/A'),
            infoCard("Vehicle Model", bookingData!['vehicleModel'] ?? 'N/A'),
            infoCard("Connection", bookingData!['connectionType'] ?? 'N/A'),
            infoCard("Booking Time",
                formatDateTime(bookingData!['bookingTime'] as Timestamp?)),
            infoCard(
                "Charge %", "${bookingData!['chargePercentage'] ?? 0}%"),
            infoCard("Amount", "PKR ${bookingData!['amount'] ?? 0}"),

            const SizedBox(height: 16),

            if (bookingData!['paymentScreenshotUrl'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Payment Screenshot:",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl:
                      bookingData!['paymentScreenshotUrl'] ?? '',
                      placeholder: (_, __) => Container(
                          height: 180, color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 80),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 30),

            Center(child: statusBadge(bookingData!['status'] ?? 'pending')),

            const SizedBox(height: 16),

            if ((bookingData!['status'] ?? 'pending') == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: updatingStatus
                        ? null
                        : () => updateBookingStatus("accepted"),
                    icon: const Icon(Icons.check),
                    label: const Text("Accept"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: updatingStatus
                        ? null
                        : () => updateBookingStatus("rejected"),
                    icon: const Icon(Icons.close),
                    label: const Text("Reject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
