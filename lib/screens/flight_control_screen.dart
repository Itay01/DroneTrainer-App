import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:drone_trainer/navigation_helper.dart';
import 'package:drone_trainer/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../widgets/gradient_text.dart';

enum FlightState { flying, stopped, landed, landing }

class FlightControlScreen extends StatefulWidget {
  const FlightControlScreen({Key? key}) : super(key: key);

  @override
  _FlightControlScreenState createState() => _FlightControlScreenState();
}

class _FlightControlScreenState extends State<FlightControlScreen> {
  // Flight parameters (to be set via navigation arguments)
  double _flightHeight = 1.0; // in meters (1–10)
  double _flightSpeed = 0.0; // in km/h (0–20)

  // Real-time telemetry
  double _currentAltitude = 1.0;
  double _currentSpeed = 0.0;
  int _batteryLevel = 100;

  // Live feed parameters
  bool _overlay = true;
  Uint8List? _liveFeedBytes;
  Uint8List? _liveFeedBytesFront;

  // Live feed Subscription
  StreamSubscription<List<Uint8List>>? _videoSub;

  // Flight state
  FlightState _flightState = FlightState.flying;

  // Subscription for live telemetry
  StreamSubscription<Map<String, dynamic>>? _telemetrySub;

  // Flight parameters
  bool _isHeightManual = false;
  bool _isSpeedManual = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to live telemetry
    _telemetrySub = AuthService.instance.subscribeTelemetry().listen(
      (msg) {
        final data = msg['data'];
        if (!mounted) return;
        setState(() {
          _currentAltitude = (data['position']['z_val'] as num)
              .toDouble()
              .abs()
              .clamp(1.0, 10.0);
          _currentSpeed = parseForwardSpeed(data);
          // extract battery if you have it in telemetry, otherwise keep
          // that `100` for now

          // === only auto-update if the user hasn’t touched the slider yet:
          if (!_isHeightManual) {
            _flightHeight = _currentAltitude.clamp(1.0, 10.0);
          }
          if (!_isSpeedManual) {
            _flightSpeed = _currentSpeed.clamp(0.0, 20.0);
          }
        });
      },
      onError: (err, st) => print('⚠️ telemetry error: $err\n$st'),
      onDone: () => print('ℹ️ telemetry stream closed'),
    );

    _videoSub = AuthService.instance.subscribeVideo(overlay: _overlay).listen((
      bytes,
    ) {
      if (!mounted) return;
      setState(() {
        _liveFeedBytes = bytes[0];
        _liveFeedBytesFront = bytes[1];
      });
    });
  }

  double parseForwardSpeed(Map<String, dynamic> telemetry) {
    // Unpack velocity
    final velData = telemetry['velocity'] as Map<String, dynamic>;
    num speed_x = velData['x_val'] as num;
    num speed_y = velData['y_val'] as num;

    // Calculate speed using Pythagorean theorem
    num speed = sqrt(pow(speed_x, 2) + pow(speed_y, 2));
    double speedMs = speed.toDouble();

    // Return km/h
    return speedMs * 3.6;
  }

  void _onOverlayToggled(bool val) {
    _videoSub?.cancel();
    AuthService.instance.unsubscribeVideo();

    _overlay = val;
    _videoSub = AuthService.instance.subscribeVideo(overlay: _overlay).listen((
      bytes,
    ) {
      if (!mounted) return;
      setState(() {
        _liveFeedBytes = bytes[0];
        _liveFeedBytesFront = bytes[1];
      });
    });
  }

  @override
  void dispose() {
    print("ℹ️ FlightControlScreen disposed");

    // Unsubscribe server-side
    AuthService.instance.unsubscribeTelemetry();
    // Cancel local subscription
    _telemetrySub?.cancel();

    // Unsubscribe video stream
    AuthService.instance.unsubscribeVideo();
    // Cancel local subscription
    _videoSub?.cancel();
    super.dispose();
  }

  // Dummy actions
  Future<void> _updateFlight() async {
    try {
      await AuthService.instance.setAltitude(_flightHeight);
      await AuthService.instance.setSpeed(_flightSpeed);

      setState(() {
        _isHeightManual = false;
        _isSpeedManual = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update flight: $e')));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Flight parameters updated')));
  }

  Future<void> _resumeFlight() async {
    try {
      await AuthService.instance.startFly();
      setState(() => _flightState = FlightState.flying);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to resume flight: $e')));
    }
  }

  Future<void> _stopFlight() async {
    try {
      await AuthService.instance.stopFly();
      setState(() {
        _flightState = FlightState.stopped;

        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            _flightSpeed = 0.0;
            _currentSpeed = 0.0;
          });
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to stop flight: $e')));
    }
  }

  Future<void> _landFlight() async {
    setState(() => _flightState = FlightState.landing);
    try {
      await AuthService.instance.land();
      setState(() {
        _flightState = FlightState.landed;
        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            _flightHeight = 0.0;
            _currentAltitude = 0.0;
          });
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to land: $e')));
    }
  }

  void _createNewFlight() {
    Navigator.pushReplacementNamed(context, '/takeoff');
  }

  Future<void> _disconnect() async {
    try {
      await AuthService.instance.disconnectDrone();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/connectDrone',
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to disconnect: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop:
          () =>
              NavigationHelper.onBackPressed(context, NavScreen.flightControl),
      child: Scaffold(
        appBar: AppBar(
          title: GradientText(
            text: 'Flight Control',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.flightControl,
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (_flightState == FlightState.flying) {
                  await AuthService.instance.stopFly();
                }
                if (_flightState != FlightState.landed) {
                  await AuthService.instance.land();
                }
                await AuthService.instance.endSession(
                  AuthService.instance.sessionId ?? '',
                );
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Telemetry Card
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    // margin: EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMetric(
                            'Altitude',
                            '${_currentAltitude.toStringAsFixed(1)} m',
                          ),
                          _buildMetric(
                            'Speed',
                            '${_currentSpeed.toStringAsFixed(1)} km/h',
                          ),
                          _buildMetric('Battery', '$_batteryLevel%'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  // Live feed
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(text: 'Front Camera'),
                              Tab(text: 'Bottom Camera'),
                            ],
                          ),
                          Expanded(
                            // now this Expanded has bounded space
                            child: TabBarView(
                              children: [
                                Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child:
                                          _liveFeedBytesFront != null
                                              ? Image.memory(
                                                _liveFeedBytesFront!,
                                                fit: BoxFit.cover,
                                                gaplessPlayback:
                                                    true, // ← keep the last frame visible
                                              )
                                              : Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                    ),
                                  ),
                                ),
                                Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      fit: StackFit.expand, // ← add this
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child:
                                              _liveFeedBytes != null
                                                  ? Image.memory(
                                                    _liveFeedBytes!,
                                                    fit: BoxFit.cover,
                                                    gaplessPlayback: true,
                                                  )
                                                  : Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            // wrap icon in a grey circle
                                            icon: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[600]!
                                                    .withOpacity(0.7),
                                                shape: BoxShape.circle,
                                              ),
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                _overlay
                                                    ? Icons.visibility
                                                    : Icons.visibility_off,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            onPressed:
                                                () => _onOverlayToggled(
                                                  !_overlay,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Spacer(),
                  SizedBox(height: 16),
                  // Height slider
                  Text(
                    'Height (${_flightHeight.toStringAsFixed(1)} m)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.indigo[900], // Using Flutter's Colors
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _flightHeight > 0 ? _flightHeight : 1.0,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          label: _flightHeight.toStringAsFixed(1),
                          activeColor:
                              _isHeightManual
                                  ? Colors.grey
                                  : Colors.indigo, // gray if manual
                          onChanged:
                              (val) => setState(() {
                                _flightHeight = val;
                                _isHeightManual = true;
                              }),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        color: Colors.indigo,
                        tooltip: 'Reset to telemetry',
                        onPressed:
                            () => setState(() {
                              _flightHeight = _currentAltitude.clamp(1.0, 10.0);
                              _isHeightManual = false; // re-enable auto-follow
                            }),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Speed slider
                  Text(
                    'Speed (${_flightSpeed.toStringAsFixed(1)} km/h)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.indigo[900],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _flightSpeed,
                          min: 0,
                          max: 20,
                          divisions: 20,
                          label: _flightSpeed.toStringAsFixed(1),
                          activeColor:
                              _isSpeedManual
                                  ? Colors.grey
                                  : Colors.blueAccent, // gray if manual
                          onChanged:
                              (val) => setState(() {
                                _flightSpeed = val;
                                _isSpeedManual = true;
                              }),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh),
                        color: Colors.blueAccent,
                        tooltip: 'Reset to telemetry',
                        onPressed:
                            () => setState(() {
                              _flightSpeed = _currentSpeed.clamp(0.0, 20.0);
                              _isSpeedManual = false; // re-enable auto-follow
                            }),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),
                  // Action buttons based on state
                  if (_flightState == FlightState.flying) ...[
                    ElevatedButton(
                      onPressed: _updateFlight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Update Flight'),
                    ),
                    SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _stopFlight,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Stop Flight'),
                    ),
                  ] else if (_flightState == FlightState.stopped) ...[
                    ElevatedButton(
                      onPressed: _resumeFlight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Resume Flight'),
                    ),
                    SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _landFlight,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orangeAccent),
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Land'),
                    ),
                  ] else if (_flightState == FlightState.landed ||
                      _flightState == FlightState.landing) ...[
                    ElevatedButton(
                      onPressed: _createNewFlight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('New Flight'),
                    ),
                    SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _disconnect,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey),
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Disconnect Drone'),
                    ),
                  ],
                ],
              ),
            ),

            // 3) Landing overlay
            if (_flightState == FlightState.landing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Landing…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900],
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }
}
