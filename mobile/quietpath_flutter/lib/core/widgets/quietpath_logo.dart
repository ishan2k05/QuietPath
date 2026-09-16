import 'package:flutter/material.dart';

/// The official QuietPath brand logo widget utilizing the custom stylized "Q" symbol.
class QuietPathLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;

  const QuietPathLogo({
    super.key,
    this.size = 24.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final pixelSize = (size * MediaQuery.of(context).devicePixelRatio).round().clamp(32, 256);
    return Image.asset(
      'assets/images/main_logo.png',
      width: size,
      height: size,
      fit: fit,
      cacheWidth: pixelSize,
      cacheHeight: pixelSize,
      errorBuilder: (context, error, stackTrace) {
        // Graceful fallback if asset loading encounters an issue
        return Icon(
          Icons.eco_rounded,
          size: size,
          color: const Color(0xFF2D5A27),
        );
      },
    );
  }
}
