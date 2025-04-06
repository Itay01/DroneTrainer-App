import 'package:flutter/material.dart';
import '../widgets/gradient_text.dart';

class TrackSelectionScreen extends StatelessWidget {
  const TrackSelectionScreen({Key? key}) : super(key: key);

  // Dummy list of tracks.
  final List<String> tracks = const ['Track 1', 'Track 2', 'Track 3'];

  @override
  Widget build(BuildContext context) {
    // Retrieve the takeoff height passed from the TakeoffScreen.
    final double takeoffHeight =
        ModalRoute.of(context)?.settings.arguments as double? ?? 2.0;

    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          text: "Select Running Track",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          gradient: LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          // Simulated drone camera feed.
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[300],
            child: Center(
              child: Text(
                'Drone Camera Feed',
                style: TextStyle(fontSize: 20, color: Colors.black54),
              ),
            ),
          ),
          // Semi-transparent overlay.
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.2),
          ),
          // Overlayed track selection buttons.
          for (var i = 0; i < tracks.length; i++)
            Positioned(
              left:
                  i == 0
                      ? 30
                      : i == 2
                      ? 80
                      : null,
              right: i == 1 ? 30 : null,
              top:
                  i == 0
                      ? 80
                      : i == 1
                      ? 180
                      : null,
              bottom: i == 2 ? 80 : null,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      i % 2 == 0 ? Colors.indigo : Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  // Navigate to the confirmation screen with the chosen track and takeoff height.
                  Navigator.pushReplacementNamed(
                    context,
                    '/speedSelection',
                    arguments: {'track': tracks[i], 'height': takeoffHeight},
                  );
                },
                child: Text(tracks[i]),
              ),
            ),
        ],
      ),
    );
  }
}
