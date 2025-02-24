import '../domain/scooter_battery.dart';
import '../domain/scooter_power_state.dart';
import '../domain/scooter_state.dart';
import '../infrastructure/battery_reader.dart';
import '../infrastructure/characteristic_repository.dart';
import '../infrastructure/string_reader.dart';
import '../models/scooter_manager.dart';

class ScooterReader {
  final CharacteristicRepository _characteristicRepository;
  ScooterState? _state;
  ScooterPowerState? _powerState;
  final ScooterManager _manager;

  ScooterReader({
    required ScooterManager service,
    required CharacteristicRepository characteristicRepository,
  })  : _characteristicRepository = characteristicRepository,
        _manager = service;

  void readAndSubscribe() {
    _subscribeState();
    _subscribePowerStateForHibernation();
    _subscribeSeat();
    _subscribeHandlebars();
    _subscribeBatteries();
  }

  void _subscribeState() {
    StringReader("State", _characteristicRepository.stateCharacteristic!)
        .readAndSubscribe((String value) {
      _state = ScooterState.fromString(value);
      _updateScooterState();
    });
  }

  void _subscribePowerStateForHibernation() {
    if (_characteristicRepository.powerStateCharacteristic != null) {
      StringReader("Power State", _characteristicRepository.powerStateCharacteristic!)
          .readAndSubscribe((String value) {
        _powerState = ScooterPowerState.fromString(value);
        _updateScooterState();
      });
    }
  }

  Future<void> _updateScooterState() async {
    ScooterState? newState = ScooterState.fromStateAndPowerState(_state, _powerState);
    _manager.updateBleState(newState);
  }

  void _subscribeSeat() {
    StringReader("Seat", _characteristicRepository.seatCharacteristic!)
        .readAndSubscribe((String seatState) {
      _manager.updateSeatState(seatState != "open");
    });
  }

  void _subscribeHandlebars() {
    StringReader("Handlebars", _characteristicRepository.handlebarCharacteristic!)
        .readAndSubscribe((String handlebarState) {
      _manager.updateHandlebarsState(handlebarState != "unlocked");
    });
  }

  void _subscribeBatteries() {
    var auxBatteryReader = BatteryReader(ScooterBattery.aux, _manager);
    auxBatteryReader.readAndSubscribeSOC(_characteristicRepository.auxSOCCharacteristic!);

    var cbbBatteryReader = BatteryReader(ScooterBattery.cbb, _manager);
    cbbBatteryReader.readAndSubscribeSOC(_characteristicRepository.cbbSOCCharacteristic!);
    cbbBatteryReader.readAndSubscribeCharging(_characteristicRepository.cbbChargingCharacteristic!);

    var primaryBatteryReader = BatteryReader(ScooterBattery.primary, _manager);
    primaryBatteryReader.readAndSubscribeSOC(
      _characteristicRepository.primarySOCCharacteristic!,
    );
    primaryBatteryReader.readAndSubscribeCycles(
      _characteristicRepository.primaryCyclesCharacteristic!,
    );

    var secondaryBatteryReader = BatteryReader(ScooterBattery.secondary, _manager);
    secondaryBatteryReader.readAndSubscribeSOC(
      _characteristicRepository.secondarySOCCharacteristic!,
    );
    secondaryBatteryReader.readAndSubscribeCycles(
      _characteristicRepository.secondaryCyclesCharacteristic!,
    );
  }
}