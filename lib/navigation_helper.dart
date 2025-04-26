import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_service.dart';

/// Identify every screen that needs special back-handling
enum NavScreen {
  splash,
  welcome,
  register,
  login,
  connectDrone,
  newDroneConnection,
  takeoff,
  trackSelection,
  speedSelection,
  flightControl,
}

/// A single entry-point that handles both the hardware back button
/// and the visible AppBar arrow.
class NavigationHelper {
  /// Returns TRUE if the framework should pop the route naturally.
  static Future<bool> onBackPressed(BuildContext ctx, NavScreen page) async {
    switch (page) {
      // ─── Exit the app on these screens ───
      case NavScreen.splash:
      case NavScreen.welcome:
      case NavScreen.connectDrone:
        if (await _confirm(ctx, 'Exit the app?')) {
          SystemNavigator.pop();
        }
        return false;

      // ─── Pop back to existing WelcomePage ───
      case NavScreen.register:
      case NavScreen.login:
        // Allow default pop to return to WelcomePage
        return Future.value(true);

      // ─── Return to Connect Drone ───
      case NavScreen.newDroneConnection:
        Navigator.pushReplacementNamed(ctx, '/connectDrone');
        return false;

      // ─── End session then go to Connect ───
      case NavScreen.takeoff:
        print('Takeoff onBackPressed');
        print('Session ID: ${AuthService.instance.sessionId}');
        if (AuthService.instance.sessionId != null) {
          await AuthService.instance.endSession(
            AuthService.instance.sessionId!,
          );
        }
        Navigator.pushNamedAndRemoveUntil(
          ctx,
          '/connectDrone',
          (route) => false,
        );
        return false;

      // ─── Land & end session ───
      case NavScreen.trackSelection:
        if (await _confirm(ctx, 'Land the drone, end session and go back?')) {
          await AuthService.instance.land();
          if (AuthService.instance.sessionId != null) {
            await AuthService.instance.endSession(
              AuthService.instance.sessionId!,
            );
          }
          Future.delayed(const Duration(seconds: 1));
          print("AAAA");
          Navigator.pushNamedAndRemoveUntil(
            ctx,
            '/connectDrone',
            (route) => false,
          );
        }
        return false;

      // ─── Back to TrackSelection ───
      case NavScreen.speedSelection:
        Navigator.pushReplacementNamed(ctx, '/trackSelection');
        return false;

      // ─── Stop, land, disconnect ───
      case NavScreen.flightControl:
        if (await _confirm(
          ctx,
          'Stop & land the drone, disconnect and go back?',
        )) {
          await AuthService.instance.stopFly();
          await AuthService.instance.land();
          await AuthService.instance.disconnectDrone();
          Navigator.pushNamedAndRemoveUntil(
            ctx,
            '/connectDrone',
            (route) => false,
          );
        }
        return false;
    }
  }

  /// Builds the AppBar back arrow, wired to onBackPressed.
  static Widget buildBackArrow(BuildContext ctx, NavScreen page) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () async {
        bool shouldPop = await onBackPressed(ctx, page);
        if (shouldPop) Navigator.of(ctx).pop();
      },
    );
  }

  /// Shows a confirmation dialog, returns true if user confirms.
  static Future<bool> _confirm(BuildContext ctx, String msg) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    return result ?? false;
  }
}
