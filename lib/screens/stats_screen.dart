import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';

import '../domain/scooter_state.dart';
import '../geo_helper.dart';
import '../models/scooter.dart';
import '../models/scooter_manager.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final log = Logger('StatsScreen');

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final activeScooter = manager.activeScooter;

    if (activeScooter == null) {
      return _buildNoScooterScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, 'stats_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Battery Section
          _buildBatterySection(context, activeScooter),

          const SizedBox(height: 16),

          // Scooter Details Section
          _buildScooterDetailsSection(context, activeScooter),

          const SizedBox(height: 16),

          // Location Section
          if (activeScooter.lastLocation != null)
            _buildLocationSection(context, activeScooter),
        ],
      ),
    );
  }

  Widget _buildNoScooterScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, 'stats_title')),
      ),
      body: Center(
        child: Text(
          FlutterI18n.translate(context, 'stats_no_name'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }

  Widget _buildBatterySection(BuildContext context, Scooter scooter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, 'stats_title_battery'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Total Range
            Text(
              '${scooter.calculateRange()} km ${FlutterI18n.translate(context, "stats_total_range")}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              FlutterI18n.translate(
                context, 
                "stats_range_until_throttled", 
                translationParams: {
                  "range": "${scooter.calculateNonThrottledRange()}"
                }
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 16),

            // Battery Details
            if (scooter.primarySOC != null)
              _buildBatteryDetailRow(
                context, 
                FlutterI18n.translate(context, 'stats_primary_name'), 
                scooter.primarySOC!, 
                scooter.primaryCycles
              ),

            if (scooter.secondarySOC != null && scooter.secondarySOC! > 0)
              _buildBatteryDetailRow(
                context, 
                FlutterI18n.translate(context, 'stats_secondary_name'), 
                scooter.secondarySOC!, 
                scooter.secondaryCycles
              ),

            if (scooter.cbbSOC != null)
              _buildInternalBatteryRow(
                context, 
                FlutterI18n.translate(context, 'stats_cbb_name'), 
                scooter.cbbSOC!,
                charging: scooter.cbbCharging
              ),

            if (scooter.auxSOC != null)
              _buildInternalBatteryRow(
                context, 
                FlutterI18n.translate(context, 'stats_aux_name'), 
                scooter.auxSOC!
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryDetailRow(BuildContext context, String label, int soc, int? cycles) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: soc / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              color: soc <= 15 
                  ? Theme.of(context).colorScheme.error 
                  : Theme.of(context).colorScheme.primary,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '$soc%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: soc <= 15 
                      ? Theme.of(context).colorScheme.error 
                      : null,
                ),
              ),
            ),
          ),
          if (cycles != null) ...[
            const SizedBox(width: 8),
            Text(
              FlutterI18n.translate(
                context, 
                'stats_cycles', 
                translationParams: {'cycles': cycles.toString()}
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInternalBatteryRow(
    BuildContext context, 
    String label, 
    int soc, 
    {bool? charging}
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '$soc%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (charging != null) ...[
            const SizedBox(width: 8),
            Icon(
              charging ? Icons.battery_charging_full : Icons.battery_std,
              size: 16,
              color: charging 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScooterDetailsSection(BuildContext context, Scooter scooter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, 'stats_title_scooter'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Scooter State
            _buildDetailRow(
              context,
              FlutterI18n.translate(context, 'stats_state'),
              scooter.state?.name(context) ?? 
                FlutterI18n.translate(context, 'stats_unknown')
            ),

            // Connection Status
            _buildDetailRow(
              context,
              'BLE',
              scooter.bleConnected 
                ? FlutterI18n.translate(context, 'ble_connected')
                : FlutterI18n.translate(context, 'ble_disconnected')
            ),

            if (scooter.cloudScooterId != null)
              _buildDetailRow(
                context,
                FlutterI18n.translate(context, 'cloud_scooter_linked'),
                scooter.cloudConnected 
                  ? FlutterI18n.translate(context, 'cloud_connected')
                  : FlutterI18n.translate(context, 'cloud_disconnected')
              ),

            // Scooter ID
            _buildDetailRow(
              context,
              FlutterI18n.translate(context, 'stats_scooter_id'),
              scooter.id
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, Scooter scooter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, 'stats_location'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Last Known Location
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(
                FlutterI18n.translate(context, 'stats_last_seen_near'),
              ),
              subtitle: FutureBuilder<String?>(
                future: GeoHelper.getAddress(scooter.lastLocation, context),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 
                    '${scooter.lastLocation!.latitude}, ${scooter.lastLocation!.longitude}'
                  );
                },
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                MapsLauncher.launchCoordinates(
                  scooter.lastLocation!.latitude,
                  scooter.lastLocation!.longitude,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}