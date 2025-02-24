import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scooter_manager.dart';

class BatteryBars extends StatelessWidget {
  const BatteryBars({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final scooter = manager.activeScooter;
    
    if (scooter == null) {
      return const SizedBox.shrink();
    }
    
    final primarySOC = scooter.primarySOC;
    final secondarySOC = scooter.secondarySOC;
    final lastPing = scooter.lastPing;
    
    // Check if data is considered old (more than 5 minutes)
    bool dataIsOld = lastPing == null ||
        lastPing.difference(DateTime.now()).inMinutes.abs() > 5;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (primarySOC != null) ...[
          SizedBox(
              width: MediaQuery.of(context).size.width / 6,
              child: LinearProgressIndicator(
                backgroundColor: Colors.black26,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                value: primarySOC / 100.0,
                color: dataIsOld
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)
                    : primarySOC <= 15
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
              )),
          const SizedBox(width: 8),
          Text("$primarySOC%"),
        ],
        
        if (secondarySOC != null && secondarySOC > 0) ...[
          const VerticalDivider(),
          SizedBox(
              width: MediaQuery.of(context).size.width / 6,
              child: LinearProgressIndicator(
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                value: secondarySOC / 100.0,
                color: dataIsOld
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)
                    : secondarySOC <= 15
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
              )),
          const SizedBox(width: 8),
          Text("$secondarySOC%"),
        ],
      ],
    );
  }
}