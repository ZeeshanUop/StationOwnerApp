import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteProvider with ChangeNotifier {
  final List<String> _favoriteNames = [];
  final _auth = FirebaseAuth.instance;

  List<String> get favorites => _favoriteNames;

  FavoriteProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('favorites')) {
        final favList = List<String>.from(data['favorites']);
        _favoriteNames
          ..clear()
          ..addAll(favList);
        notifyListeners();
      }
    }
  }

  Future<void> _saveFavoritesToFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'favorites': _favoriteNames}, SetOptions(merge: true));
    }
  }

  Future<void> addFavorite(String stationName) async {
    if (!_favoriteNames.contains(stationName)) {
      _favoriteNames.add(stationName);
      notifyListeners();
      await _saveFavoritesToFirestore();
    }
  }

  Future<void> removeFavorite(String stationName) async {
    if (_favoriteNames.remove(stationName)) {
      notifyListeners();
      await _saveFavoritesToFirestore();
    }
  }

  Future<void> toggleFavorite(String stationName) async {
    if (_favoriteNames.contains(stationName)) {
      await removeFavorite(stationName);
    } else {
      await addFavorite(stationName);
    }
  }

  bool isFavorite(String stationName) {
    return _favoriteNames.contains(stationName);
  }
}
