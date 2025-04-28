import 'package:flutter/material.dart';

// Internal services and widgets
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

/// Registration screen with live validation and strong password rules.
///
/// Lets the user enter full name, email, password, and confirm password,
/// validates inputs in real-time, and registers via AuthService.
class RegisterPage extends StatefulWidget {
  /// Creates the RegisterPage widget.
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  /// Key for form validation.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ─── Text controllers for form fields ─────────────────────────────────
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ─── Toggles for password visibility ──────────────────────────────────
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ─── Error messages for live validation ──────────────────────────────
  String? _fullNameError;
  String? _emailError;
  String? _confirmPasswordError;

  // Popular email domains for quick validation
  final List<String> popularDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
  ];

  // ─── Password rule trackers ──────────────────────────────────────────
  bool _isPassword8 = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  @override
  void initState() {
    super.initState();
    // Attach listeners for live field validation
    _fullNameController.addListener(_validateFullName);
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  /// Validates full name: non-empty and contains at least two words.
  void _validateFullName() {
    final name = _fullNameController.text.trim();
    String? error;
    if (name.isEmpty) {
      error = 'Please enter your full name';
    } else if (!name.contains(' ')) {
      error = 'Enter first and last name';
    }
    setState(() => _fullNameError = error);
  }

  /// Validates email format and domain popularity.
  void _validateEmail() {
    final email = _emailController.text.trim();
    String? error;
    if (email.isEmpty) {
      error = 'Please enter your email';
    } else {
      final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        error = 'Invalid email format';
      } else {
        final domain = email.split('@').last.toLowerCase();
        if (!popularDomains.contains(domain)) {
          error = 'Use a popular email domain';
        }
      }
    }
    setState(() => _emailError = error);
  }

  /// Updates password rule trackers based on current input.
  void _validatePassword() {
    final pw = _passwordController.text;
    setState(() {
      _isPassword8 = pw.length >= 8;
      _hasUppercase = pw.contains(RegExp(r'[A-Z]'));
      _hasLowercase = pw.contains(RegExp(r'[a-z]'));
      _hasNumber = pw.contains(RegExp(r'\d'));
      _hasSymbol = pw.contains(RegExp(r'[!@#\$&*~]'));
    });
  }

  /// Ensures confirm password matches the main password.
  void _validateConfirmPassword() {
    setState(() {
      _confirmPasswordError =
          _confirmPasswordController.text != _passwordController.text
              ? 'Passwords do not match'
              : null;
    });
  }

  @override
  void dispose() {
    // Clean up controllers
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Builds a row indicating one password rule's pass/fail state.
  Widget _buildPasswordRule({required bool passed, required String text}) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          color: passed ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: passed ? Colors.green : Colors.red)),
      ],
    );
  }

  /// Attempts registration if all validations pass; shows feedback.
  Future<void> _submitRegistration() async {
    final formValid = _formKey.currentState?.validate() == true;
    final pwValid =
        _isPassword8 &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSymbol;
    final allValid =
        formValid &&
        _fullNameError == null &&
        _emailError == null &&
        pwValid &&
        _confirmPasswordError == null;

    if (!allValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors before registering'),
        ),
      );
      return;
    }

    try {
      await AuthService.instance.register(
        _fullNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/connectDrone');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop:
          () => NavigationHelper.onBackPressed(context, NavScreen.register),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(context, NavScreen.register),
          title: const GradientText(
            text: 'Register',
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full Name field with error display
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    errorText: _fullNameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter your full name';
                    if (!v.trim().contains(' '))
                      return 'Enter first and last name';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Email field with live error
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: _emailError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                // Password input with toggle
                TextFormField(
                  controller: _passwordController,
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
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please enter a password'
                              : null,
                ),
                const SizedBox(height: 20),
                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    errorText: _confirmPasswordError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                          ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please confirm your password';
                    if (v != _passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                // Live password rule feedback
                _buildPasswordRule(
                  passed: _isPassword8,
                  text: 'At least 8 characters',
                ),
                _buildPasswordRule(
                  passed: _hasUppercase,
                  text: '1 uppercase letter',
                ),
                _buildPasswordRule(
                  passed: _hasLowercase,
                  text: '1 lowercase letter',
                ),
                _buildPasswordRule(passed: _hasNumber, text: '1 number'),
                _buildPasswordRule(
                  passed: _hasSymbol,
                  text: '1 symbol (!@#\$&*~)',
                ),
                const SizedBox(height: 30),
                // Register button
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
                  onPressed: _submitRegistration,
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
