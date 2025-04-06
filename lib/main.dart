import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/connect_screen.dart';
import 'screens/new_drone_connection_screen.dart';
import 'screens/takeoff_screen.dart';
import 'screens/track_selection_screen.dart';
import 'screens/speed_selection_screen.dart';
import 'screens/flight_control_screen.dart';

void main() {
  runApp(DroneControlApp());
}

class DroneControlApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Control App',
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/welcome': (context) => WelcomePage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/connect': (context) => ConnectScreen(),
        '/newDroneConnection': (context) => NewDroneConnectionScreen(),
        '/takeoff': (context) => TakeoffScreen(),
        '/trackSelection': (context) => TrackSelectionScreen(),
        '/speedSelection': (context) => SpeedSelectionScreen(),
        '/flightControl': (context) => FlightControlScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
