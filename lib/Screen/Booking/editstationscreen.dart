import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

class EditStationScreen extends StatefulWidget {
  final String stationId;
  const EditStationScreen({super.key, required this.stationId});

  @override
  State<EditStationScreen> createState() => _EditStationScreenState();
}

class _EditStationScreenState extends State<EditStationScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();

  String? imageUrl;
  File? newImageFile;
  String status = 'Open';
  List<Map<String, dynamic>> connectors = [];
  List<String> amenities = [];

  final availableStatuses = ['Open', 'Closed', 'Under Maintenance'];
  final availableConnectors = ['CCS', 'CHAdeMO', 'Type2', 'Tesla'];
  final availableAmenities = ['Washroom', 'Mosque', 'Mechanic', 'Car Service', 'Food'];

  @override
  void initState() {
    super.initState();
    fetchStationData();
  }

  @override
  void dispose() {
    nameController.dispose();
    cityController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> fetchStationData() async {
    final doc = await FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .get();

    final data = doc.data();
    if (data != null) {
      nameController.text = data['name'];
      cityController.text = data['city'];
      addressController.text = data['location'] ?? '';
      imageUrl = data['imageUrl'];
      status = data['status'] ?? 'Open';
      connectors = List<Map<String, dynamic>>.from(data['connectors'] ?? []);
      amenities = List<String>.from(data['amenities'] ?? []);
      setState(() {});
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => newImageFile = File(pickedFile.path));
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('station_images')
        .child('${widget.stationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<void> updateStation() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? updatedImageUrl = imageUrl;
      if (newImageFile != null) {
        updatedImageUrl = await uploadImage(newImageFile!);
      }

      for (final connector in connectors) {
        if (!connector['power'].toString().toLowerCase().contains("kw")) {
          connector['power'] = "${connector['power']} kW";
        }
        if (!connector['price'].toString().toLowerCase().contains("pkr")) {
          connector['price'] = "${connector['price']} PKR";
        }
      }

      // 🧭 Convert address to coordinates
      final geoPoint = await getCoordinatesFromAddress(addressController.text);
      if (geoPoint == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to detect coordinates from address")),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('ev_stations').doc(widget.stationId).update({
        'name': nameController.text,
        'city': cityController.text,
        'location': addressController.text,
        'latitude': geoPoint.latitude,
        'longitude': geoPoint.longitude,
        'status': status,
        'connectors': connectors,
        'amenities': amenities,
        'imageUrl': updatedImageUrl,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating station: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }


  InputDecoration buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: buildInputDecoration(label, icon),
        validator: isRequired ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      ),
    );
  }
  Future<GeoPoint?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return GeoPoint(loc.latitude, loc.longitude);
      }
    } catch (e) {
      print('Error converting address to coordinates: $e');
    }
    return null;
  }

  Widget buildConnectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: availableConnectors.map((type) {
        final index = connectors.indexWhere((c) => c['name'] == type);
        final isSelected = index != -1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              title: Text(type),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    connectors.add({
                      'name': type,
                      'power': '',
                      'price': '',
                      'totalSlots': 0,
                    });
                  } else {
                    connectors.removeWhere((c) => c['name'] == type);
                  }
                });
              },
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: connectors[index]['power'],
                      decoration: InputDecoration(
                        labelText: '$type Power (kW)',
                        prefixIcon: const Icon(Icons.flash_on),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => connectors[index]['power'] = val,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: connectors[index]['price'],
                      decoration: InputDecoration(
                        labelText: '$type Price (PKR)',
                        prefixIcon: const Icon(Icons.money),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => connectors[index]['price'] = val,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: connectors[index]['totalSlots']?.toString() ?? '',
                      decoration: InputDecoration(
                        labelText: '$type Total Slots',
                        prefixIcon: const Icon(Icons.ev_station),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => connectors[index]['totalSlots'] = int.tryParse(val) ?? 0,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              )
          ],
        );
      }).toList(),
    );
  }

  Widget buildChips(List<String> items, List<String> selectedItems) {
    return Wrap(
      spacing: 8,
      children: items.map((item) {
        final isSelected = selectedItems.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (_) => setState(() {
            if (isSelected) {
              selectedItems.remove(item);
            } else {
              selectedItems.add(item);
            }
          }),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        height: 50,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: updateStation,
          child: const Text('Update Station'),
        ),
      ),
      appBar: AppBar(
        title: const Text('Edit Station'),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: pickImage,
                child: Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: newImageFile != null
                        ? FileImage(newImageFile!)
                        : (imageUrl != null ? NetworkImage(imageUrl!) as ImageProvider : null),
                    child: imageUrl == null && newImageFile == null
                        ? const Icon(Icons.camera_alt, size: 40)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              buildTextField(nameController, 'Station Name', Icons.ev_station),
              buildTextField(cityController, 'City', Icons.location_city),
              buildTextField(addressController, 'Address', Icons.location_on),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                items: availableStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => status = val!),
                decoration: buildInputDecoration("Status", Icons.settings),
              ),
              const SizedBox(height: 16),
              const Text("Connector Types", style: TextStyle(fontWeight: FontWeight.bold)),
              buildConnectorSection(),
              const SizedBox(height: 16),
              const Text("Amenities", style: TextStyle(fontWeight: FontWeight.bold)),
              buildChips(availableAmenities, amenities),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
