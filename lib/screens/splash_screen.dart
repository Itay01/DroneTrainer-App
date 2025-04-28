import 'package:flutter/material.dart';

// Internal service for authentication and session management
import '../services/auth_service.dart';

/// Initial splash screen that bootstraps the app.
///
/// Checks if the user is already authenticated and if there's an active
/// drone session to resume; navigates to the appropriate screen.
class SplashScreen extends StatefulWidget {
  /// Creates the splash screen widget.
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Begin app initialization and session check
    _bootstrap();
  }

  /// Initializes AuthService and determines the next screen.
  ///
  /// - If init succeeds and a previous flying session exists, resumes it.
  /// - If init succeeds but no session to resume, goes to connect drone screen.
  /// - If init fails, goes to welcome screen for login/register.
  Future<void> _bootstrap() async {
    final ok = await AuthService.instance.init();
    if (!mounted) return;

    if (ok) {
      // Fetch any current sessions for this user
      final sessions = await AuthService.instance.getCurrentSessions();
      bool continueSession = false;

      for (final session in sessions) {
        if (session['session_id'] == AuthService.instance.sessionId) {
          if (session['status'] == 'flying') {
            // Resume if it was flying
            continueSession = true;
          } else {
            // End any non-flying session
            continueSession = false;
            try {
              await AuthService.instance.endSession(session['session_id']);
            } catch (e) {
              // Show error if unable to end prior session
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to end previous session: \$e'),
                  ),
                );
              }
            }
          }
        }
      }

      // Navigate based on session state
      if (continueSession) {
        Navigator.pushReplacementNamed(context, '/flightControl');
      } else {
        Navigator.pushReplacementNamed(context, '/connectDrone');
      }
    } else {
      // Not authenticated: go to welcome screen
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen gradient background with app title
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.blueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.airplanemode_active, size: 120, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Autonomous Drone App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
