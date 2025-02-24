import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

import '../domain/scooter_state.dart';
import '../flutter/blue_plus_mockable.dart';
import '../infrastructure/characteristic_repository.dart';
import '../infrastructure/scooter_reader.dart';

class BLEConnectionService {
  final log = Logger('BLEConnectionService');
  final FlutterBluePlusMockable _flutterBluePlus;
  
  // Connection state
  bool _autoRestarting = false;
  BluetoothDevice? _device;
  CharacteristicRepository? _characteristicRepository;
  ScooterReader? _scooterReader;
  
  // Callbacks
  final StateUpdateCallback? onStateUpdate;
  final BatteryUpdateCallback? onBatteryUpdate;
  final RssiUpdateCallback? onRssiUpdate;
  
  // Getters
  bool get isConnected => _device?.isConnected ?? false;
  BluetoothDevice? get device => _device;
  CharacteristicRepository? get characteristicRepository => _characteristicRepository;
  
  BLEConnectionService(
    this._flutterBluePlus, {
    this.onStateUpdate,
    this.onBatteryUpdate,
    this.onRssiUpdate,
  });
  
  // Connect to a device by ID
  Future<void> connect(String id) async {
    log.info("Connecting to device: $id");
    
    try {
      // Create device from ID and attempt connection
      BluetoothDevice attemptedDevice = BluetoothDevice.fromId(id);
      await attemptedDevice.connect(timeout: const Duration(seconds: 30));
      
      _device = attemptedDevice;

      // Set up characteristics
      await _setupCharacteristics();

      // Listen for disconnects
      _device!.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          log.info("Lost connection to device");
          
          // Attempt reconnection if auto-restart is enabled
          if (_autoRestarting) {
            connect(id);
          }
        }
      });

    } catch (e, stack) {
      log.severe("Failed to connect to device", e, stack);
      throw Exception("Failed to connect: ${e.toString()}");
    }
  }
  
  // Disconnect from the current device
  Future<void> disconnect() async {
    if (_device != null && _device!.isConnected) {
      try {
        await _device!.disconnect();
      } catch (e, stack) {
        log.warning("Error disconnecting from device", e, stack);
      }
    }
    
    _device = null;
    _characteristicRepository = null;
    
    if (_scooterReader != null) {
      _scooterReader!.dispose();
      _scooterReader = null;
    }
  }
  
  // Set up characteristics and readers
  Future<void> _setupCharacteristics() async {
    if (_device == null) return;
    
    try {
      _characteristicRepository = CharacteristicRepository(_device!);
      await _characteristicRepository!.findAll();
      
      _scooterReader = ScooterReader(
        characteristicRepository: _characteristicRepository!,
        onStateUpdate: onStateUpdate,
        onBatteryUpdate: onBatteryUpdate,
        onRssiUpdate: onRssiUpdate,
      );
      
      _scooterReader!.readAndSubscribe();
    } catch (e, stack) {
      log.severe("Error setting up characteristics", e, stack);
      throw Exception("Failed to set up characteristics: ${e.toString()}");
    }
  }
  
  // Scan for devices
  Future<List<BluetoothDevice>> scan({
    List<String>? savedIds,
    List<String>? excludeIds,
    bool preferSavedIds = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_flutterBluePlus.isScanningNow) {
      _flutterBluePlus.stopScan();
    }
    
    final List<BluetoothDevice> foundDevices = [];
    final Completer<List<BluetoothDevice>> completer = Completer();
    
    try {
      // Start scanning
      if (preferSavedIds && savedIds != null && savedIds.isNotEmpty) {
        // First try to scan for known scooters
        _flutterBluePlus.startScan(
          withRemoteIds: savedIds,
          timeout: timeout,
        );
      } else {
        // If no known scooters or not preferring saved IDs, scan for all unu scooters
        _flutterBluePlus.startScan(
          withNames: ["unu Scooter"],
          timeout: timeout,
        );
      }
      
      // Listen for scan results
      final subscription = _flutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // Skip devices that are in the exclude list
          if (excludeIds != null && excludeIds.contains(result.device.remoteId.toString())) {
            continue;
          }
          
          // Skip devices that are already in our list
          if (foundDevices.any((device) => device.remoteId.toString() == result.device.remoteId.toString())) {
            continue;
          }
          
          foundDevices.add(result.device);
        }
      });
      
      // Complete when scan finishes
      _flutterBluePlus.isScanning.where((isScanning) => !isScanning).first.then((_) {
        subscription.cancel();
        completer.complete(foundDevices);
      });
      
      // Handle timeout
      Future.delayed(timeout + const Duration(seconds: 1), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          _flutterBluePlus.stopScan();
          completer.complete(foundDevices);
        }
      });
    } catch (e, stack) {
      log.severe("Error scanning for devices", e, stack);
      _flutterBluePlus.stopScan();
      completer.completeError(e, stack);
    }
    
    return completer.future;
  }
  
  // Auto-reconnection control
  void startAutoReconnect() {
    _autoRestarting = true;
  }
  
  void stopAutoReconnect() {
    _autoRestarting = false;
  }
}
