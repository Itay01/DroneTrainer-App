import 'package:flutter/material.dart';

/// Widget that renders text filled with an arbitrary [Gradient].
///
/// Uses a [ShaderMask] to apply the gradient across the text's bounds.
class GradientText extends StatelessWidget {
  /// The string to display.
  final String text;

  /// Base text style (font size, weight, etc.).
  /// The color provided here is replaced by the gradient shader.
  final TextStyle style;

  /// The gradient to fill the text with.
  final Gradient gradient;

  /// Creates a [GradientText] widget.
  ///
  /// All parameters are required:
  ///  • [text]: the content to render
  ///  • [style]: base styling (font, size)
  ///  • [gradient]: color gradient to apply
  const GradientText({
    super.key,
    required this.text,
    required this.style,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // Generate a shader that covers the text bounds
      shaderCallback: (bounds) {
        return gradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        );
      },
      // Render the text in white; will be masked by gradient
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
