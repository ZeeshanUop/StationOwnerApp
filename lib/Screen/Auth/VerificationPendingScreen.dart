import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Pending'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Your account is not yet verified or approved by admin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.email),
                label: const Text("Resend Verification Email"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: () async {
                  await user?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification email sent again.')),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                child: const Text("Logout"),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pop(context); // go back to login
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
