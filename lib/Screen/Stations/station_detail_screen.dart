import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class StationDetailScreen extends StatefulWidget {
  const StationDetailScreen({super.key});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  late String stationId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    stationId = args['stationId'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Station Details"),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('ev_stations').doc(stationId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final String name = data['name'] ?? '';
          final String? imagePath = data['imageUrl'];
          final double rating = (data['rating'] ?? 0.0).toDouble();
          final String location = data['location'] ?? '';
          final String openingHours = data['openingHours'] ?? 'N/A';
          final double latitude = data['latitude'];
          final double longitude = data['longitude'];
          final List<dynamic> connectors = data['connectors'] ?? [];
          final List<dynamic> amenities = data['amenities'] ?? [];

          final int totalSlots = connectors.fold(0, (sum, c) => sum + ((c['totalSlots'] ?? 0) as int));
          final int availableSlots = connectors.fold(0, (sum, c) => sum + ((c['availableSlots'] ?? 0) as int));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: stationId,
                  child: imagePath != null
                      ? Image.network(imagePath, width: double.infinity, height: 220, fit: BoxFit.cover)
                      : Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 80),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 12),
                          const Icon(Icons.ev_station, size: 20),
                          const SizedBox(width: 4),
                          Text('$totalSlots Slots', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text('($availableSlots available)', style: const TextStyle(fontSize: 14, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined),
                          const SizedBox(width: 4),
                          Expanded(child: Text(location, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.access_time),
                          const SizedBox(width: 4),
                          Text("Opening Hours: $openingHours"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const Text("Connectors", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...connectors.map((conn) {
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.power, color: Colors.blue),
                            title: Text('${conn['name']}'),
                            subtitle: Text(
                              'Power: ${conn['power']} kW\nPrice: Rs. ${conn['price']}\n'
                                  'Slots: ${conn['totalSlots']} — Available: ${conn['availableSlots']}',
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                      const Divider(),
                      const Text("Amenities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: amenities.map<Widget>((item) {
                          return Chip(
                            label: Text(item),
                            backgroundColor: Colors.green.shade100,
                            avatar: const Icon(Icons.check, size: 16, color: Colors.green),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const Text("Map Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(latitude, longitude),
                              zoom: 14,
                            ),
                            markers: {
                              Marker(
                                markerId: MarkerId(stationId),
                                position: LatLng(latitude, longitude),
                                infoWindow: InfoWindow(title: name),
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

