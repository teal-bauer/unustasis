import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

import '../domain/scooter_battery.dart';
import '../infrastructure/string_reader.dart';
import '../infrastructure/utils.dart';
import '../models/scooter_manager.dart';

class BatteryReader {
  final log = Logger("BatteryReader");
  final ScooterBattery _battery;
  final ScooterManager _manager;

  BatteryReader(this._battery, this._manager);

  void readAndSubscribeSOC(
    BluetoothCharacteristic socCharacteristic,
  ) async {
    subscribeCharacteristic(socCharacteristic, (value) async {
      int? soc;
      if (_battery == ScooterBattery.cbb && value.length == 1) {
        soc = value[0];
      } else {
        soc = _convertUint32ToInt(value);
      }
      log.info("$_battery SOC received: $soc");
      
      // sometimes the scooter sends null. Ignoring those values...
      if (soc != null) {
        switch (_battery) {
          case ScooterBattery.primary:
            _manager.updateBatteryInfo(primarySOC: soc);
            break;
          case ScooterBattery.secondary:
            _manager.updateBatteryInfo(secondarySOC: soc);
            break;
          case ScooterBattery.cbb:
            _manager.updateBatteryInfo(cbbSOC: soc);
            break;
          case ScooterBattery.aux:
            _manager.updateBatteryInfo(auxSOC: soc);
            break;
        }
      }
    });
  }

  void readAndSubscribeCycles(
    BluetoothCharacteristic cyclesCharacteristic,
  ) async {
    subscribeCharacteristic(cyclesCharacteristic, (value) {
      int? cycles = _convertUint32ToInt(value);
      log.info("$_battery battery cycles received: $cycles");
      
      if (cycles != null) {
        switch (_battery) {
          case ScooterBattery.primary:
            _manager.updateBatteryInfo(primaryCycles: cycles);
            break;
          case ScooterBattery.secondary:
            _manager.updateBatteryInfo(secondaryCycles: cycles);
            break;
          default:
            // we will never read cycles of CBB or AUX, so this is unreachable
            break;
        }
      }
    });
  }

  void readAndSubscribeCharging(
    BluetoothCharacteristic chargingCharacteristic,
  ) {
    StringReader("${_battery.name} charging", chargingCharacteristic)
        .readAndSubscribe((String chargingState) {
      if (chargingState == "charging") {
        switch (_battery) {
          case ScooterBattery.cbb:
            _manager.updateBatteryInfo(cbbCharging: true);
            break;
          default:
            // CBB is the only one that reports charging, so this is unreachable
            break;
        }
      } else if (chargingState == "not-charging") {
        switch (_battery) {
          case ScooterBattery.cbb:
            _manager.updateBatteryInfo(cbbCharging: false);
            break;
          default:
            // CBB is the only one that reports charging, so this is unreachable
            break;
        }
      }
    });
  }

  int? _convertUint32ToInt(List<int> uint32data) {
    log.fine("Converting $uint32data to int.");
    if (uint32data.length != 4) {
      log.info("Received empty data for uint32 conversion. Ignoring.");
      return null;
    }

    // Little-endian to big-endian interpretation (important for proper UInt32 conversion)
    return (uint32data[3] << 24) +
        (uint32data[2] << 16) +
        (uint32data[1] << 8) +
        uint32data[0];
  }
}