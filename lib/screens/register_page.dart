import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../navigation_helper.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers.
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Obscure toggles.
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Real-time feedback variables.
  String? _fullNameError;
  String? _emailError;
  String? _confirmPasswordError;

  // List of popular email domains.
  final List<String> popularDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
  ];

  // Password rule booleans.
  bool _isPassword8 = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  @override
  void initState() {
    super.initState();
    _fullNameController.addListener(_validateFullName);
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  void _validateFullName() {
    String name = _fullNameController.text.trim();
    String? error;
    if (name.isEmpty) {
      error = 'Please enter your full name';
    } else if (name.split(' ').length < 2) {
      error = 'Enter first and last name';
    }
    setState(() {
      _fullNameError = error;
    });
  }

  void _validateEmail() {
    String email = _emailController.text.trim();
    String? error;
    if (email.isEmpty) {
      error = 'Please enter your email';
    } else {
      final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        error = 'Invalid email format';
      } else {
        String domain = email.split('@').last.toLowerCase();
        if (!popularDomains.contains(domain)) {
          error = 'Use a popular email domain';
        }
      }
    }
    setState(() {
      _emailError = error;
    });
  }

  void _validatePassword() {
    String password = _passwordController.text;
    setState(() {
      _isPassword8 = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'\d'));
      _hasSymbol = password.contains(RegExp(r'[!@#\$&*~]'));
    });
  }

  void _validateConfirmPassword() {
    setState(() {
      _confirmPasswordError =
          _confirmPasswordController.text != _passwordController.text
              ? 'Passwords do not match'
              : null;
    });
  }

  // Helper widget to display password rules.
  Widget _buildPasswordRule({required bool passed, required String text}) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          color: passed ? Colors.green : Colors.red,
          size: 16,
        ),
        SizedBox(width: 8),
        Text(text, style: TextStyle(color: passed ? Colors.green : Colors.red)),
      ],
    );
  }

  Future<void> _submitRegistration() async {
    if (_formKey.currentState?.validate() == true &&
        _fullNameError == null &&
        _emailError == null &&
        _isPassword8 &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSymbol &&
        _confirmPasswordError == null) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fix the errors before registering')),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop:
          () => NavigationHelper.onBackPressed(context, NavScreen.register),
      child: Scaffold(
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(context, NavScreen.register),
          title: GradientText(
            text: "Register",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
          // no logout button on register page
        ),
        backgroundColor: Colors.grey[100],
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Full Name field.
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    errorText: _fullNameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Enter first and last name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                // Email field.
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: _emailError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                SizedBox(height: 20),
                // Password field.
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.lock),
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
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                // Confirm Password field.
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    errorText: _confirmPasswordError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed:
                          () => setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          }),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10),
                // Real-time password rules.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPasswordRule(
                      passed: _isPassword8,
                      text: 'At least 8 characters',
                    ),
                    _buildPasswordRule(
                      passed: _hasUppercase,
                      text: 'At least 1 uppercase letter',
                    ),
                    _buildPasswordRule(
                      passed: _hasLowercase,
                      text: 'At least 1 lowercase letter',
                    ),
                    _buildPasswordRule(
                      passed: _hasNumber,
                      text: 'At least 1 number',
                    ),
                    _buildPasswordRule(
                      passed: _hasSymbol,
                      text: 'At least 1 symbol (!@#\$&*~)',
                    ),
                  ],
                ),
                SizedBox(height: 30),
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
                  onPressed: _submitRegistration,
                  child: Text("Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
