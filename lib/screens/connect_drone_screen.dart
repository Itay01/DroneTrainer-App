import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';

class ConnectDroneScreen extends StatefulWidget {
  const ConnectDroneScreen({Key? key}) : super(key: key);

  @override
  _ConnectDroneScreenState createState() => _ConnectDroneScreenState();
}

class _ConnectDroneScreenState extends State<ConnectDroneScreen> {
  final List<String> previousConnections = [
    'Drone A - 192.168.1.10',
    'Drone B - 192.168.1.11',
  ];

  bool _isConnecting = false;
  bool _isConfirmed = false;
  String? _targetRoute;
  Map<String, dynamic>? _arguments;

  void _handleConnection(String route, {Map<String, dynamic>? arguments}) {
    // Dismiss any open keyboard
    FocusScope.of(context).unfocus();

    // If the route is for a new drone connection, navigate immediately.
    if (route == '/newDroneConnection') {
      Navigator.pushReplacementNamed(context, route, arguments: arguments);
      return;
    }

    // For previous connections, simulate connecting with a delay.
    setState(() {
      _isConnecting = true;
      _isConfirmed = false;
      _targetRoute = route;
      _arguments = arguments;
    });

    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        _isConfirmed = true;
      });
      // After showing the confirmation icon, navigate to the next screen.
      Future.delayed(Duration(seconds: 1), () {
        if (_targetRoute != null) {
          Navigator.pushReplacementNamed(
            context,
            _targetRoute!,
            arguments: _arguments,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: GradientText(
          text: "Connect to Drone",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          gradient: LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        // add a logout button in the app bar
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
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
                // Illustration.
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
                      Icons.wifi_tethering,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Select a previous connection or connect to a new drone',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.indigo[900]),
                ),
                SizedBox(height: 30),
                // List of previous connections.
                Expanded(
                  child: ListView.builder(
                    itemCount: previousConnections.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            previousConnections[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.indigo,
                          ),
                          onTap: () {
                            // Use _handleConnection to simulate connecting before navigating.
                            _handleConnection(
                              '/takeoff',
                              arguments: {
                                'connection': previousConnections[index],
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
                // Button for new drone connection.
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                  onPressed: () {
                    _handleConnection('/newDroneConnection');
                  },
                  child: Text('Connect to New Drone'),
                ),
              ],
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 80,
                          ),
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
