import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../widgets/loading.dart';
import '../navigation_helper.dart';

class TakeoffScreen extends StatefulWidget {
  const TakeoffScreen({super.key});

  @override
  _TakeoffScreenState createState() => _TakeoffScreenState();
}

class _TakeoffScreenState extends State<TakeoffScreen> {
  double _takeoffHeight = 4.0; // default height (range: 1 - 10 meters)
  bool _takeoffInProgress = false; // indicates if takeoff is in progress
  bool _takeoffComplete = false; // indicates if takeoff is complete

  Future<void> _initiateTakeoff() async {
    setState(() {
      _takeoffInProgress = true;
      _takeoffComplete = false;
    });

    try {
      await AuthService.instance.takeoff(_takeoffHeight);
      setState(() {
        _takeoffComplete = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacementNamed(context, '/trackSelection');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Takeoff failed: $e')));
    } finally {
      setState(() {
        _takeoffInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop:
          () => NavigationHelper.onBackPressed(context, NavScreen.takeoff),
      child: Scaffold(
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(context, NavScreen.takeoff),
          title: GradientText(
            text: "Drone Takeoff",
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
                // end session and return to welcome
                if (AuthService.instance.sessionId != null) {
                  await AuthService.instance.endSession(
                    AuthService.instance.sessionId!,
                  );
                }
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
        body: Stack(
          children: [
            Padding(
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
                      child: Icon(
                        Icons.flight_takeoff,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Text(
                    'Select takeoff height (meters):',
                    style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
                  ),
                  SizedBox(height: 20),
                  Slider(
                    value: _takeoffHeight,
                    min: 1,
                    max: 10,
                    divisions: 18,
                    label: _takeoffHeight.toStringAsFixed(1),
                    activeColor: Colors.indigo,
                    inactiveColor: Colors.blueAccent.withOpacity(0.3),
                    onChanged: (value) {
                      setState(() {
                        _takeoffHeight = value;
                      });
                    },
                  ),
                  Text(
                    'Height: ${_takeoffHeight.toStringAsFixed(1)} m',
                    style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: _initiateTakeoff,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: TextStyle(fontSize: 18),
                    ),
                    child: Text('Take Off'),
                  ),
                ],
              ),
            ),
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
