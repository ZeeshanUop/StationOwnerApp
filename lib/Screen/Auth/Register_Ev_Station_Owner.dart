import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Splash/Splash Screen.dart';
import '../../core/services/Firebase_Services.dart';
import 'Ev_Station_Owner_login.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();



  bool isLoading = false;
  bool _obscurePassword = true;


  String generateLicenseKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final user = await _firebaseService.registerUser(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        final key = generateLicenseKey();

        await _firebaseService.saveStationOwner(user.uid, {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'license_key': key,
          'phone': phoneController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isApproved': false,
        });

        await _firebaseService.sendVerificationEmail(user);
        await _firebaseService.signOut();

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text("Verify Your Email"),
              content: const Text("Check your inbox to verify your email."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const Ev_Station_Owner_login()),
                    );
                  },
                  child: const Text("Go to Login"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildInput(TextEditingController controller, String label,
      {bool obscure = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: label == "Password" ? _obscurePassword : false,
        keyboardType: type,
        validator: (val) {
          if (val == null || val.isEmpty) return 'Required';
          if (label == 'Email' && !val.contains('@')) return 'Enter valid email';
          if (label == 'Phone Number' && val.length < 10) return 'Enter valid phone number';
          if (label == 'Password' && val.length < 6) return 'Minimum 6 characters';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: label == "Email"
              ? const Icon(Icons.email)
              : label == "Password"
              ? const Icon(Icons.lock)
              : const Icon(Icons.person),
          suffixIcon: label == "Password"
              ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }


  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text("Register as EV Station Owner"),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Image.asset('Assets/SplashScreen4.png', height: 140),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildInput(nameController, "Full Name"),
                        _buildInput(emailController, "Email", type: TextInputType.emailAddress),
                        _buildInput(passwordController, "Password", obscure: true),
                        _buildInput(phoneController, "Phone Number", type: TextInputType.phone),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : register,
                            icon: const Icon(Icons.app_registration),
                            label: isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text("Register & Generate License"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut(); // 👈 Force logout
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const Ev_Station_Owner_login()),
                            );
                          },
                          child: const Text("Already registered? Login"),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
