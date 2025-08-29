import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';

class StationDetailFormScreen extends StatefulWidget {
  const StationDetailFormScreen({super.key});

  @override
  State<StationDetailFormScreen> createState() => _StationDetailFormScreenState();
}

class _StationDetailFormScreenState extends State<StationDetailFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _selectedImage;

  String _selectedCity = 'Islamabad';
  final List<String> _cities = ['Islamabad', 'Lahore', 'Karachi', 'Peshawar','Rawalpindi','Swat','Quetta','Multan'];
  final List<String> _connectors = ['CCS', 'CCS2', 'Mennekes','type 2','Dc Fast Chargeroa'];
  final Set<String> _selectedConnectors = {};
  final Map<String, TextEditingController> _powerControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _totalSlotsControllers = {};

  final List<String> _amenities = [
    'Food',
    'Washroom',
    'Mosque',
    'Mechanic',
    'Car Service',
  ];
  final Set<String> _selectedAmenities = {};

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final extension = imageFile.path.split('.').last;
      final fileName = 'ev_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final ref = FirebaseStorage.instance.ref().child('ev_station').child(fileName);
      await ref.putFile(imageFile, SettableMetadata(contentType: mimeType));
      return await ref.getDownloadURL();
    } catch (e) {
      _showSnackBar('Image upload failed');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showSnackBar('Please select an image');
      return;
    }
    if (_selectedConnectors.isEmpty) {
      _showSnackBar('Select at least one connector');
      return;
    }

    for (var type in _selectedConnectors) {
      final power = _powerControllers[type]?.text.trim();
      final price = _priceControllers[type]?.text.trim();
      final points = _totalSlotsControllers[type]?.text.trim();
      if (power == null || power.isEmpty || price == null || price.isEmpty || points == null || points.isEmpty) {
        _showSnackBar('Please fill power, price, and available points for $type');
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in first');
      return;
    }

    final fullAddress = '${_addressController.text.trim()}, $_selectedCity';

    try {
      final locations = await locationFromAddress(fullAddress);
      if (locations.isEmpty) {
        _showSnackBar('Invalid address or city. Please check your input.');
        return;
      }

      final position = locations.first;
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final detectedCity = placemarks.first.locality?.toLowerCase().trim() ?? '';

      if (detectedCity != _selectedCity.toLowerCase().trim()) {
        _showSnackBar("Address doesn't match selected city. Detected: $detectedCity");
        return;
      }

      // Check for duplicate address
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ev_stations')
          .where('location', isEqualTo: _addressController.text.trim())
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        _showSnackBar('A station with this address already exists.');
        return;
      }

      final imageUrl = await _uploadImage(_selectedImage!);
      if (imageUrl == null) return;

      final stationData = _createStationData(
        user.uid,
        Position(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
        imageUrl,
      );

      await FirebaseFirestore.instance.collection('ev_stations').add(stationData);
      _showSnackBar('Station added successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Map<String, dynamic> _createStationData(String userId, Position position, String imageUrl) {
    int totalAvailablePoints = 0;

    final connectorData = _selectedConnectors.map((type) {
      final slots = int.tryParse(_totalSlotsControllers[type]?.text ?? '0') ?? 0;
      totalAvailablePoints += slots;
      return {
        'name': type,
        'power': _powerControllers[type]?.text ?? '',
        'price': _priceControllers[type]?.text ?? '',
        'totalSlots': slots,
      };
    }).toList();

    return {
      'name': _nameController.text.trim(),
      'location': _addressController.text.trim(),
      'city': _selectedCity,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'status': 'Open',
      'rating': 0.0,
      'ratingCount': 0,
      'openingHours': _hoursController.text.trim(),
      'ownerId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'connectors': connectorData,
      'amenities': _selectedAmenities.toList(),
      'imageUrl': imageUrl,
      'paymentPhone': _phoneController.text.trim(),
      'availablePoints': totalAvailablePoints,
    };
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    for (final c in _powerControllers.values) c.dispose();
    for (final c in _priceControllers.values) c.dispose();
    for (final c in _totalSlotsControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Beautiful AppBar
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 4,
        backgroundColor: Colors.transparent,
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
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Add EV Station",
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
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                        backgroundColor: Colors.grey.shade200,
                        child: _selectedImage == null
                            ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                            : null,
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 18,
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _sectionTitle('Station Information'),
              _cardContainer(
                children: [
                  _buildTextField(_nameController, 'Station Name', Icons.ev_station),
                  const SizedBox(height: 12),
                  _buildTextField(_addressController, 'Address', Icons.location_on),
                  const SizedBox(height: 12),
                  _buildCityDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField(_phoneController, 'Phone Number for Payment', Icons.phone),
                  const SizedBox(height: 12),
                  _buildTextField(_hoursController, 'Opening Hours', Icons.access_time),
                ],
              ),

              const SizedBox(height: 20),
              _sectionTitle("Select Connectors"),
              _cardContainer(
                children: _buildConnectorFields(),
              ),

              const SizedBox(height: 20),
              _sectionTitle("Select Amenities"),
              _cardContainer(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _amenities.map((amenity) {
                      final selected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: selected,
                        selectedColor: Colors.green.shade200,
                        checkmarkColor: Colors.green.shade800,
                        onSelected: (val) {
                          setState(() {
                            val ? _selectedAmenities.add(amenity) : _selectedAmenities.remove(amenity);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitForm,
                  icon: const Icon(Icons.check,color: Colors.white,),
                  label: const Text("Submit Station", style: TextStyle(fontSize: 16,color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _cardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
  );

  Widget _buildCityDropdown() => DropdownButtonFormField<String>(
    value: _selectedCity,
    items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
    onChanged: (val) => setState(() => _selectedCity = val!),
    decoration: InputDecoration(
      labelText: "City",
      prefixIcon: const Icon(Icons.location_city),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
  );

  List<Widget> _buildConnectorFields() {
    return _connectors.map((type) {
      final selected = _selectedConnectors.contains(type);
      if (selected) {
        _powerControllers[type] ??= TextEditingController();
        _priceControllers[type] ??= TextEditingController();
        _totalSlotsControllers[type] ??= TextEditingController();
        _powerControllers[type]!.addListener(() => setState(() {}));
        _priceControllers[type]!.addListener(() => setState(() {}));
        _totalSlotsControllers[type]!.addListener(() => setState(() {}));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: selected,
            title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
            onChanged: (value) => setState(() {
              value == true ? _selectedConnectors.add(type) : _selectedConnectors.remove(type);
            }),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: [
                  _buildValidatedField(_powerControllers[type]!, "$type Power (kW)", Icons.flash_on),
                  const SizedBox(height: 8),
                  _buildValidatedField(_priceControllers[type]!, "$type Price (PKR)", Icons.currency_rupee),
                  const SizedBox(height: 8),
                  _buildValidatedField(_totalSlotsControllers[type]!, "$type Available Points", Icons.electric_car, isInt: true),
                ],
              ),
            ),
        ],
      );
    }).toList();
  }

  Widget _buildValidatedField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isInt = false,
      }) {
    bool isValid = controller.text.trim().isNotEmpty &&
        (!isInt || int.tryParse(controller.text.trim()) != null);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: isValid
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.error, color: Colors.red),
      ),
      keyboardType: isInt ? TextInputType.number : TextInputType.text,
      validator: (v) => (v == null || v.isEmpty)
          ? 'Required'
          : isInt && int.tryParse(v) == null
          ? 'Enter a valid number'
          : null,
    );
  }
}
