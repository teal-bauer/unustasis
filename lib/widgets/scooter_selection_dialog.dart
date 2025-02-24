import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import 'scooter_card.dart';
import '../screens/add_scooter_screen.dart';
import '../screens/scooter_settings_screen.dart';

class ScooterSelectionDialog extends StatelessWidget {
  const ScooterSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final activeScooterId = manager.activeScooterId;
    final scooters = manager.scooters.values.toList();

    // Sort scooters: active first, then by most recently connected
    scooters.sort((a, b) {
      if (a.id == activeScooterId) return -1;
      if (b.id == activeScooterId) return 1;
      return b.lastConnection.compareTo(a.lastConnection);
    });

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Text(
                    FlutterI18n.translate(context, 'select_scooter'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scooter list
            if (scooters.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    FlutterI18n.translate(context, 'no_scooters_added'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final scooter in scooters)
                        ScooterCard(
                          scooter: scooter,
                          isActive: scooter.id == activeScooterId,
                          onTap: () {
                            manager.setActiveScooter(scooter.id);
                            Navigator.of(context).pop();
                          },
                          onSettings: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ScooterSettingsScreen(scooter: scooter),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

            // Add scooter button
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(FlutterI18n.translate(context, 'add_scooter')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddScooterScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
