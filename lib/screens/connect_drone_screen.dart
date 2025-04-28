import 'package:flutter/material.dart';

// Internal service and widgets
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../widgets/loading.dart';
import '../navigation_helper.dart';

/// Screen for connecting to a previously registered drone or adding a new one.
class ConnectDroneScreen extends StatefulWidget {
  /// Creates the ConnectDrone screen widget.
  const ConnectDroneScreen({super.key});

  @override
  _ConnectDroneScreenState createState() => _ConnectDroneScreenState();
}

class _ConnectDroneScreenState extends State<ConnectDroneScreen> {
  /// List of drones fetched from backend.
  List _droneList = [];

  /// Loading state while fetching the drone list.
  bool _isLoading = true;

  /// Indicates an ongoing connection attempt.
  bool _isConnecting = false;

  /// Indicates successful connection confirmation.
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _fetchDrones(); // Fetch saved drone connections on init
  }

  /// Fetches the list of previously connected drones.
  Future<void> _fetchDrones() async {
    try {
      final drones = await AuthService.instance.getDroneList();
      setState(() {
        _droneList = drones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Show error snackbar on failure
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load drones: $e')));
    }
  }

  /// Attempts to connect to the selected drone by name.
  Future<void> _connectToDrone(String droneName) async {
    setState(() {
      _isConnecting = true;
      _isConfirmed = false;
    });
    try {
      await AuthService.instance.connectDrone(droneName);
      setState(() => _isConfirmed = true);
      // Brief delay to show confirmation before navigating
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacementNamed(context, '/takeoff');
    } catch (e) {
      // Show error snackbar and reset connecting state
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Handle back button with custom navigation logic
      onWillPop:
          () => NavigationHelper.onBackPressed(context, NavScreen.connectDrone),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: GradientText(
            text: 'Connect to Drone',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: const LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
          // Custom back arrow logic
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.connectDrone,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Logout and navigate to welcome
                await AuthService.instance.logout();
                Navigator.pushReplacementNamed(context, '/welcome');
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Drone icon with gradient circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
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
                    child: const Center(
                      child: Icon(
                        Icons.wifi_tethering,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select a previous connection or connect to a new drone',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.indigo),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child:
                        _isLoading
                            // Show spinner while loading
                            ? const Center(child: CircularProgressIndicator())
                            // Show message if no drones
                            : _droneList.isEmpty
                            ? const Center(
                              child: Text('No previous drones found.'),
                            )
                            // List of available drones
                            : ListView.builder(
                              itemCount: _droneList.length,
                              itemBuilder: (context, index) {
                                final drone = _droneList[index];
                                return Card(
                                  color: Colors.white,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      drone['drone_name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      drone['drone_ip'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.indigo,
                                    ),
                                    onTap:
                                        () => _connectToDrone(
                                          drone['drone_name'],
                                        ),
                                  ),
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 10),
                  // Button to initiate new drone connection
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed:
                        () => Navigator.pushReplacementNamed(
                          context,
                          '/newDroneConnection',
                        ),
                    child: const Text('Connect to New Drone'),
                  ),
                ],
              ),
            ),
            // Overlay loading/confirmation widget during connection
            if (_isConnecting)
              LoadingWidget(
                text: 'Connecting to drone...',
                isConfirmed: _isConfirmed,
              ),
          ],
        ),
      ),
    );
  }
}
