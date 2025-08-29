import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔥 NEW

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---------------- AUTH ----------------
  Future<User?> registerUser(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<User?> loginUser(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<void> signOut() async => await _auth.signOut();

  User? getCurrentUser() => _auth.currentUser;

  Future<void> sendVerificationEmail(User user) async =>
      await user.sendEmailVerification();

  Future<void> sendPasswordReset(String email) async =>
      await _auth.sendPasswordResetEmail(email: email);

  // ---------------- STATION OWNER ----------------
  Future<void> saveStationOwner(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('ev_station_owners').doc(uid).set(data);
  }

  Future<DocumentSnapshot?> getStationOwner(String uid) async {
    final doc =
    await _firestore.collection('ev_station_owners').doc(uid).get();
    return doc.exists ? doc : null;
  }

  // 🔥 NEW: Save FCM token
  Future<void> saveFcmToken(String uid, {String? token}) async {
    String? fcmToken = token ?? await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _firestore.collection('ev_station_owners').doc(uid).update({
        "fcmToken": fcmToken,
        "lastLogin": FieldValue.serverTimestamp(),
      });
    }
  }

  // 🔥 NEW: Listen for token refresh
  void listenForTokenRefresh(String uid) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await saveFcmToken(uid, token: newToken);
    });
  }

  // ---------------- STATIONS ----------------
  Future<String> uploadStationImage(File imageFile, String stationId) async {
    final ref = _storage.ref().child('stations/$stationId.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<void> addStation(Map<String, dynamic> data) async {
    await _firestore.collection('stations').add(data);
  }

  Future<void> updateStation(String stationId, Map<String, dynamic> data) async {
    await _firestore.collection('stations').doc(stationId).update(data);
  }

  Future<void> deleteStation(String stationId) async {
    await _firestore.collection('stations').doc(stationId).delete();
  }

  Stream<QuerySnapshot> getStationsByOwner(String ownerId) {
    return _firestore
        .collection('stations')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();
  }

  // ---------------- BOOKINGS ----------------
  Future<void> createBooking(Map<String, dynamic> bookingData) async {
    await _firestore.collection('bookings').add(bookingData);
  }

  Stream<QuerySnapshot> getBookingsForStation(String stationId) {
    return _firestore
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .snapshots();
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
    });
  }

  // ---------------- NOTIFICATIONS ----------------
  Future<void> sendNotificationToFirestore(
      Map<String, dynamic> notification) async {
    await _firestore.collection('notifications').add(notification);
  }
}
