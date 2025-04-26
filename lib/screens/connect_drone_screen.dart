import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../widgets/loading.dart';

class ConnectDroneScreen extends StatefulWidget {
  const ConnectDroneScreen({super.key});

  @override
  _ConnectDroneScreenState createState() => _ConnectDroneScreenState();
}

class _ConnectDroneScreenState extends State<ConnectDroneScreen> {
  List _droneList = [];
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _fetchDrones();
  }

  Future<void> _fetchDrones() async {
    try {
      final drones = await AuthService.instance.getDroneList();
      setState(() {
        _droneList = drones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load drones: $e')));
    }
  }

  Future<void> _connectToDrone(String drone) async {
    setState(() {
      _isConnecting = true;
      _isConfirmed = false;
    });
    try {
      await AuthService.instance.connectDrone(drone);
      setState(() => _isConfirmed = true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
                          ? const Center(child: CircularProgressIndicator())
                          : _droneList.isEmpty
                          ? const Center(
                            child: Text('No previous drones found.'),
                          )
                          : ListView.builder(
                            itemCount: _droneList.length,
                            itemBuilder: (context, index) {
                              final drone = _droneList[index];
                              return Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 3,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    drone["drone_name"],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    drone["drone_ip"],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.indigo,
                                  ),
                                  onTap:
                                      () =>
                                          _connectToDrone(drone["drone_name"]),
                                ),
                              );
                            },
                          ),
                ),
                const SizedBox(height: 10),
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

          if (_isConnecting)
            // use the LoadingWidget from the previous code snippet
            LoadingWidget(
              text: 'Connecting to drone...',
              isConfirmed: _isConfirmed,
            ),
        ],
      ),
    );
  }
}
