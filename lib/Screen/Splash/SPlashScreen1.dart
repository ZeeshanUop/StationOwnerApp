import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project_2/Screen/Auth/Ev_Station_Owner_login.dart';
import 'package:fyp_project_2/Screen/Dashboard/Ev_station_owner_screen.dart';
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  void _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3)); // Optional shorter splash
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // ✅ Auto-login: user already signed in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_)=>StationOwnerDashboardMain())
      );
    } else {
      // Not signed in: go to onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Ev_Station_Owner_login()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            alignment: Alignment.center,
            image: AssetImage('Assets/14.jpg'),
          ),
        ),
      ),
    );
  }
}
