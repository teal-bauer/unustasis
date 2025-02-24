import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:latlong2/latlong.dart';

import '../domain/scooter_state.dart';

// value cache
bool _connected = false;
DateTime? _lastPing;
ScooterState? _scooterState;
int? _primarySOC;
int? _secondarySOC;
String? _scooterName;
LatLng? _lastLocation;
bool? _seatClosed;

void passToWidget({
  bool connected = false,
  DateTime? lastPing,
  ScooterState? scooterState,
  int? primarySOC,
  int? secondarySOC,
  String? scooterName,
  LatLng? lastLocation,
  bool? seatClosed,
}) async {
  if (connected != _connected ||
      (scooterState?.isOn) != (_scooterState?.isOn) ||
      (scooterState?.isReadyForSeatOpen) !=
          (_scooterState?.isReadyForSeatOpen) ||
      lastPing?.calculateTimeDifferenceInShort() !=
          _lastPing?.calculateTimeDifferenceInShort() ||
      scooterState?.toString() != _scooterState?.toString() ||
      primarySOC != _primarySOC ||
      secondarySOC != _secondarySOC ||
      scooterName != _scooterName ||
      lastLocation != _lastLocation ||
      seatClosed != _seatClosed) {
    print("Relevant values have changed");

    await HomeWidget.saveWidgetData<bool>("connected", connected);
    if (scooterState != null) {
      await HomeWidget.saveWidgetData<bool>("locked", !scooterState.isOn);
      await HomeWidget.saveWidgetData<bool>(
          "seatOpenable", scooterState.isReadyForSeatOpen);
    }

    // Not broadcasting "linking" state by default
    String stateName = "disconnected";
    if (scooterState != null) {
      stateName = scooterState == ScooterState.linking
          ? "disconnected"
          : scooterState.toString().split('.').last;
    }
    await HomeWidget.saveWidgetData<String>("stateName", stateName);

    await HomeWidget.saveWidgetData<String>(
        "lastPing", lastPing?.calculateTimeDifferenceInShort() ?? "");

    await HomeWidget.saveWidgetData<int>("soc1", primarySOC);
    await HomeWidget.saveWidgetData<int?>("soc2", secondarySOC);
    await HomeWidget.saveWidgetData<String>("scooterName", scooterName);
    await HomeWidget.saveWidgetData("seatClosed", seatClosed);

    await HomeWidget.saveWidgetData<String>(
        "lastLat", lastLocation?.latitude.toString() ?? "0.0");
    await HomeWidget.saveWidgetData<String>(
        "lastLon", lastLocation?.longitude.toString() ?? "0.0");

    // once everything is set, rebuild the widget
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'de.freal.unustasis.HomeWidgetReceiver',
    );
  } else {
    print("No relevant changes");
  }
}

Future<void> setWidgetScanning(bool scanning) async {
  await HomeWidget.saveWidgetData<bool>("scanning", scanning);
      await HomeWidget.saveWidgetData<String>(
          "stateName", "linking");
  await HomeWidget.updateWidget(
    qualifiedAndroidName: 'de.freal.unustasis.HomeWidgetReceiver',
  );
}

@pragma("vm:entry-point")
FutureOr<void> backgroundCallback(Uri? data) async {
  await HomeWidget.setAppGroupId('de.freal.unustasis');
  print("Received data: $data");
  switch (data?.host) {
    case "scan":
      setWidgetScanning(true);
    case "lock":
      FlutterBackgroundService().invoke("lock");
    case "unlock":
      FlutterBackgroundService().invoke("unlock");
    case "openseat":
      FlutterBackgroundService().invoke("openseat");
  }
  await HomeWidget.updateWidget(
    qualifiedAndroidName: 'de.freal.unustasis.HomeWidgetReceiver',
  );
}

extension DateTimeExtension on DateTime {
  String calculateTimeDifferenceInShort() {
    final originalDate = DateTime.now();
    final difference = originalDate.difference(this);

    if ((difference.inDays / 7).floor() >= 1) {
      return '${(difference.inDays / 7).floor()}W';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}D';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}H';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}M';
    } else {
      return "";
    }
  }
}

// Extension methods moved to domain/scooter_state.dart
