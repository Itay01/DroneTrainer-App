import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/gradient_text.dart';

class NewDroneConnectionScreen extends StatefulWidget {
  const NewDroneConnectionScreen({Key? key}) : super(key: key);

  @override
  _NewDroneConnectionScreenState createState() => _NewDroneConnectionScreenState();
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
  int _discoveryCount = 0;
  // Increased tile height to properly fit both name and IP.
  final double _tileHeight = 72.0;

  @override
  void initState() {
    super.initState();
    // Simulate discovering a new drone every 5 seconds.
    _discoveryTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        _discoveredDrones.add({
          'name': 'Discovered Drone ${_discoveryCount + 1}',
          'ip': '192.168.1.${100 + _discoveryCount}',
        });
        _discoveryCount++;
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

  void _connect() {
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
      // Simulate a connection delay.
      Future.delayed(Duration(seconds: 3), () {
        setState(() {
          _isConfirmed = true;
        });
        // After showing confirmation, navigate to /takeoff.
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pushReplacementNamed(context, '/takeoff', arguments: {
            'droneName': _droneNameController.text.trim(),
            'ip': _ipController.text.trim(),
          });
        });
      });
    }
  }

  /// When a discovered drone is tapped, auto-fill the form fields.
  void _selectDiscoveredDrone(Map<String, String> drone) {
    setState(() {
      _droneNameController.text = drone['name'] ?? '';
      _ipController.text = drone['ip'] ?? '';
    });
    // Discovery continues even after a drone is selected.
  }

  @override
  Widget build(BuildContext context) {
    final int count = _discoveredDrones.length;
    // If there are more than 3 items, the container remains 3 tile-heights tall.
    final bool isScrollable = count > 3;
    final double containerHeight =
        count > 0 ? (isScrollable ? 3 * _tileHeight : count * _tileHeight) : 0;

    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          text: "New Drone Connection",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          gradient: LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Colors.grey[100],
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main content.
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
                        SizedBox(height: 20),
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
                            final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                            if (!ipRegex.hasMatch(value.trim())) {
                              return 'Enter a valid IP address';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  // Discovered Drones Section.
                  Text(
                    'Automatically Discovered Drones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[900],
                    ),
                  ),
                  SizedBox(height: 10),
                  // Drone List Container.
                  Container(
                    height: containerHeight,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                    ),
                    child: count > 0
                        ? RawScrollbar(
                            controller: _droneListController,
                            thumbVisibility: isScrollable,
                            thickness: 8,
                            radius: Radius.circular(8),
                            // This padding insets the thumb from the top and bottom only.
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            child: ListView.builder(
                              controller: _droneListController,
                              shrinkWrap: true,
                              primary: false,
                              physics: isScrollable
                                  ? AlwaysScrollableScrollPhysics()
                                  : NeverScrollableScrollPhysics(),
                              itemCount: _discoveredDrones.length,
                              itemBuilder: (context, index) {
                                final drone = _discoveredDrones[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.airplanemode_active, color: Colors.blueAccent),
                                  title: Text(drone['name']!),
                                  subtitle: Text(drone['ip']!),
                                  onTap: () => _selectDiscoveredDrone(drone),
                                );
                              },
                            ),
                          )
                        : Center(child: Text("No drones discovered yet")),
                  ),
                  // Spinner row below the list.
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text("Searching for drones..."),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  // Connect Button for manual connection.
                  ElevatedButton(
                    onPressed: _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: TextStyle(fontSize: 22),
                    ),
                    child: Text("Connect"),
                  ),
                  // Extra spacing at the bottom.
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Overlay for connection status.
          if (_isConnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      !_isConfirmed
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : Icon(Icons.check_circle, color: Colors.green, size: 80),
                      SizedBox(height: 16),
                      Text(
                        !_isConfirmed ? "Connecting" : "Connected",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
