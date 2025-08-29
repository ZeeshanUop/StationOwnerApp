import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyStationsScreen extends StatefulWidget {
  const MyStationsScreen({super.key});

  @override
  State<MyStationsScreen> createState() => _MyStationsScreenState();
}

class _MyStationsScreenState extends State<MyStationsScreen> {
  String? ownerId;
  String selectedStatus = 'All';
  String selectedCity = 'All';
  final List<String> statuses = ['All', 'Open', 'Closed', 'Under Maintenance'];
  final List<String> cities = [
    'All',
    'Islamabad',
    'Lahore',
    'Karachi',
    'Peshawar',
    'Rawalpindi',
    'Swat',
    'Quetta',
    'Multan'
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ownerId = user.uid;
      setState(() {});
    }
  }

  Future<void> _refreshStations() async {
    setState(() {}); // Refresh the StreamBuilder
  }

  void _confirmDeleteStation(String stationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Station"),
        content: const Text("Are you sure you want to delete this station?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('ev_stations').doc(stationId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'closed':
        return Colors.red;
      case 'under maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ownerId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 4,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Back button with spacing
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    const Text(
                      "My Stations",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5),
                    ),

                  ],
                ),
              ),
            ),
          ),
        )
        ,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStations,
        child: Column(
          children: [
            // Filter Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedCity,
                      isExpanded: true,
                      items: cities
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedCity = val!),
                      decoration: InputDecoration(
                        labelText: 'City',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      items: statuses
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedStatus = val!),
                      decoration: InputDecoration(
                        labelText: 'Status',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Station Cards
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ev_stations')
                    .where('ownerId', isEqualTo: ownerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error loading stations"));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final filteredStations = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cityMatch = selectedCity == 'All' || data['city'] == selectedCity;
                    final statusMatch = selectedStatus == 'All' || data['status'] == selectedStatus;
                    return cityMatch && statusMatch;
                  }).toList();

                  if (filteredStations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ev_station, size: 100, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text("No stations found",
                              style: TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 6),
                          const Text("Add new stations or adjust filters",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: filteredStations.length,
                    itemBuilder: (context, index) {
                      final doc = filteredStations[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final String name = data['name'] ?? "Unnamed Station";
                      final String city = data['city'] ?? 'N/A';
                      final List connectors = data['connectors'] ?? [];
                      int totalSlots = 0;
                      int availableSlots = 0;

                      for (var connector in connectors) {
                        totalSlots += ((connector['totalSlots'] ?? 0) as num).toInt();
                        availableSlots += ((connector['availableSlots'] ?? 0) as num).toInt();
                      }

                      final String status = data['status'] ?? 'Unknown';
                      final String? imageUrl = data['imageUrl'];

                      return Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/stationDetail',
                              arguments: {
                                'stationId': doc.id,
                                'name': name,
                                'imagePath': imageUrl,
                                'rating': (data['rating'] ?? 0).toDouble(),
                                'location': data['location'],
                                'connectors': data['connectors'],
                                'openingHours': data['openingHours'],
                                'pricing': '',
                                'amenities': List<String>.from(data['amenities'] ?? []),
                                'latitude': data['latitude'],
                                'longitude': data['longitude'],
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                Hero(
                                  tag: doc.id,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: imageUrl != null
                                        ? Image.network(imageUrl,
                                        width: 80, height: 80, fit: BoxFit.cover)
                                        : Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.ev_station,
                                          size: 36, color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontSize: 17, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.location_city,
                                              size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(city,
                                              style:
                                              TextStyle(color: Colors.grey.shade700)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.ev_station,
                                              size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                              "Slots: $totalSlots • Available: $availableSlots",
                                              style: TextStyle(
                                                  color: Colors.grey.shade700)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit & Delete
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 22, color: Colors.blue),
                                      tooltip: 'Edit Station',
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/editStation',
                                          arguments: {'stationId': doc.id},
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 22, color: Colors.red),
                                      tooltip: 'Delete Station',
                                      onPressed: () => _confirmDeleteStation(doc.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
