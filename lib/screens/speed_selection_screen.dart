import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';

class SpeedSelectionScreen extends StatefulWidget {
  const SpeedSelectionScreen({Key? key}) : super(key: key);

  @override
  _SpeedSelectionScreenState createState() => _SpeedSelectionScreenState();
}

class _SpeedSelectionScreenState extends State<SpeedSelectionScreen> {
  double _speed = 10.0; // default speed (range: 0 - 20 km/h)

  Future<void> _setSpeed() async {
    try {
      // Simulate speed setting process.
      await AuthService.instance.setSpeed(_speed);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to set speed: $e')));
    }
  }

  Future<void> _initiateFlight() async {
    try {
      // Simulate flight initiation process.
      await _setSpeed();
      await AuthService.instance.startFly();

      // Navigate to flight control screen.
      Navigator.pushNamed(context, '/flightControl');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flight initiation failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          text: "Drone Takeoff - Speed",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          gradient: LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Illustration.
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
            // Slider for speed selection.
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
              onPressed: () {
                _initiateFlight();
                Navigator.pushReplacementNamed(context, '/flightControl');
              },
              child: Text('Fly!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
