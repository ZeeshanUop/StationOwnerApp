import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/Firebase_Services.dart';
import '../Stations/My_station.dart';
import '../Dashboard/Ev_station_owner_screen.dart';
import 'Register_Ev_Station_Owner.dart';
import 'VerificationPendingScreen.dart';

class Ev_Station_Owner_login extends StatefulWidget {
  const Ev_Station_Owner_login({super.key});

  @override
  State<Ev_Station_Owner_login> createState() => _Ev_Station_Owner_loginState();
}

class _Ev_Station_Owner_loginState extends State<Ev_Station_Owner_login> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final licenseKeyController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    autoLoginIfAlreadyAuthenticated();
  }

  Future<void> autoLoginIfAlreadyAuthenticated() async {
    final user = _firebaseService.getCurrentUser();
    await user?.reload();

    if (user != null) {
      if (!user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
        );
        return;
      }

      final doc = await _firebaseService.getStationOwner(user.uid);
      final data = doc?.data() as Map<String, dynamic>?;

      if (data != null && data['isApproved'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StationOwnerDashboardMain()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
        );
      }
    }
  }

  Future<void> validateLogin() async {
    setState(() => isLoading = true);
    try {
      final user = await _firebaseService.loginUser(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null && user.emailVerified) {
        final doc = await _firebaseService.getStationOwner(user.uid);
        final data = doc?.data() as Map<String, dynamic>?;

        if (data == null) {
          await _firebaseService.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No registration record found.")),
          );
          return;
        }

        final storedKey = data['license_key'];
        final isApproved = data['isApproved'] == true;

        if (licenseKeyController.text.trim() != storedKey) {
          await _firebaseService.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid license key.")),
          );
          return;
        }

        if (!isApproved) {
          await _firebaseService.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Your account is awaiting admin approval.")),
          );
          return;
        }

        // 🔥 Save FCM token on successful login
        await _firebaseService.saveFcmToken(user.uid);
        _firebaseService.listenForTokenRefresh(user.uid);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StationOwnerDashboardMain()),
        );
      } else {
        await user?.sendEmailVerification();
        await _firebaseService.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please verify your email first.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showResetPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: "Enter your email"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firebaseService.sendPasswordReset(
                  resetEmailController.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password reset email sent")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Send Reset Email"),
          ),
        ],
      ),
    );
  }


  Widget _buildInput(TextEditingController controller, String label, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          prefixIcon: label == "Email"
              ? const Icon(Icons.email)
              : label == "Password"
              ? const Icon(Icons.lock)
              : const Icon(Icons.verified_user),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text("EV Station Owner Login"),

        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Image.asset('Assets/SplashScreen2.png', height: 150),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInput(emailController, "Email"),
                    _buildInput(passwordController, "Password", obscure: true),
                    _buildInput(licenseKeyController, "License Key"),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : validateLogin,
                        icon: const Icon(Icons.login),
                        label: isLoading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Text("Login", style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: showResetPasswordDialog,
                      child: const Text("Forgot Password?"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: ()async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                    );
                  },
                  child: const Text('Register Now'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
