import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';

class NewDroneConnectionScreen extends StatefulWidget {
  const NewDroneConnectionScreen({Key? key}) : super(key: key);

  @override
  _NewDroneConnectionScreenState createState() =>
      _NewDroneConnectionScreenState();
}

class _NewDroneConnectionScreenState extends State<NewDroneConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _droneNameController = TextEditingController();
  final _ipController = TextEditingController();

  bool _isProcessing = false;
  bool _isConfirmed = false;

  Future<void> _registerDrone() async {
    if (!_formKey.currentState!.validate()) return;

    // Hide keyboard
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() {
      _isProcessing = true;
      _isConfirmed = false;
    });

    final name = _droneNameController.text.trim();
    final ip = _ipController.text.trim();

    try {
      // <-- call your new AuthService method
      await AuthService.instance.registerDrone(name, ip);

      // on success show checkmark briefly
      setState(() => _isConfirmed = true);
      await Future.delayed(const Duration(seconds: 1));

      // navigate to takeoff
      Navigator.pushReplacementNamed(context, '/connectDrone');
    } catch (e) {
      // failure: reset and show error
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to register drone: $e')));
    }
  }

  @override
  void dispose() {
    _droneNameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          text: "New Drone Connection",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          gradient: const LinearGradient(
            colors: [Colors.indigo, Colors.blueAccent],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Colors.grey[100],
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Drone Name
                  TextFormField(
                    controller: _droneNameController,
                    decoration: InputDecoration(
                      labelText: 'Drone Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.label),
                    ),
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Enter a name'
                                : null,
                  ),
                  const SizedBox(height: 20),

                  // IP Address
                  TextFormField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'IP Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.router),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter the IP address';
                      final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                      if (!ipRegex.hasMatch(v.trim()))
                        return 'Invalid IP address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  // Discovered Drones Section
                  Text(
                    'Automatically Discovering Drones...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[900],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // For now, empty container: user will see spinner below
                  Container(height: 0),
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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

                  const SizedBox(height: 40),

                  // Register button
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _registerDrone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text("Register Drone"),
                  ),

                  const SizedBox(height: 20), // Spacer
                ],
              ),
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child:
                      _isConfirmed
                          ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 80,
                          )
                          : const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
