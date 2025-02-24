import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

class CharacteristicRepository {
  final log = Logger("CharacteristicRepository");
  final BluetoothDevice device;
  BluetoothCharacteristic? commandCharacteristic;
  BluetoothCharacteristic? hibernationCommandCharacteristic;
  BluetoothCharacteristic? stateCharacteristic;
  BluetoothCharacteristic? powerStateCharacteristic;
  BluetoothCharacteristic? seatCharacteristic;
  BluetoothCharacteristic? handlebarCharacteristic;
  BluetoothCharacteristic? auxSOCCharacteristic;
  BluetoothCharacteristic? cbbSOCCharacteristic;
  BluetoothCharacteristic? cbbChargingCharacteristic;
  BluetoothCharacteristic? primaryCyclesCharacteristic;
  BluetoothCharacteristic? primarySOCCharacteristic;
  BluetoothCharacteristic? secondaryCyclesCharacteristic;
  BluetoothCharacteristic? secondarySOCCharacteristic;

  // Combined battery characteristic for easier reading
  Stream<List<int>>? get batteryCharacteristic {
    if (primarySOCCharacteristic == null ||
        secondarySOCCharacteristic == null ||
        cbbSOCCharacteristic == null ||
        cbbChargingCharacteristic == null ||
        auxSOCCharacteristic == null ||
        primaryCyclesCharacteristic == null ||
        secondaryCyclesCharacteristic == null) {
      return null;
    }

    // Create a stream controller to combine all battery values
    final controller = StreamController<List<int>>();

    // Subscribe to all battery-related characteristics
    primarySOCCharacteristic!.value.listen((primary) {
      _updateBatteryValues(controller);
    });
    secondarySOCCharacteristic!.value.listen((secondary) {
      _updateBatteryValues(controller);
    });
    cbbSOCCharacteristic!.value.listen((cbb) {
      _updateBatteryValues(controller);
    });
    cbbChargingCharacteristic!.value.listen((charging) {
      _updateBatteryValues(controller);
    });
    auxSOCCharacteristic!.value.listen((aux) {
      _updateBatteryValues(controller);
    });
    primaryCyclesCharacteristic!.value.listen((cycles) {
      _updateBatteryValues(controller);
    });
    secondaryCyclesCharacteristic!.value.listen((cycles) {
      _updateBatteryValues(controller);
    });

    return controller.stream;
  }

  void _updateBatteryValues(StreamController<List<int>> controller) {
    try {
      final primary = primarySOCCharacteristic!.lastValue;
      final secondary = secondarySOCCharacteristic!.lastValue;
      final cbb = cbbSOCCharacteristic!.lastValue;
      final cbbCharging = cbbChargingCharacteristic!.lastValue;
      final aux = auxSOCCharacteristic!.lastValue;
      final primaryCycles = primaryCyclesCharacteristic!.lastValue;
      final secondaryCycles = secondaryCyclesCharacteristic!.lastValue;

      // Format: primarySOC,secondarySOC,cbbSOC,cbbCharging,auxSOC,primaryCycles,secondaryCycles
      final combinedValue = '${ascii.decode(primary)},${ascii.decode(secondary)},${ascii.decode(cbb)},${ascii.decode(cbbCharging)},${ascii.decode(aux)},${ascii.decode(primaryCycles)},${ascii.decode(secondaryCycles)}';
      controller.add(ascii.encode(combinedValue));
    } catch (e, stack) {
      log.warning("Failed to update battery values", e, stack);
    }
  }

  CharacteristicRepository(this.device);

  Future<void> findAll() async {
    log.info("findAll running");
    await device.discoverServices();
    commandCharacteristic = findCharacteristic(
        device,
        "9a590000-6e67-5d0d-aab9-ad9126b66f91",
        "9a590001-6e67-5d0d-aab9-ad9126b66f91");
    hibernationCommandCharacteristic = findCharacteristic(
        device,
        "9a590000-6e67-5d0d-aab9-ad9126b66f91",
        "9a590002-6e67-5d0d-aab9-ad9126b66f91");
    stateCharacteristic = findCharacteristic(
        device,
        "9a590020-6e67-5d0d-aab9-ad9126b66f91",
        "9a590021-6e67-5d0d-aab9-ad9126b66f91");
    log.info("State characteristic initialized! It's $stateCharacteristic");
    powerStateCharacteristic = findCharacteristic(
        device,
        "9a5900a0-6e67-5d0d-aab9-ad9126b66f91",
        "9a5900a1-6e67-5d0d-aab9-ad9126b66f91");
    seatCharacteristic = findCharacteristic(
        device,
        "9a590020-6e67-5d0d-aab9-ad9126b66f91",
        "9a590022-6e67-5d0d-aab9-ad9126b66f91");
    handlebarCharacteristic = findCharacteristic(
        device,
        "9a590020-6e67-5d0d-aab9-ad9126b66f91",
        "9a590023-6e67-5d0d-aab9-ad9126b66f91");
    auxSOCCharacteristic = findCharacteristic(
        device,
        "9a590040-6e67-5d0d-aab9-ad9126b66f91",
        "9a590044-6e67-5d0d-aab9-ad9126b66f91");
    cbbSOCCharacteristic = findCharacteristic(
        device,
        "9a590060-6e67-5d0d-aab9-ad9126b66f91",
        "9a590061-6e67-5d0d-aab9-ad9126b66f91");
    cbbChargingCharacteristic = findCharacteristic(
        device,
        "9a590060-6e67-5d0d-aab9-ad9126b66f91",
        "9a590072-6e67-5d0d-aab9-ad9126b66f91");
    primaryCyclesCharacteristic = findCharacteristic(
        device,
        "9a5900e0-6e67-5d0d-aab9-ad9126b66f91",
        "9a5900e6-6e67-5d0d-aab9-ad9126b66f91");
    primarySOCCharacteristic = findCharacteristic(
        device,
        "9a5900e0-6e67-5d0d-aab9-ad9126b66f91",
        "9a5900e9-6e67-5d0d-aab9-ad9126b66f91");
    secondaryCyclesCharacteristic = findCharacteristic(
        device,
        "9a5900e0-6e67-5d0d-aab9-ad9126b66f91",
        "9a5900f2-6e67-5d0d-aab9-ad9126b66f91");
    secondarySOCCharacteristic = findCharacteristic(
        device,
        "9a5900e0-6e67-5d0d-aab9-ad9126b66f91",
        "9a5900f5-6e67-5d0d-aab9-ad9126b66f91");
    return;
  }

  bool anyAreNull() {
    return stateCharacteristic == null ||
        powerStateCharacteristic == null ||
        seatCharacteristic == null ||
        handlebarCharacteristic == null ||
        auxSOCCharacteristic == null ||
        cbbSOCCharacteristic == null ||
        cbbChargingCharacteristic == null ||
        primaryCyclesCharacteristic == null ||
        primarySOCCharacteristic == null ||
        secondaryCyclesCharacteristic == null ||
        secondarySOCCharacteristic == null;
  }

  static BluetoothCharacteristic? findCharacteristic(
      BluetoothDevice device, String serviceUuid, String characteristicUuid) {
    try {
      return device.servicesList
          .firstWhere(
              (service) => service.serviceUuid.toString() == serviceUuid)
          .characteristics
          .firstWhere((char) =>
              char.characteristicUuid.toString() == characteristicUuid);
    } catch (e) {
      Logger("findCharacteristic")
          .severe("Characteristic $characteristicUuid not found!");
      return null;
    }
  }
}
