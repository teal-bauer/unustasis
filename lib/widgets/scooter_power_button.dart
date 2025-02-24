import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ScooterPowerButton extends StatefulWidget {
  final VoidCallback? action;
  final IconData icon;
  final String label;

  const ScooterPowerButton({
    super.key,
    required this.action,
    required this.icon,
    required this.label,
  });

  @override
  State<ScooterPowerButton> createState() => _ScooterPowerButtonState();
}

class _ScooterPowerButtonState extends State<ScooterPowerButton> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    Color mainColor = widget.action == null
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
        : Theme.of(context).colorScheme.primary;
        
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: mainColor),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                backgroundColor: loading 
                    ? Theme.of(context).colorScheme.surface 
                    : mainColor,
              ),
              onPressed: () {
                Fluttertoast.showToast(msg: widget.label);
              },
              onLongPress: widget.action == null
                  ? null
                  : () {
                      setState(() {
                        loading = true;
                      });
                      widget.action!();
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) {
                          setState(() {
                            loading = false;
                          });
                        }
                      });
                    },
              child: loading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: mainColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      widget.icon,
                      color: Theme.of(context).colorScheme.surface,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: mainColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}