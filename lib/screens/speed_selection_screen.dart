import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Internal services and helpers
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

/// Screen for selecting drone flight speed before starting the flight loop.
///
/// Allows the user to choose a speed (0–20 km/h), applies it to the drone,
/// and navigates to the live flight control screen.
class SpeedSelectionScreen extends StatefulWidget {
  /// Creates the SpeedSelection screen widget.
  const SpeedSelectionScreen({super.key});

  @override
  _SpeedSelectionScreenState createState() => _SpeedSelectionScreenState();
}

class _SpeedSelectionScreenState extends State<SpeedSelectionScreen> {
  /// Selected speed in km/h (range 0 to 20).
  double _speed = 10.0;

  /// Sends the selected speed to the drone via AuthService.
  Future<void> _setSpeed() async {
    try {
      await AuthService.instance.setSpeed(_speed);
    } catch (e) {
      // Show error message on failure
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to set speed: \$e')));
    }
  }

  /// Applies speed, starts the flight loop, and navigates to control screen.
  Future<void> _initiateFlight() async {
    try {
      await _setSpeed();
      await AuthService.instance.startFly();
      Navigator.pushReplacementNamed(context, '/flightControl');
    } catch (e) {
      // Show error if flight initiation fails
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flight initiation failed: \$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Use custom back handling to return to track selection
      onWillPop:
          () =>
              NavigationHelper.onBackPressed(context, NavScreen.speedSelection),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          // Back arrow with NavigationHelper
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.speedSelection,
          ),
          title: const GradientText(
            text: 'Drone Takeoff - Speed',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Land and end session before logout
                await AuthService.instance.land();
                await AuthService.instance.endSession(
                  AuthService.instance.sessionId ?? '',
                );
                await AuthService.instance.logout();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/welcome',
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Speed icon in gradient circle
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
                  child: Icon(Icons.speed, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 30),
              // Prompt for speed selection
              Text(
                'Select speed (km/h):',
                style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
              ),
              const SizedBox(height: 20),
              // Slider to choose speed
              Slider(
                value: _speed,
                min: 0.0,
                max: 20.0,
                divisions: 20,
                label: _speed.toStringAsFixed(0),
                activeColor: Colors.indigo,
                inactiveColor: Colors.blueAccent.withOpacity(0.3),
                onChanged:
                    (value) => setState(() {
                      _speed = value;
                    }),
              ),
              // Display selected speed
              Text(
                'Speed: ${_speed.toStringAsFixed(0)} km/h',
                style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
              ),
              const Spacer(),
              // Button to start flight
              ElevatedButton(
                onPressed: _initiateFlight,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Fly!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
