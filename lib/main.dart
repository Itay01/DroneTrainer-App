import 'dart:io';

import 'package:flutter/material.dart';

// Screen widget imports
import 'screens/splash_screen.dart';
import 'screens/welcome_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/connect_drone_screen.dart';
import 'screens/new_drone_connection_screen.dart';
import 'screens/takeoff_screen.dart';
import 'screens/track_selection_screen.dart';
import 'screens/speed_selection_screen.dart';
import 'screens/flight_control_screen.dart';

/// Allows self-signed or invalid SSL certificates (development only).
class _AllowBadCerts extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // Accept any certificate (not secure for production!)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

/// Entry point of the application.
/// Sets up HTTP overrides and runs the Flutter app.
void main() {
  // Override HTTP client to trust bad certificates in development.
  HttpOverrides.global = _AllowBadCerts();
  runApp(const DroneControlApp());
}

/// Root widget of the Drone Control application.
/// Configures named routes and global app settings.
class DroneControlApp extends StatelessWidget {
  /// Creates the main app widget.
  const DroneControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App title shown in task switcher
      title: 'Drone Control App',
      // Remove the debug banner
      debugShowCheckedModeBanner: false,
      // Initial route displayed on startup
      initialRoute: '/',
      // Named routes for navigation
      routes: {
        '/': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/connectDrone': (context) => const ConnectDroneScreen(),
        '/newDroneConnection': (context) => const NewDroneConnectionScreen(),
        '/takeoff': (context) => const TakeoffScreen(),
        '/trackSelection': (context) => const TrackSelectionScreen(),
        '/speedSelection': (context) => const SpeedSelectionScreen(),
        '/flightControl': (context) => const FlightControlScreen(),
      },
      // Theme and other global config can be added here
    );
  }
}
