import 'package:flutter/material.dart';

/// A customizable full-screen loading overlay widget.
///
/// Shows a semi-transparent black backdrop with:
///  • A loading spinner if [isConfirmed] is false,
///  • A green check icon if [isConfirmed] is true,
///  • A message text below the indicator.
class LoadingWidget extends StatelessWidget {
  /// Message to display below the indicator/icon.
  final String text;

  /// Whether to show the confirmation icon instead of spinner.
  final bool isConfirmed;

  /// Creates a loading overlay with optional confirmation state.
  ///
  /// The [text] is required; [isConfirmed] defaults to false.
  const LoadingWidget({
    super.key,
    required this.text,
    this.isConfirmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fill available space with a translucent backdrop
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show spinner or confirmation icon
                  if (!isConfirmed)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  else
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),

                  const SizedBox(height: 16),

                  // Display the provided message text
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
