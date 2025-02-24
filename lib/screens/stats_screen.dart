import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';
import 'package:maps_launcher/maps_launcher.dart';

import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import '../stats/battery_section.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final activeScooter = manager.activeScooter;
    
    // If no active scooter, show a message
    if (activeScooter == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(FlutterI18n.translate(context, "stats_title")),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.electric_scooter_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                FlutterI18n.translate(context, "stats_no_scooter"),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                FlutterI18n.translate(context, "stats_no_scooter_desc"),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Calculate if data is old (more than 1 hour)
    final dataIsOld = activeScooter.lastConnection
        .isBefore(DateTime.now().subtract(const Duration(hours: 1)));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "stats_title")),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: FlutterI18n.translate(context, "stats_tab_scooter")),
            Tab(text: FlutterI18n.translate(context, "stats_tab_battery")),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Scooter info tab
          _buildScooterInfoTab(context, activeScooter),
          
          // Battery info tab
          BatterySection(dataIsOld: dataIsOld),
        ],
      ),
    );
  }
  
  Widget _buildScooterInfoTab(BuildContext context, Scooter scooter) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scooter image
        Center(
          child: Image.asset(
            "images/scooter/side_${scooter.color}.webp",
            height: 160,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Scooter name and ID
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FlutterI18n.translate(context, "stats_scooter_info"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(FlutterI18n.translate(context, "stats_name")),
                  subtitle: Text(scooter.name),
                ),
                const Divider(),
                ListTile(
                  title: Text(FlutterI18n.translate(context, "stats_id")),
                  subtitle: Text(scooter.id),
                ),
                const Divider(),
                ListTile(
                  title: Text(FlutterI18n.translate(context, "stats_state")),
                  subtitle: Text(
                    scooter.state != null 
                      ? FlutterI18n.translate(context, "state_name_${scooter.state.toString().split('.').last}")
                      : FlutterI18n.translate(context, "state_name_disconnected"),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Connection info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FlutterI18n.translate(context, "stats_connection_info"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    scooter.bleConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: scooter.bleConnected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(FlutterI18n.translate(context, "stats_ble_status")),
                  subtitle: Text(
                    scooter.bleConnected
                      ? FlutterI18n.translate(context, "stats_ble_connected")
                      : FlutterI18n.translate(context, "stats_ble_disconnected"),
                  ),
                ),
                if (scooter.cloudScooterId != null)
                  ListTile(
                    leading: Icon(
                      scooter.cloudConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: scooter.cloudConnected ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(FlutterI18n.translate(context, "stats_cloud_status")),
                    subtitle: Text(
                      scooter.cloudConnected
                        ? FlutterI18n.translate(context, "stats_cloud_connected")
                        : FlutterI18n.translate(context, "stats_cloud_disconnected"),
                    ),
                  ),
                ListTile(
                  title: Text(FlutterI18n.translate(context, "stats_last_ping_title")),
                  subtitle: Text(
                    scooter.lastConnection.toString().substring(0, 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Location info
        if (scooter.lastLocation != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FlutterI18n.translate(context, "stats_location"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(FlutterI18n.translate(context, "stats_last_seen_near")),
                    subtitle: Text(
                      "${scooter.lastLocation!.latitude}, ${scooter.lastLocation!.longitude}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined),
                      onPressed: () {
                        MapsLauncher.launchCoordinates(
                          scooter.lastLocation!.latitude,
                          scooter.lastLocation!.longitude,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
