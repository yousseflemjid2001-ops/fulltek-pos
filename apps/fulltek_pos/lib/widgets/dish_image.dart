import 'package:flutter/material.dart';

/// Displays a real dish photograph (bundled asset or network URL) with graceful fallback.
class DishImage extends StatelessWidget {
  final String imageUrl;
  final String fallbackIcon;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final double fallbackFontSize;

  const DishImage({
    super.key,
    required this.imageUrl,
    this.fallbackIcon = '🍽',
    this.borderRadius = BorderRadius.zero,
    this.backgroundColor,
    this.fallbackFontSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    Widget fallback() => Container(
          color: backgroundColor ?? const Color(0xFF1E293B),
          alignment: Alignment.center,
          child: Text(
            fallbackIcon.isEmpty ? '🍽' : fallbackIcon,
            style: TextStyle(fontSize: fallbackFontSize),
          ),
        );

    Widget child;
    if (trimmed.isEmpty) {
      child = fallback();
    } else if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      child = Image.network(
        trimmed,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      child = Image.asset(
        trimmed,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}
