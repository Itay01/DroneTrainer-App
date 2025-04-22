// test_auth_init.dart

import 'dart:io';

import 'package:flutter/widgets.dart';
import '../auth_service.dart';

Future<void> main() async {
  // Required before you use any Flutter plugin (flutter_secure_storage, etc).
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final ok = await AuthService.instance.init();
    print('✅ AuthService.init() returned: $ok');
  } catch (e, st) {
    print('❌ AuthService.init() threw an exception: $e');
    print(st);
  }
  // Optionally exit the process (if running in a true Dart VM):
  exit(0);
}
