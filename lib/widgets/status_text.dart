import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../domain/scooter_state.dart';
import '../models/scooter.dart';
import '../models/scooter_manager.dart';

class StatusText extends StatelessWidget {
  const StatusText({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final scooter = manager.activeScooter;

    return Column(
      children: [
        // BLE connection status
        _buildBleStatus(context, manager, scooter),
      ],
    );
  }

  Widget _buildBleStatus(BuildContext context, ScooterManager manager, Scooter? scooter) {
    final bool scanning = manager.scanning;
    final bool connected = manager.connected;
    final ScooterState? state = scooter?.state;

    return Text(
      scanning && (state == null || state == ScooterState.disconnected)
          ? (manager.scooters.isNotEmpty
              ? FlutterI18n.translate(context, "home_scanning_known")
              : FlutterI18n.translate(context, "home_scanning"))
          : ((state != null ? state.name(context) : FlutterI18n.translate(context, "home_loading_state")) +
              (connected && scooter?.handlebarsLocked == false ? FlutterI18n.translate(context, "home_unlocked") : "")),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
