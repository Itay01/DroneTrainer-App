import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

class NewDroneConnectionScreen extends StatefulWidget {
  const NewDroneConnectionScreen({super.key});

  @override
  _NewDroneConnectionScreenState createState() =>
      _NewDroneConnectionScreenState();
}

class _NewDroneConnectionScreenState extends State<NewDroneConnectionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _droneNameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  // Scroll controller for the drone list.
  final ScrollController _droneListController = ScrollController();

  bool _isConnecting = false;
  bool _isConfirmed = false;

  // For discovered drones.
  final List<Map<String, String>> _discoveredDrones = [];
  Timer? _discoveryTimer;

  @override
  void initState() {
    super.initState();
    // Simulate discovering a new drone after 3 seconds.
    _discoveryTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _discoveredDrones.add({'name': 'Drone 1', 'ip': '192.168.1.50'});
      });
    });
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _droneNameController.dispose();
    _ipController.dispose();
    _droneListController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_formKey.currentState?.validate() == true) {
      // Stop the drone discovery process.
      _discoveryTimer?.cancel();

      // Dismiss the keyboard explicitly.
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');

      setState(() {
        _isConnecting = true;
        _isConfirmed = false;
      });

      try {
        await AuthService.instance.registerDrone(
          _droneNameController.text,
          _ipController.text,
        );
        await AuthService.instance.connectDrone(_droneNameController.text);
        setState(() {
          _isConfirmed = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/takeoff');
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  /// When a discovered drone is tapped, auto-fill the form fields.
  void _selectDiscoveredDrone(Map<String, String> drone) {
    setState(() {
      _droneNameController.text = drone['name'] ?? '';
      _ipController.text = drone['ip'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final int count = _discoveredDrones.length;
    final double tileHeight = 72.0;
    final bool isScrollable = count > 3;
    final double containerHeight =
        count > 0 ? (isScrollable ? 3 * tileHeight : count * tileHeight) : 0;

    return WillPopScope(
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
          title: GradientText(
            text: "New Drone Connection",
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
                    // Connection Details Form.
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
                              prefixIcon: Icon(Icons.label),
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
                              prefixIcon: Icon(Icons.router),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the IP address';
                              }
                              final ipRegex = RegExp(
                                r'^(\d{1,3}\.){3}\d{1,3}\$',
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
                    // Discovered Drones Section.
                    Text(
                      'Automatically Discovered Drones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Drone List Container.
                    Container(
                      height: containerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 5),
                        ],
                      ),
                      child:
                          count > 0
                              ? RawScrollbar(
                                controller: _droneListController,
                                thumbVisibility: isScrollable,
                                thickness: 8,
                                radius: Radius.circular(8),
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 12,
                                ),
                                child: ListView.builder(
                                  controller: _droneListController,
                                  shrinkWrap: true,
                                  physics:
                                      isScrollable
                                          ? const AlwaysScrollableScrollPhysics()
                                          : const NeverScrollableScrollPhysics(),
                                  itemCount: _discoveredDrones.length,
                                  itemBuilder: (context, index) {
                                    final drone = _discoveredDrones[index];
                                    return ListTile(
                                      leading: Icon(
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
                              : const Center(
                                child: Text("No drones discovered yet"),
                              ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        const Text("Searching for drones..."),
                      ],
                    ),
                    const SizedBox(height: 30),
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
                      child: const Text("Connect"),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (_isConnecting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        !_isConfirmed
                            ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                            : const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 80,
                            ),
                        const SizedBox(height: 16),
                        Text(
                          !_isConfirmed ? "Connecting" : "Connected",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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
}
