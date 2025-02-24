import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import '../screens/scooter_settings_screen.dart';

class ScooterSelectionDialog extends StatelessWidget {
  final bool showAddButton;
  final Function()? onAddPressed;
  
  const ScooterSelectionDialog({
    super.key,
    this.showAddButton = true,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final scooters = manager.scooters.values.toList();
    
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FlutterI18n.translate(context, "scooter_selection_title"),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Scooter list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: scooters.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        FlutterI18n.translate(context, "scooter_selection_empty"),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: scooters.length,
                    itemBuilder: (context, index) {
                      final scooter = scooters[index];
                      final isActive = scooter.id == manager.activeScooterId;
                      
                      return _ScooterListItem(
                        scooter: scooter,
                        isActive: isActive,
                        onTap: () async {
                          if (!isActive) {
                            try {
                              await manager.setActiveScooter(scooter.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(FlutterI18n.translate(
                                    context, 
                                    "scooter_selection_error",
                                    translationParams: {"name": scooter.name}
                                  ))),
                                );
                              }
                            }
                          }
                        },
                        onSettingsTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ScooterSettingsScreen(
                                scooter: scooter,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
            
            // Add button
            if (showAddButton)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(FlutterI18n.translate(context, "scooter_selection_add")),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onAddPressed != null) {
                      onAddPressed!();
                    } else {
                      // Default add scooter action
                      // TODO: Navigate to add scooter screen
                    }
                  },
                ),
              ),
              
            // Cancel button
            TextButton(
              child: Text(FlutterI18n.translate(context, "scooter_selection_cancel")),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScooterListItem extends StatelessWidget {
  final Scooter scooter;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;
  
  const _ScooterListItem({
    required this.scooter,
    required this.isActive,
    required this.onTap,
    required this.onSettingsTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isActive ? 4 : 1,
      color: isActive 
        ? Theme.of(context).colorScheme.primaryContainer
        : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Scooter image
              Image.asset(
                "images/scooter/side_${scooter.color}.webp",
                height: 60,
                width: 60,
              ),
              
              const SizedBox(width: 12),
              
              // Scooter info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scooter.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isActive ? FontWeight.bold : null,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Connection status
                    Row(
                      children: [
                        Icon(
                          scooter.bleConnected 
                            ? Icons.bluetooth_connected 
                            : Icons.bluetooth_disabled,
                          size: 16,
                          color: scooter.bleConnected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        Text(
                          scooter.bleConnected
                            ? FlutterI18n.translate(context, "scooter_selection_connected")
                            : FlutterI18n.translate(context, "scooter_selection_disconnected"),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        
                        if (scooter.cloudScooterId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.cloud,
                            size: 16,
                            color: scooter.cloudConnected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ],
                      ],
                    ),
                    
                    // Battery status if available
                    if (scooter.primarySOC != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.battery_full,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${scooter.primarySOC}%",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Settings button
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: onSettingsTap,
                tooltip: FlutterI18n.translate(context, "scooter_selection_settings"),
              ),
              
              // Active indicator
              if (isActive)
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
