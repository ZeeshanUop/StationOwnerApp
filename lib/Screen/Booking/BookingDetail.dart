import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'bookingSlipscreen.dart';
class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  String _selectedTimeFilter = 'Today';
  String _selectedStatusFilter = 'Accepted';
  List<Map<String, dynamic>> _bookings = [];
  double _totalProfit = 0.0;
  bool _loading = true;
  List<BarChartGroupData> _barGroups = [];

  final List<String> _timeFilters = ['Today', 'Last 7 Days', 'This Month'];
  final List<String> _statusFilters = ['Accepted', 'Pending', 'Rejected'];

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    setState(() {
      _loading = true;
      _bookings.clear();
      _totalProfit = 0;
      _barGroups.clear();
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final now = DateTime.now().toUtc();
    DateTime startDate;

    switch (_selectedTimeFilter) {
      case 'Today':
        startDate = DateTime.utc(now.year, now.month, now.day);
        break;
      case 'Last 7 Days':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'This Month':
        startDate = DateTime.utc(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime.utc(now.year, now.month, now.day);
    }

    try {
      final stationsSnapshot = await FirebaseFirestore.instance
          .collection('ev_stations')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final stationIds = stationsSnapshot.docs.map((doc) => doc.id).toList();
      Map<String, double> dailyProfitMap = {};

      for (String stationId in stationIds) {
        final bookingSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('stationId', isEqualTo: stationId)
            .where('status', isEqualTo: _selectedStatusFilter.toLowerCase())
            .get();

        final filteredDocs = bookingSnapshot.docs.where((doc) {
          final bookingTime =
          (doc['bookingTime'] as Timestamp).toDate().toUtc();
          return bookingTime.isAtSameMomentAs(startDate) ||
              bookingTime.isAfter(startDate);
        }).toList();

        for (var doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          _bookings.add(data);

          final amount = (data['amount'] as num).toDouble();
          _totalProfit += amount;

          final dateKey = (data['bookingTime'] as Timestamp).toDate();
          final key = '${dateKey.year}-${dateKey.month}-${dateKey.day}';
          dailyProfitMap[key] = (dailyProfitMap[key] ?? 0) + amount;
        }
      }

      int index = 0;
      for (var entry in dailyProfitMap.entries) {
        _barGroups.add(BarChartGroupData(
          x: index++,
          barRods: [
            BarChartRodData(toY: entry.value, color: Colors.teal, width: 16)
          ],
        ));
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Booking Summary', style: pw.TextStyle(fontSize: 22)),
            pw.SizedBox(height: 10),
            for (var booking in _bookings)
              pw.Text(
                'User: ${booking['userName']} (${booking['userPhone']}) | Station: ${booking['stationName']} | Vehicle: ${booking['vehicleModel']} | Amount: PKR ${booking['amount']} | Status: ${booking['status']}',
              ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          elevation: 4,
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: SafeArea(
              child: Center(
                child: Text(
                  'Booking Summary',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export to PDF',
              onPressed: _bookings.isEmpty ? null : _exportToPdf,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTimeFilter,
                    items: _timeFilters.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Row(
                          children: [
                            Icon(Icons.filter_list, color: Colors.teal.shade700),
                            const SizedBox(width: 8),
                            Text(f),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedTimeFilter = val!);
                      fetchBookings();
                    },
                    decoration: InputDecoration(
                      labelText: 'Time Filter',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatusFilter,
                    items: _statusFilters.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(Icons.label, color: Colors.teal.shade700),
                            const SizedBox(width: 8),
                            Text(s),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedStatusFilter = val!);
                      fetchBookings();
                    },
                    decoration: InputDecoration(
                      labelText: 'Status Filter',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Total Profit
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Profit",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _totalProfit),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, _) {
                      return Text(
                        "PKR ${value.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 16, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Profit Chart
          if (_barGroups.isNotEmpty)
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: BarChart(
                  BarChartData(
                    barGroups: _barGroups,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${value.toInt() + 1}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Booking List
          Expanded(
            child: _bookings.isEmpty
                ? const Center(child: Text("No bookings found for selected filters."))
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                final time = (booking['bookingTime'] as Timestamp).toDate();
                final status = booking['status'] ?? '';
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text('${booking['stationName']} - ${booking['vehicleModel']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User: ${booking['userName']} (${booking['userPhone']})'),
                        Text('${time.toLocal()}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('PKR ${booking['amount']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingSlipScreen(bookingId: booking['bookingId']),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
