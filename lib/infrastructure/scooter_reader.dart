import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

import '../domain/scooter_state.dart';
import 'characteristic_repository.dart';

typedef StateUpdateCallback = void Function(ScooterState? state);
typedef BatteryUpdateCallback = void Function({
  int? primarySOC,
  int? secondarySOC,
  int? cbbSOC,
  bool? cbbCharging,
  int? auxSOC,
  int? primaryCycles,
  int? secondaryCycles,
});
typedef RssiUpdateCallback = void Function(int rssi);
typedef SeatUpdateCallback = void Function(bool closed);
typedef HandlebarUpdateCallback = void Function(bool locked);

class ScooterReader {
  final log = Logger('ScooterReader');
  final CharacteristicRepository characteristicRepository;
  final StateUpdateCallback? onStateUpdate;
  final BatteryUpdateCallback? onBatteryUpdate;
  final RssiUpdateCallback? onRssiUpdate;
  final SeatUpdateCallback? onSeatUpdate;
  final HandlebarUpdateCallback? onHandlebarUpdate;
  
  Timer? _rssiTimer;
  StreamSubscription? _batterySubscription;

  ScooterReader({
    required this.characteristicRepository,
    this.onStateUpdate,
    this.onBatteryUpdate,
    this.onRssiUpdate,
    this.onSeatUpdate,
    this.onHandlebarUpdate,
  });

  void readAndSubscribe() {
    // Set up state listener
    characteristicRepository.stateCharacteristic?.value.listen((value) {
      String stateString = ascii.decode(value);
      ScooterState? state = ScooterState.fromString(stateString);
      onStateUpdate?.call(state);
    });

    // Set up seat listener
    characteristicRepository.seatCharacteristic?.value.listen((value) {
      String seatString = ascii.decode(value);
      bool closed = seatString.trim() == "1";
      onSeatUpdate?.call(closed);
    });

    // Set up handlebar listener
    characteristicRepository.handlebarCharacteristic?.value.listen((value) {
      String handlebarString = ascii.decode(value);
      bool locked = handlebarString.trim() == "1";
      onHandlebarUpdate?.call(locked);
    });

    // Set up battery listener
    if (characteristicRepository.batteryCharacteristic != null) {
      _batterySubscription = characteristicRepository.batteryCharacteristic!.listen((value) {
        String batteryString = ascii.decode(value);
        List<String> batteryValues = batteryString.split(",");
        if (batteryValues.length >= 7) {
          onBatteryUpdate?.call(
            primarySOC: int.tryParse(batteryValues[0]),
            secondarySOC: int.tryParse(batteryValues[1]),
            cbbSOC: int.tryParse(batteryValues[2]),
            cbbCharging: batteryValues[3] == "1",
            auxSOC: int.tryParse(batteryValues[4]),
            primaryCycles: int.tryParse(batteryValues[5]),
            secondaryCycles: int.tryParse(batteryValues[6]),
          );
        }
      });
    }

    // Initial reads
    characteristicRepository.stateCharacteristic?.read();
    characteristicRepository.seatCharacteristic?.read();
    characteristicRepository.handlebarCharacteristic?.read();
    
    // Start RSSI polling
    startRssiPolling();
  }

  void startRssiPolling({Duration interval = const Duration(seconds: 3)}) {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(interval, (_) => readRssi());
  }

  void stopRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
  }

  Future<void> readRssi() async {
    try {
      BluetoothDevice device = characteristicRepository.device;
      int rssi = await device.readRssi();
      onRssiUpdate?.call(rssi);
    } catch (e, stack) {
      log.warning("Failed to read RSSI", e, stack);
    }
  }

  void dispose() {
    stopRssiPolling();
    _batterySubscription?.cancel();
  }
}
