import 'package:flutter/material.dart';
import '../widgets/gradient_text.dart';

class SpeedSelectionScreen extends StatefulWidget {
  const SpeedSelectionScreen({Key? key}) : super(key: key);

  @override
  _SpeedSelectionScreenState createState() => _SpeedSelectionScreenState();
}

class _SpeedSelectionScreenState extends State<SpeedSelectionScreen> {
  double _speed = 10.0; // default speed (range: 0 - 20 km/h)
  late double _height; // height value passed from the previous screen
  late String _track; // track value passed from the previous screen

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve the chosen height and track from the route arguments.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _height = args['height'] ?? 2.0;
      _track = args['track'] ?? 'Unknown Track';
    } else {
      _height = 2.0;
      _track = 'Unknown Track';
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
                // Navigate to flight control, passing track, height, and speed.
                Navigator.pushReplacementNamed(
                  context,
                  '/flightControl',
                  arguments: {
                    'track': _track,
                    'height': _height,
                    'speed': _speed,
                  },
                );
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
