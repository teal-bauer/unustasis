import 'package:flutter/material.dart';

class ScooterActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color? iconColor;

  const ScooterActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    Color mainColor = iconColor ??
        (onPressed == null
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.onSurface);
            
    return Column(
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(24),
            side: BorderSide(
              color: mainColor,
            ),
          ),
          onPressed: onPressed,
          child: Icon(
            icon,
            color: mainColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: mainColor),
        ),
      ],
    );
  }
}