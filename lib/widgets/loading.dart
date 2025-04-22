import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String text;
  final bool isConfirmed;

  const LoadingWidget({Key? key, required this.text, this.isConfirmed = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // now this Positioned only belongs to this inner Stack,
        // not the parent one.
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
