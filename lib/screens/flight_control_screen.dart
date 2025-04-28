import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// Internal navigation and service imports
import 'package:drone_trainer/navigation_helper.dart';
import 'package:drone_trainer/services/auth_service.dart';
import 'package:drone_trainer/widgets/loading.dart';
import '../widgets/gradient_text.dart';

/// Possible states of the flight control UI.
enum FlightState { flying, stopped, landed, landing }

/// Screen for real-time flight control, telemetry display, and live video.
class FlightControlScreen extends StatefulWidget {
  /// Creates the Flight Control screen widget.
  const FlightControlScreen({Key? key}) : super(key: key);

  @override
  _FlightControlScreenState createState() => _FlightControlScreenState();
}

class _FlightControlScreenState extends State<FlightControlScreen> {
  // ─── Flight parameters (modifiable via sliders) ─────────────────────────
  double _flightHeight = 1.0; // meters (range 1–10)
  double _flightSpeed = 0.0; // km/h (range 0–20)

  // ─── Real-time telemetry values ───────────────────────────────────────
  double _currentAltitude = 1.0; // meters, absolute
  double _currentSpeed = 0.0; // km/h
  int _batteryLevel = 100; // percent (placeholder)

  // ─── Live video feed state ───────────────────────────────────────────
  bool _overlay = true; // overlay on/off
  Uint8List? _liveFeedBytes; // bottom camera feed
  Uint8List? _liveFeedBytesFront; // front camera feed

  // Stream subscriptions for telemetry and video
  StreamSubscription<List<Uint8List>>? _videoSub;
  StreamSubscription<Map<String, dynamic>>? _telemetrySub;

  // ─── Flight lifecycle state ─────────────────────────────────────────
  FlightState _flightState = FlightState.flying;
  bool _isLanding = false; // whether landing overlay is active

  // ─── Manual override flags ──────────────────────────────────────────
  bool _isHeightManual = false; // user touched height slider
  bool _isSpeedManual = false; // user touched speed slider

  @override
  void initState() {
    super.initState();
    // Subscribe to telemetry updates
    _telemetrySub = AuthService.instance.subscribeTelemetry().listen(
      _handleTelemetry,
      onError: (e, st) => print('⚠️ telemetry error: $e'),
    );

    // Subscribe to video feed with overlay option
    _videoSub = AuthService.instance
        .subscribeVideo(overlay: _overlay)
        .listen(_handleVideo);
  }

  /// Handles incoming telemetry messages.
  void _handleTelemetry(Map<String, dynamic> msg) {
    final data = msg['data'];
    if (!mounted) return;
    setState(() {
      // Altitude is z_val (negative downwards), take absolute
      _currentAltitude = (data['position']['z_val'] as num)
          .toDouble()
          .abs()
          .clamp(1.0, 10.0);
      // Convert x/y velocity to forward speed
      _currentSpeed = _parseForwardSpeed(data);

      // Auto-update UI sliders if not manually overridden
      if (!_isHeightManual) {
        _flightHeight = _currentAltitude;
      }
      if (!_isSpeedManual) {
        _flightSpeed = _currentSpeed;
      }
    });
  }

  /// Parses forward velocity components into km/h.
  double _parseForwardSpeed(Map<String, dynamic> telemetry) {
    final vel = telemetry['velocity'] as Map<String, dynamic>;
    final x = (vel['x_val'] as num).toDouble();
    final y = (vel['y_val'] as num).toDouble();
    final speedMs = sqrt(x * x + y * y);
    return speedMs * 3.6; // m/s → km/h
  }

  /// Handles incoming video frame updates.
  void _handleVideo(List<Uint8List> bytes) {
    if (!mounted) return;
    setState(() {
      // bytes[0] = bottom camera, bytes[1] = front camera
      _liveFeedBytes = bytes[0];
      _liveFeedBytesFront = bytes[1];
    });
  }

  /// Toggles overlay on the bottom camera feed.
  void _onOverlayToggled(bool val) {
    _videoSub?.cancel();
    AuthService.instance.unsubscribeVideo();
    _overlay = val;
    _videoSub = AuthService.instance
        .subscribeVideo(overlay: _overlay)
        .listen(_handleVideo);
  }

  @override
  void dispose() {
    // Clean up subscriptions and notify server
    if (AuthService.instance.token != '') {
      AuthService.instance.unsubscribeTelemetry();
      _telemetrySub?.cancel();
      AuthService.instance.unsubscribeVideo();
      _videoSub?.cancel();
    }
    super.dispose();
  }

  // ─── Flight control actions ──────────────────────────────────────────

  /// Applies manual updates for height and speed.
  Future<void> _updateFlight() async {
    try {
      await AuthService.instance.setAltitude(_flightHeight);
      await AuthService.instance.setSpeed(_flightSpeed);
      setState(() {
        _isHeightManual = false;
        _isSpeedManual = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flight parameters updated')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update flight: $e')));
    }
  }

  /// Resumes the flight loop after a stop.
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

  /// Stops the flight loop and resets speed display.
  Future<void> _stopFlight() async {
    try {
      await AuthService.instance.stopFly();
      setState(() => _flightState = FlightState.stopped);
      // Clear speed after delay
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _flightSpeed = 0.0;
          _currentSpeed = 0.0;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to stop flight: $e')));
    }
  }

  /// Initiates landing sequence and shows overlay until complete.
  Future<void> _landFlight() async {
    setState(() {
      _flightState = FlightState.landing;
      _isLanding = true;
    });
    try {
      await AuthService.instance.land();
      setState(() => _flightState = FlightState.landed);
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _flightHeight = 0.0;
          _currentAltitude = 0.0;
          _isLanding = false;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to land: $e')));
    }
  }

  /// Starts a new flight by navigating to the takeoff screen.
  void _createNewFlight() {
    Navigator.pushReplacementNamed(context, '/takeoff');
  }

  /// Disconnects the drone and returns to the initial screen.
  Future<void> _disconnect() async {
    try {
      await AuthService.instance.disconnectDrone();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/connectDrone',
        (route) => false,
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
      // Custom back handling for flight control screen
      onWillPop:
          () =>
              NavigationHelper.onBackPressed(context, NavScreen.flightControl),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          // Title with gradient text
          title: const GradientText(
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
                // 1) Stop & cancel all client-side subscriptions
                _telemetrySub?.cancel();
                AuthService.instance.unsubscribeTelemetry();
                _videoSub?.cancel();
                AuthService.instance.unsubscribeVideo();

                await Future.delayed(const Duration(seconds: 1));

                try {
                  // 3) Now it’s safe to clear your session
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
                } catch (e) {
                  print('⚠️ logout error: $e');
                }

                // 4) And finally navigate away
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Telemetry display card
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                  const SizedBox(height: 6),
                  // Live camera feed with tabs
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Front Camera'),
                              Tab(text: 'Bottom Camera'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildCameraCard(
                                  // front camera
                                  _liveFeedBytesFront,
                                  overlayToggle: false,
                                ),
                                _buildCameraCard(
                                  // bottom camera with overlay button
                                  _liveFeedBytes,
                                  overlayToggle: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Height control slider + reset
                  _buildSliderControl(
                    label: 'Height',
                    unit: 'm',
                    value: _flightHeight != 0.0 ? _flightHeight : 1.0,
                    min: 1.0,
                    max: 10.0,
                    manualFlag: _isHeightManual,
                    onChanged:
                        (v) => setState(() {
                          _flightHeight = v;
                          _isHeightManual = true;
                        }),
                    onReset:
                        () => setState(() {
                          _flightHeight = _currentAltitude;
                          _isHeightManual = false;
                        }),
                  ),
                  const SizedBox(height: 8),
                  // Speed control slider + reset
                  _buildSliderControl(
                    label: 'Speed',
                    unit: 'km/h',
                    value: _flightSpeed,
                    min: 0.0,
                    max: 20.0,
                    manualFlag: _isSpeedManual,
                    onChanged:
                        (v) => setState(() {
                          _flightSpeed = v;
                          _isSpeedManual = true;
                        }),
                    onReset:
                        () => setState(() {
                          _flightSpeed = _currentSpeed;
                          _isSpeedManual = false;
                        }),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons based on flight state
                  ..._buildActionButtons(),
                ],
              ),
            ),
            // Overlay during landing
            if (_flightState == FlightState.landing || _isLanding)
              LoadingWidget(
                text: 'Landing...',
                isConfirmed: _flightState == FlightState.landed,
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a camera feed card, optionally with overlay toggle button.
  Widget _buildCameraCard(Uint8List? bytes, {bool overlayToggle = false}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child:
                  bytes != null
                      ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                      : const Center(child: CircularProgressIndicator()),
            ),
            if (overlayToggle)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[600]!.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _overlay ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => _onOverlayToggled(!_overlay),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a slider with a reset icon for a control parameter.
  Widget _buildSliderControl({
    required String label,
    required String unit,
    required double value,
    required double min,
    required double max,
    required bool manualFlag,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (${value.toStringAsFixed(1)} $unit)',
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
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) * 10).toInt(),
                label: value.toStringAsFixed(1),
                activeColor: manualFlag ? Colors.grey : Colors.indigo,
                onChanged: onChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              color: manualFlag ? Colors.grey : Colors.indigo,
              tooltip: 'Reset to telemetry',
              onPressed: onReset,
            ),
          ],
        ),
      ],
    );
  }

  /// Returns action buttons based on the current [_flightState].
  List<Widget> _buildActionButtons() {
    switch (_flightState) {
      case FlightState.flying:
        return [
          ElevatedButton(
            onPressed: _updateFlight,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Update Flight'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _stopFlight,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Stop Flight'),
          ),
        ];
      case FlightState.stopped:
        return [
          ElevatedButton(
            onPressed: _resumeFlight,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Resume Flight'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _landFlight,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orangeAccent),
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Land'),
          ),
        ];
      case FlightState.landing:
      case FlightState.landed:
        return [
          ElevatedButton(
            onPressed: _createNewFlight,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('New Flight'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _disconnect,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Disconnect Drone'),
          ),
        ];
    }
  }

  /// Builds an individual metric display (e.g., altitude, speed).
  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
