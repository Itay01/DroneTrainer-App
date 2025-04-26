import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

class SpeedSelectionScreen extends StatefulWidget {
  const SpeedSelectionScreen({super.key});

  @override
  _SpeedSelectionScreenState createState() => _SpeedSelectionScreenState();
}

class _SpeedSelectionScreenState extends State<SpeedSelectionScreen> {
  double _speed = 10.0; // default speed (range: 0 - 20 km/h)

  Future<void> _setSpeed() async {
    try {
      await AuthService.instance.setSpeed(_speed);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to set speed: $e')));
    }
  }

  Future<void> _initiateFlight() async {
    try {
      await _setSpeed();
      await AuthService.instance.startFly();
      Navigator.pushReplacementNamed(context, '/flightControl');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flight initiation failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop:
          () =>
              NavigationHelper.onBackPressed(context, NavScreen.speedSelection),
      child: Scaffold(
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.speedSelection,
          ),
          title: GradientText(
            text: "Drone Takeoff - Speed",
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
                // stop current flight and clean up
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
        backgroundColor: Colors.grey[100],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.blueAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.speed, size: 60, color: Colors.white),
                ),
              ),
              SizedBox(height: 30),
              Text(
                'Select speed (km/h):',
                style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
              ),
              SizedBox(height: 20),
              Slider(
                value: _speed,
                min: 0,
                max: 20,
                divisions: 20,
                label: _speed.toStringAsFixed(0),
                activeColor: Colors.indigo,
                inactiveColor: Colors.blueAccent.withOpacity(0.3),
                onChanged: (value) {
                  setState(() {
                    _speed = value;
                  });
                },
              ),
              Text(
                'Speed: ${_speed.toStringAsFixed(0)} km/h',
                style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: _initiateFlight,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text('Fly!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
