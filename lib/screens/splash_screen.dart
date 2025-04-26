import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final ok = await AuthService.instance.init(); // ← new
    if (!mounted) return;
    if (ok) {
      final sessions = await AuthService.instance.getCurrentSessions();
      if (sessions.isNotEmpty) {
        bool sessionFound = false;
        for (final session in sessions) {
          if (session["session_id"] == AuthService.instance.sessionId) {
            sessionFound = true;
          }
        }
        if (sessionFound) {
          Navigator.pushReplacementNamed(context, '/flightControl');
        } else {
          Navigator.pushReplacementNamed(context, '/connectDrone');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/connectDrone');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // original gradient UI stays exactly the same
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.blueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
