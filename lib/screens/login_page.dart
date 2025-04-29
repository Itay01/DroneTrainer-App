import 'package:flutter/material.dart';

// Internal helpers and widgets
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

/// Login screen with email & password fields.
///
/// Validates input, performs authentication via AuthService,
/// and navigates to the drone connection screen on success.
class LoginPage extends StatefulWidget {
  /// Creates the LoginPage widget.
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Key for form validation.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controller for email input field.
  final TextEditingController _emailCtrl = TextEditingController();

  /// Controller for password input field.
  final TextEditingController _pwCtrl = TextEditingController();

  /// Whether the password text is obscured.
  bool _obscurePassword = true;

  // --- New state for lockout logic ---
  int _failedAttempts = 0;
  DateTime? _blockEndTime;

  /// Checks if we are currently in a block period.
  bool get _isBlocked {
    if (_blockEndTime == null) return false;
    return DateTime.now().isBefore(_blockEndTime!);
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  /// Validates form and attempts login via AuthService.
  Future<void> _submitLogin() async {
    final now = DateTime.now();

    // 1) If blocked, show remaining time and bail out
    if (_isBlocked) {
      final remaining = _blockEndTime!.difference(now);
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many failed attempts. '
            'Please try again in '
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')} minutes.',
          ),
        ),
      );
      return;
    }

    // 2) If the block expired, reset counters
    if (_blockEndTime != null && now.isAfter(_blockEndTime!)) {
      setState(() {
        _blockEndTime = null;
        _failedAttempts = 0;
      });
    }

    // 3) Validate inputs
    if (_formKey.currentState?.validate() != true) return;
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;

    try {
      // Attempt login
      await AuthService.instance.login(email, pw);

      // On success, reset failures and navigate
      if (!mounted) return;
      setState(() {
        _failedAttempts = 0;
      });
      Navigator.pushReplacementNamed(context, '/connectDrone');
    } catch (e) {
      // On failure, bump the counter
      setState(() {
        _failedAttempts++;
      });

      // If that was the 5th failure, start a 2-minute block
      if (_failedAttempts >= 5) {
        setState(() {
          _blockEndTime = DateTime.now().add(const Duration(minutes: 2));
        });
        // Schedule automatic reset after 2 minutes
        Future.delayed(const Duration(minutes: 2), () {
          if (mounted) {
            setState(() {
              _blockEndTime = null;
              _failedAttempts = 0;
            });
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Too many failed attempts. You are blocked for 2 minutes.',
            ),
          ),
        );
      } else {
        // Otherwise just show the error
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Handle hardware back button with custom logic
      onWillPop: () => NavigationHelper.onBackPressed(context, NavScreen.login),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          // Back arrow navigates back to Welcome
          leading: NavigationHelper.buildBackArrow(context, NavScreen.login),
          // Title with gradient text
          title: const GradientText(
            text: 'Login',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Email field...
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(
                      r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Password field...
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                // Login button, disabled when blocked
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: _isBlocked ? null : _submitLogin,
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
