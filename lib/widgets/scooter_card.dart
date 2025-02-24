import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../domain/scooter_state.dart';
import '../models/scooter.dart';
import '../models/scooter_manager.dart';

class ScooterCard extends StatelessWidget {
  final Scooter scooter;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onSettings;
  final bool showConnect;

  const ScooterCard({
    super.key,
    required this.scooter,
    this.isActive = false,
    this.onTap,
    this.onSettings,
    this.showConnect = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      elevation: isActive ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with scooter name and source indicators
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scooter.name,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _buildConnectionIcons(context),
                  if (onSettings != null)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      iconSize: 20,
                      onPressed: onSettings,
                      tooltip: FlutterI18n.translate(context, 'scooter_settings'),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Scooter details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scooter image
                  SizedBox(
                    width: 100,
                    child: Image.asset(
                      "images/scooter/side_${scooter.color}.webp",
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Scooter details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Battery info
                        if (scooter.primarySOC != null) _buildBatteryInfo(context),

                        const SizedBox(height: 8),

                        // Connection status
                        _buildStatusInfo(context),

                        const SizedBox(height: 8),

                        // Connect button if not active
                        if (showConnect && !isActive) _buildConnectButton(context),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIcons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BLE connection icon
        if (scooter.bleConnected)
          Tooltip(
            message: FlutterI18n.translate(context, 'connected_bluetooth'),
            child: Icon(
              Icons.bluetooth_connected,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        else if (scooter.sourceType == ScooterSourceType.ble || scooter.sourceType == ScooterSourceType.both)
          Tooltip(
            message: FlutterI18n.translate(context, 'disconnected_bluetooth'),
            child: Icon(
              Icons.bluetooth,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),

        const SizedBox(width: 8),

        // Cloud connection icon
        if (scooter.cloudConnected)
          Tooltip(
            message: FlutterI18n.translate(context, 'connected_cloud'),
            child: Icon(
              Icons.cloud_done_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        else if (scooter.cloudScooterId != null)
          Tooltip(
            message: FlutterI18n.translate(context, 'disconnected_cloud'),
            child: Icon(
              Icons.cloud_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  Widget _buildBatteryInfo(BuildContext context) {
    int primarySOC = scooter.primarySOC ?? 0;
    int secondarySOC = scooter.secondarySOC ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${scooter.calculateRange()} km ${FlutterI18n.translate(context, "stats_total_range")}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: LinearProgressIndicator(
                value: primarySOC / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                color: primarySOC <= 15 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
              ),
            ),
            if (secondarySOC > 0) ...[
              const SizedBox(width: 4),
              Expanded(
                flex: 1,
                child: LinearProgressIndicator(
                  value: secondarySOC / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  color:
                      secondarySOC <= 15 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              '$primarySOC%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (secondarySOC > 0) ...[
              const Spacer(),
              Text(
                '$secondarySOC%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusInfo(BuildContext context) {
    String? statusText;

    if (scooter.bleConnected) {
      statusText = scooter.state?.name(context) ?? FlutterI18n.translate(context, 'state_name_unknown');
    } else if (scooter.lastPing != null) {
      final now = DateTime.now();
      final difference = now.difference(scooter.lastPing!);
      
      String timeAgo;
      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours}h';
      } else {
        timeAgo = '${difference.inDays}d';
      }
      
      statusText = FlutterI18n.translate(
        context,
        'stats_last_ping',
        translationParams: {
          'time': timeAgo,
        },
      );
    } else {
      statusText = FlutterI18n.translate(context, 'state_name_disconnected');
    }

    return Text(
      statusText,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.power_settings_new, size: 16),
        label: Text(FlutterI18n.translate(context, 'settings_connect')),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        onPressed: () {
          final manager = Provider.of<ScooterManager>(context, listen: false);
          manager.setActiveScooter(scooter.id);
        },
      ),
    );
  }
}
