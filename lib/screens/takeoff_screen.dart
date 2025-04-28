import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Internal services and widgets
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../widgets/loading.dart';
import '../navigation_helper.dart';

/// Screen for initiating drone takeoff at a specified altitude.
///
/// Allows the user to select a height with a slider, then commands the drone to take off and navigates to the track selection screen.
class TakeoffScreen extends StatefulWidget {
  /// Creates the Takeoff screen widget.
  const TakeoffScreen({super.key});

  @override
  _TakeoffScreenState createState() => _TakeoffScreenState();
}

class _TakeoffScreenState extends State<TakeoffScreen> {
  /// Selected takeoff height in meters (1.0 - 10.0).
  double _takeoffHeight = 4.0;

  /// Indicates if a takeoff command is in progress.
  bool _takeoffInProgress = false;

  /// Indicates if the takeoff has completed successfully.
  bool _takeoffComplete = false;

  @override
  void initState() {
    super.initState();
    // Optionally hide keyboard on init
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// Sends takeoff command to the drone and handles navigation.
  Future<void> _initiateTakeoff() async {
    setState(() {
      _takeoffInProgress = true;
      _takeoffComplete = false;
    });

    try {
      // Perform takeoff via AuthService
      await AuthService.instance.takeoff(_takeoffHeight);
      setState(() => _takeoffComplete = true);
      // Brief delay to show confirmation icon
      await Future.delayed(const Duration(seconds: 1));
      // Navigate to track selection screen
      Navigator.pushReplacementNamed(context, '/trackSelection');
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Takeoff failed: $e')));
    } finally {
      // Reset progress state
      setState(() {
        _takeoffInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Custom back navigation handling
      onWillPop:
          () => NavigationHelper.onBackPressed(context, NavScreen.takeoff),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          // Back arrow with NavigationHelper logic
          leading: NavigationHelper.buildBackArrow(context, NavScreen.takeoff),
          title: const GradientText(
            text: 'Drone Takeoff',
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
                // End session if active
                if (AuthService.instance.sessionId != null) {
                  await AuthService.instance.endSession(
                    AuthService.instance.sessionId!,
                  );
                }
                // Logout and return to welcome screen
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
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Decorative takeoff icon in gradient circle
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
                  // Prompt text
                  Text(
                    'Select takeoff height (meters):',
                    style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
                  ),
                  const SizedBox(height: 20),
                  // Slider for height selection
                  Slider(
                    value: _takeoffHeight,
                    min: 1.0,
                    max: 10.0,
                    divisions: 18,
                    label: _takeoffHeight.toStringAsFixed(1),
                    activeColor: Colors.indigo,
                    inactiveColor: Colors.blueAccent.withOpacity(0.3),
                    onChanged:
                        (value) => setState(() {
                          _takeoffHeight = value;
                        }),
                  ),
                  // Display selected height
                  Text(
                    'Height: ${_takeoffHeight.toStringAsFixed(1)} m',
                    style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
                  ),
                  const Spacer(),
                  // Takeoff button
                  ElevatedButton(
                    onPressed: _initiateTakeoff,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Take Off'),
                  ),
                ],
              ),
            ),
            // Loading/confirmation overlay during takeoff
            if (_takeoffInProgress)
              LoadingWidget(
                text: 'Taking off...',
                isConfirmed: _takeoffComplete,
              ),
          ],
        ),
      ),
    );
  }
}
