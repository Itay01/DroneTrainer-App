import 'package:flutter/material.dart';

// Internal widgets and navigation helper
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

/// Welcome screen with options to log in or register.
///
/// Includes a decorative icon, greeting text, and buttons
/// to navigate to the login and register pages.
class WelcomePage extends StatelessWidget {
  /// Creates the WelcomePage widget.
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Intercept hardware back press to confirm exit
      onWillPop:
          () => NavigationHelper.onBackPressed(context, NavScreen.welcome),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          // No back arrow; title uses gradient text
          title: const GradientText(
            text: 'Welcome',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decorative icon in gradient circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.indigo, Colors.blueAccent],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.flight_takeoff,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Greeting text
                Text(
                  'Welcome to the Autonomous Drone App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.indigo[900],
                  ),
                ),
                const SizedBox(height: 40),
                // Login button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Login'),
                ),
                const SizedBox(height: 20),
                // Register button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
