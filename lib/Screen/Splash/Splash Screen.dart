import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Auth/Ev_Station_Owner_login.dart';
import '../Dashboard/Ev_station_owner_screen.dart'; // Your main screen after login
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class SplashScreen1 extends StatefulWidget {
  const SplashScreen1({super.key});

  @override
  State<SplashScreen1> createState() => _SplashScreen1State();
}

class _SplashScreen1State extends State<SplashScreen1> {
  final PageController _controller = PageController();
  bool onLastPage = false;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => onLastPage = index == 2);
              },
              children: const [
                SplashPage(
                  image: 'Assets/SplashScreen2.png',
                  text: '🚗 Powering the Future of Mobility',
                  subtitle:
                  'Register your EV charging station and join the clean energy revolution.',
                ),
                SplashPage(
                  image: 'Assets/SplashScreen3.png',
                  text: '⚡ Real-Time Station Management',
                  subtitle:
                  'Update slots, respond to bookings, and stay connected with EV users in real time.',
                ),
                SplashPage(
                  image: 'Assets/SplashScreen4.png',
                  text: '📈 Grow Your Business with Ease',
                  subtitle:
                  'Track bookings, manage availability, and monitor performance — all in one place.',
                ),
              ],
            ),

            // Dot Indicator
            Positioned(
              bottom: 60,
              child: SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: WormEffect(
                  activeDotColor: Colors.blue,
                  dotColor: Colors.grey.shade300,
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 16,
                ),
              ),
            ),

            // Get Started button
            if (onLastPage)
              Positioned(
                left: 330,
                bottom: 40,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => Ev_Station_Owner_login()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.green,
                  ),
                  child: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
class SplashPage extends StatelessWidget {
  final String image;
  final String text;
  final String subtitle;

  const SplashPage({
    super.key,
    required this.image,
    required this.text,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 40,),
            Image.asset(
              image,
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 60),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


