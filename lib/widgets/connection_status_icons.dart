import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../models/scooter_manager.dart';

class ConnectionStatusIcons extends StatelessWidget {
  const ConnectionStatusIcons({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final activeScooter = manager.activeScooter;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BLE connection status
        if (activeScooter != null)
          _buildConnectionIcon(
            context: context,
            connected: activeScooter.bleConnected,
            icon: activeScooter.bleConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            tooltip: activeScooter.bleConnected
                ? FlutterI18n.translate(context, 'connected_bluetooth')
                : FlutterI18n.translate(context, 'disconnected_bluetooth'),
            onTap: activeScooter.bleConnected
                ? null
                : () => manager.attemptToConnectToActiveScooter(),
          ),
        
        const SizedBox(width: 16),
        
        // Cloud connection status
        if (activeScooter != null && activeScooter.cloudScooterId != null)
          _buildConnectionIcon(
            context: context,
            connected: activeScooter.cloudConnected,
            icon: activeScooter.cloudConnected ? Icons.cloud_done : Icons.cloud_outlined,
            tooltip: activeScooter.cloudConnected
                ? FlutterI18n.translate(context, 'connected_cloud')
                : FlutterI18n.translate(context, 'disconnected_cloud'),
            onTap: activeScooter.cloudConnected
                ? null
                : () => manager.refreshCloudData(),
          ),
      ],
    );
  }
  
  Widget _buildConnectionIcon({
    required BuildContext context,
    required bool connected,
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: connected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: connected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
