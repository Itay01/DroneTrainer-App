import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/auth_service.dart';

/// Screens that require custom back-button handling.
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

/// Helper for unified back navigation (hardware & AppBar arrow).
class NavigationHelper {
  /// Handles back press based on current [page].
  /// Returns true if the framework should perform a default pop.
  static Future<bool> onBackPressed(BuildContext ctx, NavScreen page) async {
    switch (page) {
      // ─── Exit the app on these screens ─────────────────────────
      case NavScreen.splash:
      case NavScreen.welcome:
      case NavScreen.connectDrone:
        // Confirm before exiting
        if (await _confirm(ctx, 'Exit the app?')) {
          SystemNavigator.pop();
        }
        return false;

      // ─── Default pop back to WelcomePage ───────────────────────
      case NavScreen.register:
      case NavScreen.login:
        return Future.value(true);

      // ─── Replace with ConnectDrone screen ──────────────────────
      case NavScreen.newDroneConnection:
        Navigator.pushReplacementNamed(ctx, '/connectDrone');
        return false;

      // ─── End session then navigate home ────────────────────────
      case NavScreen.takeoff:
        // Ensure any active session is ended
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

      // ─── Land, end session, then navigate home ─────────────────
      case NavScreen.trackSelection:
        if (await _confirm(ctx, 'Land the drone, end session and go back?')) {
          await AuthService.instance.land();
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
        }
        return false;

      // ─── Pop back to TrackSelection ────────────────────────────
      case NavScreen.speedSelection:
        Navigator.pushReplacementNamed(ctx, '/trackSelection');
        return false;

      // ─── Stop flight, land, disconnect, then home ──────────────
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

  /// Builds a back arrow icon wired to [onBackPressed].
  static Widget buildBackArrow(BuildContext ctx, NavScreen page) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () async {
        bool shouldPop = await onBackPressed(ctx, page);
        if (shouldPop) Navigator.of(ctx).pop();
      },
    );
  }

  /// Shows a confirmation dialog with [msg].
  /// Returns true if user selects 'Yes'.
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
    // Default to false if dialog dismissed
    return result ?? false;
  }
}
