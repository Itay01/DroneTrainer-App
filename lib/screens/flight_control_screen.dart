import 'package:flutter/material.dart';
import '../widgets/gradient_text.dart';

class FlightControlScreen extends StatefulWidget {
  const FlightControlScreen({Key? key}) : super(key: key);

  @override
  _FlightControlScreenState createState() => _FlightControlScreenState();
}

class _FlightControlScreenState extends State<FlightControlScreen> {
  double _flightHeight = 2.0; // in meters (range: 2–5)
  int _flightSpeed = 0;       // in km/h (range: 0–20)

  // For demonstration, we simulate real-time metrics.
  double _currentAltitude = 2.0;
  int _currentSpeed = 0;
  int _batteryLevel = 100; // percentage

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve confirmed parameters from arguments.
    final Map args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    setState(() {
      _flightHeight = args['takeoffHeight'] ?? 2.0;
      _flightSpeed = args['initialSpeed'] ?? 0;
      _currentAltitude = _flightHeight; // initially, current altitude equals takeoff height
      _currentSpeed = _flightSpeed;
    });
  }

  void _decreaseHeight() {
    setState(() {
      if (_flightHeight > 2.0) {
        _flightHeight = (_flightHeight - 0.5).clamp(2.0, 5.0);
        _currentAltitude = _flightHeight; // simulate altitude update
      }
    });
  }

  void _increaseHeight() {
    setState(() {
      if (_flightHeight < 5.0) {
        _flightHeight = (_flightHeight + 0.5).clamp(2.0, 5.0);
        _currentAltitude = _flightHeight; // simulate altitude update
      }
    });
  }

  void _decreaseSpeed() {
    setState(() {
      if (_flightSpeed > 0) {
        _flightSpeed = (_flightSpeed - 1).clamp(0, 20);
        _currentSpeed = _flightSpeed; // simulate speed update
      }
    });
  }

  void _increaseSpeed() {
    setState(() {
      if (_flightSpeed < 20) {
        _flightSpeed = (_flightSpeed + 1).clamp(0, 20);
        _currentSpeed = _flightSpeed; // simulate speed update
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the confirmed track.
    final String selectedTrack =
        (ModalRoute.of(context)?.settings.arguments as Map?)?['track'] ?? 'Unknown Track';

    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          text: "Flight Control",
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
            // Real-time metrics card.
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetricItem("Altitude", "${_currentAltitude.toStringAsFixed(1)} m"),
                    _buildMetricItem("Speed", "${_currentSpeed} km/h"),
                    _buildMetricItem("Battery", "$_batteryLevel%"),
                  ],
                ),
              ),
            ),
            Text(
              'Flying on: $selectedTrack',
              style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
            ),
            SizedBox(height: 30),
            // Height control.
            Text(
              'Adjust Height (meters):',
              style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _decreaseHeight,
                  icon: Icon(Icons.remove_circle_outline),
                  color: Colors.indigo,
                  iconSize: 32,
                ),
                SizedBox(width: 20),
                Text(
                  '${_flightHeight.toStringAsFixed(1)} m',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 20),
                IconButton(
                  onPressed: _increaseHeight,
                  icon: Icon(Icons.add_circle_outline),
                  color: Colors.indigo,
                  iconSize: 32,
                ),
              ],
            ),
            SizedBox(height: 30),
            // Speed control.
            Text(
              'Adjust Speed (km/h):',
              style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _decreaseSpeed,
                  icon: Icon(Icons.remove_circle_outline),
                  color: Colors.blueAccent,
                  iconSize: 32,
                ),
                SizedBox(width: 20),
                Text(
                  '${_flightSpeed.toString()} km/h',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 20),
                IconButton(
                  onPressed: _increaseSpeed,
                  icon: Icon(Icons.add_circle_outline),
                  color: Colors.blueAccent,
                  iconSize: 32,
                ),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                // Send updated flight parameters (simulate).
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Flight parameters updated')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text('Update Flight'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo[900]),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
