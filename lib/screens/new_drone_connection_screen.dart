import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Internal services and widgets
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';
import '../widgets/loading.dart';

/// Screen for registering and connecting to a new drone.
///
/// Provides a form to manually enter drone name and IP, and
/// displays automatically discovered drones for quick selection.
class NewDroneConnectionScreen extends StatefulWidget {
  /// Creates the NewDroneConnection screen widget.
  const NewDroneConnectionScreen({super.key});

  @override
  _NewDroneConnectionScreenState createState() =>
      _NewDroneConnectionScreenState();
}

class _NewDroneConnectionScreenState extends State<NewDroneConnectionScreen> {
  /// Key for form validation.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controller for the drone name input field.
  final TextEditingController _droneNameController = TextEditingController();

  /// Controller for the IP address input field.
  final TextEditingController _ipController = TextEditingController();

  /// Scroll controller for the discovered drones list.
  final ScrollController _droneListController = ScrollController();

  /// Whether a connection attempt is in progress.
  bool _isConnecting = false;

  /// Whether the connection attempt has been confirmed.
  bool _isConfirmed = false;

  /// List of drones discovered automatically.
  final List<Map<String, String>> _discoveredDrones = [];

  /// Timer to simulate drone discovery.
  Timer? _discoveryTimer;

  @override
  void initState() {
    super.initState();
    // Simulate automatic discovery after a delay
    _discoveryTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _discoveredDrones.add({'name': 'Drone 1', 'ip': '192.168.1.50'});
      });
    });
  }

  @override
  void dispose() {
    // Clean up controllers and timers
    _discoveryTimer?.cancel();
    _droneNameController.dispose();
    _ipController.dispose();
    _droneListController.dispose();
    super.dispose();
  }

  /// Handles the connect action when the form is submitted or a discovered
  /// drone is selected.
  Future<void> _connect() async {
    if (_formKey.currentState?.validate() == true) {
      // Stop discovery and hide keyboard
      _discoveryTimer?.cancel();
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');

      setState(() {
        _isConnecting = true;
        _isConfirmed = false;
      });

      try {
        // Register then connect to the drone via AuthService
        await AuthService.instance.registerDrone(
          _droneNameController.text,
          _ipController.text,
        );
        await AuthService.instance.connectDrone(_droneNameController.text);
        setState(() => _isConfirmed = true);
        // Show confirmation before navigating
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/takeoff');
      } catch (e) {
        // Show failure message and reset state
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  /// Auto-fills the form fields when a discovered drone is tapped.
  void _selectDiscoveredDrone(Map<String, String> drone) {
    setState(() {
      _droneNameController.text = drone['name'] ?? '';
      _ipController.text = drone['ip'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final int count = _discoveredDrones.length;
    const double tileHeight = 72.0;
    final bool isScrollable = count > 3;
    final double containerHeight =
        count > 0 ? (isScrollable ? 3 * tileHeight : count * tileHeight) : 0;

    return WillPopScope(
      // Custom back-button handling
      onWillPop:
          () => NavigationHelper.onBackPressed(
            context,
            NavScreen.newDroneConnection,
          ),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.newDroneConnection,
          ),
          title: const GradientText(
            text: 'New Drone Connection',
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
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Connection form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _droneNameController,
                            decoration: InputDecoration(
                              labelText: 'Drone Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.label),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a drone name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _ipController,
                            decoration: InputDecoration(
                              labelText: 'IP Address',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.router),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the IP address';
                              }
                              final ipRegex = RegExp(
                                r'^(\d{1,3}\.){3}\d{1,3}$',
                              );
                              if (!ipRegex.hasMatch(value.trim())) {
                                return 'Enter a valid IP address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Automatically discovered drones list
                    const Text(
                      'Automatically Discovered Drones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: containerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 5),
                        ],
                      ),
                      child:
                          count > 0
                              // Scrollable list if many drones
                              ? RawScrollbar(
                                controller: _droneListController,
                                thumbVisibility: isScrollable,
                                thickness: 8,
                                radius: const Radius.circular(8),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: ListView.builder(
                                  controller: _droneListController,
                                  physics:
                                      isScrollable
                                          ? const AlwaysScrollableScrollPhysics()
                                          : const NeverScrollableScrollPhysics(),
                                  itemCount: _discoveredDrones.length,
                                  itemBuilder: (context, index) {
                                    final drone = _discoveredDrones[index];
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.airplanemode_active,
                                        color: Colors.blueAccent,
                                      ),
                                      title: Text(drone['name']!),
                                      subtitle: Text(drone['ip']!),
                                      onTap:
                                          () => _selectDiscoveredDrone(drone),
                                    );
                                  },
                                ),
                              )
                              // Placeholder when none found
                              : const Center(
                                child: Text('No drones discovered yet'),
                              ),
                    ),
                    const SizedBox(height: 15),
                    // Discovery indicator
                    Row(
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Searching for drones...'),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Connect button
                    ElevatedButton(
                      onPressed: _connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 22),
                      ),
                      child: const Text('Connect'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Overlay loading/confirmation during connection
            if (_isConnecting)
              Positioned.fill(
                child: LoadingWidget(
                  text: 'Connecting...',
                  isConfirmed: _isConfirmed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
