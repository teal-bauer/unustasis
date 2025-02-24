import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../cloud_service.dart';
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
        // Cloud connection status
        if (scooter?.cloudScooterId != null)
          _buildCloudStatus(context, scooter!),
          
        // BLE connection status
        _buildBleStatus(context, manager, scooter),
      ],
    );
  }

  Widget _buildCloudStatus(BuildContext context, Scooter scooter) {
    final cloudService = CloudService(Provider.of<ScooterManager>(context));
    final log = Logger('StatusText/CloudStatus');

    return StreamBuilder<bool>(
      stream: Stream.periodic(const Duration(seconds: 5))
          .asyncMap((_) => cloudService.isAuthenticated),
      initialData: false,
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData || !authSnapshot.data!) return Container();

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getCurrentCloudScooter(context, cloudService, scooter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return Text(
              FlutterI18n.translate(
                context,
                (!snapshot.hasData || snapshot.data == null)
                    ? "cloud_no_linked_scooter"
                    : "cloud_scooter_linked_to",
                translationParams: snapshot.hasData && snapshot.data != null 
                    ? {"name": snapshot.data!['name']} 
                    : {},
              ),
              style: Theme.of(context).textTheme.titleMedium,
            );
          },
        );
      },
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
          : ((state != null
              ? state.name(context)
              : FlutterI18n.translate(context, "home_loading_state")) +
              (connected && scooter?.handlebarsLocked == false
                  ? FlutterI18n.translate(context, "home_unlocked")
                  : "")),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Future<Map<String, dynamic>?> _getCurrentCloudScooter(
      BuildContext context, CloudService cloudService, Scooter scooter) async {
    if (!await cloudService.isAuthenticated || scooter.cloudScooterId == null) {
      return null;
    }

    final cloudScooters = await cloudService.getScooters();

    try {
      return cloudScooters.firstWhere(
        (s) => s['id'] == scooter.cloudScooterId,
        orElse: () => throw Exception("Cloud scooter not found"),
      );
    } catch (e) {
      return null;
    }
  }
}