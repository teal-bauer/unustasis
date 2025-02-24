import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../models/scooter_manager.dart';

class ConnectionStatusIcons extends StatelessWidget {
  final bool showLabels;
  final bool showRefreshButtons;
  final double iconSize;
  final Color? iconColor;
  final Color? activeColor;
  
  const ConnectionStatusIcons({
    super.key,
    this.showLabels = false,
    this.showRefreshButtons = false,
    this.iconSize = 24.0,
    this.iconColor,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final activeScooter = manager.activeScooter;
    
    // If no active scooter, show disconnected state
    if (activeScooter == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(
            context,
            icon: Icons.bluetooth_disabled,
            active: false,
            label: showLabels ? FlutterI18n.translate(context, "connection_status_no_scooter") : null,
            onRefresh: null,
          ),
        ],
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BLE connection status
        _buildStatusIcon(
          context,
          icon: activeScooter.bleConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          active: activeScooter.bleConnected,
          label: showLabels 
            ? FlutterI18n.translate(
                context, 
                activeScooter.bleConnected 
                  ? "connection_status_ble_connected" 
                  : "connection_status_ble_disconnected"
              )
            : null,
          onRefresh: showRefreshButtons && !activeScooter.bleConnected
            ? () async {
                try {
                  await manager.attemptToConnectToActiveScooter();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(FlutterI18n.translate(context, "connection_status_reconnecting"))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(FlutterI18n.translate(context, "connection_status_reconnect_failed"))),
                    );
                  }
                }
              }
            : null,
        ),
        
        const SizedBox(width: 16),
        
        // Cloud connection status
        if (activeScooter.cloudScooterId != null)
          _buildStatusIcon(
            context,
            icon: activeScooter.cloudConnected ? Icons.cloud_done : Icons.cloud_off,
            active: activeScooter.cloudConnected,
            label: showLabels 
              ? FlutterI18n.translate(
                  context, 
                  activeScooter.cloudConnected 
                    ? "connection_status_cloud_connected" 
                    : "connection_status_cloud_disconnected"
                )
              : null,
            onRefresh: showRefreshButtons
              ? () async {
                  try {
                    await manager.refreshCloudData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(FlutterI18n.translate(context, "connection_status_cloud_refreshed"))),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(FlutterI18n.translate(context, "connection_status_cloud_refresh_failed"))),
                      );
                    }
                  }
                }
              : null,
          ),
      ],
    );
  }
  
  Widget _buildStatusIcon(
    BuildContext context, {
    required IconData icon,
    required bool active,
    String? label,
    VoidCallback? onRefresh,
  }) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    final effectiveActiveColor = activeColor ?? Theme.of(context).colorScheme.primary;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: active ? effectiveActiveColor : effectiveIconColor,
        ),
        
        if (label != null) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: iconSize * 0.6,
              color: active ? effectiveActiveColor : effectiveIconColor,
            ),
          ),
        ],
        
        if (onRefresh != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh),
            iconSize: iconSize * 0.8,
            color: effectiveIconColor,
            onPressed: onRefresh,
            tooltip: FlutterI18n.translate(context, "connection_status_refresh"),
          ),
        ],
      ],
    );
  }
}
