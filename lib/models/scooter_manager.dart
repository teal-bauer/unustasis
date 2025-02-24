import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble_command_service.dart';
import '../cloud_command_service.dart';
import '../cloud_service.dart';
import '../command_service.dart';
import '../domain/scooter_state.dart';
import '../flutter/blue_plus_mockable.dart';
import '../services/ble_connection_service.dart';
import 'scooter.dart';

typedef ConfirmationCallback = Future<bool> Function();

class ScooterManager with ChangeNotifier {
  final log = Logger('ScooterManager');

  // Dependencies
  late final FlutterBluePlusMockable _flutterBluePlus;
  late CloudService _cloudService;

  // State
  Map<String, Scooter> _scooters = {};
  String? _activeScooterId;

  // Connection services
  late BLEConnectionService _bleConnectionService;
  late CloudCommandService _cloudCommands;
  BLECommandService? _bleCommands;
  
  // Connection state
  bool _scanning = false;

  // Settings
  bool _autoUnlock = false;
  int _autoUnlockThreshold = -65; // Default threshold
  bool _openSeatOnUnlock = false;
  bool _hazardLocking = false;
  bool _optionalAuth = false;
  bool _autoUnlockCooldown = false;

  // Getters
  Map<String, Scooter> get scooters => _scooters;
  String? get activeScooterId => _activeScooterId;
  Scooter? get activeScooter => _activeScooterId != null ? _scooters[_activeScooterId] : null;
  bool get scanning => _scanning;
  bool get connected => _bleConnectionService.isConnected;
  BluetoothDevice? get activeDevice => _bleConnectionService.device;
  bool get autoUnlock => _autoUnlock;
  int get autoUnlockThreshold => _autoUnlockThreshold;
  bool get openSeatOnUnlock => _openSeatOnUnlock;
  bool get hazardLocking => _hazardLocking;
  bool get optionalAuth => _optionalAuth;
  
  // Background service compatibility getters
  ScooterState? get state => activeScooter?.state;
  DateTime? get lastPing => activeScooter?.lastConnection;
  int? get primarySOC => activeScooter?.primarySOC;
  int? get secondarySOC => activeScooter?.secondarySOC;
  String? get scooterName => activeScooter?.name;
  LatLng? get lastLocation => activeScooter?.lastLocation;
  bool? get seatClosed => activeScooter?.seatClosed;

  // Constructor
  ScooterManager(this._flutterBluePlus, {bool isInBackgroundService = false}) {
    // Initialize BLE connection service with callbacks
    _bleConnectionService = BLEConnectionService(
      _flutterBluePlus,
      onStateUpdate: updateBleState,
      onBatteryUpdate: updateBatteryInfo,
      onRssiUpdate: updateRssi,
    );
    
    _initialize();
  }

  // Initialize the manager
  Future<void> _initialize() async {
    // Set up cloud service
    _cloudService = CloudService(this);
    _cloudCommands = CloudCommandService(_cloudService, this);

    // Load saved settings
    await _loadSettings();

    // Load saved scooters
    await _loadScooters();

    // Update scanning status
    _flutterBluePlus.isScanning.listen((isScanning) {
      _scanning = isScanning;
      notifyListeners();
    });

    // Attempt to connect to the most recent scooter if available
    if (_activeScooterId != null) {
      attemptToConnectToActiveScooter();
    }
  }

  // Setters that notify
  set optionalAuth(bool value) {
    _optionalAuth = value;
    notifyListeners();
  }

  // Settings management
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoUnlock = prefs.getBool('autoUnlock') ?? false;
    _autoUnlockThreshold = prefs.getInt('autoUnlockThreshold') ?? -65;
    _openSeatOnUnlock = prefs.getBool('openSeatOnUnlock') ?? false;
    _hazardLocking = prefs.getBool('hazardLocking') ?? false;
    _optionalAuth = !(prefs.getBool('biometrics') ?? false);

    // Load active scooter ID
    _activeScooterId = prefs.getString('activeScooterId');
  }

  Future<void> setAutoUnlock(bool value) async {
    _autoUnlock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoUnlock', value);
    notifyListeners();
  }

  Future<void> setAutoUnlockThreshold(int value) async {
    _autoUnlockThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoUnlockThreshold', value);
    notifyListeners();
  }

  Future<void> setOpenSeatOnUnlock(bool value) async {
    _openSeatOnUnlock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('openSeatOnUnlock', value);
    notifyListeners();
  }

  Future<void> setHazardLocking(bool value) async {
    _hazardLocking = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hazardLocking', value);
    notifyListeners();
  }

  // Scooter management
  Future<void> _loadScooters() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey('scooters')) {
      final String scootersJson = prefs.getString('scooters')!;
      final Map<String, dynamic> scootersMap = jsonDecode(scootersJson) as Map<String, dynamic>;

      for (var entry in scootersMap.entries) {
        final Scooter scooter = Scooter.fromJson(entry.value as Map<String, dynamic>);
        _scooters[entry.key] = scooter;
      }

      // Legacy import if we have old data
      if (_scooters.isEmpty && prefs.containsKey('savedScooters')) {
        await _migrateFromOldFormat(prefs);
      }

      // Set active scooter if necessary
      if (_activeScooterId == null && _scooters.isNotEmpty) {
        _setMostRecentAsActive();
      }
    } else if (prefs.containsKey('savedScooters')) {
      await _migrateFromOldFormat(prefs);
    }

    notifyListeners();
  }

  // Migrate from the old storage format
  Future<void> _migrateFromOldFormat(SharedPreferences prefs) async {
    try {
      Map<String, dynamic> oldScooters = jsonDecode(prefs.getString('savedScooters')!) as Map<String, dynamic>;

      for (var entry in oldScooters.entries) {
        String id = entry.key;
        Map<String, dynamic> data = entry.value as Map<String, dynamic>;

        Scooter scooter = Scooter(
          id: id,
          name: data['name'] ?? 'Scooter Pro',
          color: data['color'] ?? 1,
          cloudScooterId: data['cloudScooterId'],
          autoConnect: data['autoConnect'] ?? true,
          lastBleConnect: data.containsKey('lastPing') ? DateTime.fromMicrosecondsSinceEpoch(data['lastPing']) : null,
          lastLocation: data['lastLocation'] != null ? LatLng.fromJson(data['lastLocation']) : null,
          primarySOC: data['lastPrimarySOC'],
          secondarySOC: data['lastSecondarySOC'],
          cbbSOC: data['lastCbbSOC'],
          auxSOC: data['lastAuxSOC'],
        );

        _scooters[id] = scooter;
      }

      // Save in new format
      await _saveScooters();

      // Set the most recently used scooter as active
      _setMostRecentAsActive();
    } catch (e, stack) {
      log.severe("Error migrating from old format", e, stack);
    }
  }

  // Set the most recently used scooter as active
  void _setMostRecentAsActive() {
    if (_scooters.isEmpty) return;

    Scooter? mostRecent;

    for (var scooter in _scooters.values) {
      if (scooter.autoConnect && (mostRecent == null || (scooter.lastConnection.isAfter(mostRecent.lastConnection)))) {
        mostRecent = scooter;
      }
    }

    if (mostRecent != null) {
      setActiveScooter(mostRecent.id);
    }
  }
  
  // Background service compatibility method
  void setMostRecentScooter(String id) async {
    if (_scooters.containsKey(id)) {
      _scooters[id]!.updateLastConnection(DateTime.now());
      await _saveScooters();
      
      if (_activeScooterId != id) {
        setActiveScooter(id);
      }
    }
  }

  // Save all scooters to preferences
  Future<void> _saveScooters() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> scootersMap = {};

    for (var entry in _scooters.entries) {
      scootersMap[entry.key] = entry.value.toJson();
    }

    await prefs.setString('scooters', jsonEncode(scootersMap));
  }

  Future<void> renameSavedScooter({required String id, required String name}) async {
    if (_scooters.containsKey(id)) {
      _scooters[id]!.name = name;
      await _saveScooters();
      notifyListeners();
    }
  }

  // Set the active scooter
  Future<void> setActiveScooter(String scooterId) async {
    if (_scooters.containsKey(scooterId)) {
      // Disconnect from current scooter if needed
      if (_activeScooterId != null && _bleConnectionService.isConnected) {
        await _bleConnectionService.disconnect();
        _bleCommands = null;
      }

      _activeScooterId = scooterId;

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeScooterId', scooterId);

      // Try to connect to the new active scooter
      attemptToConnectToActiveScooter();

      notifyListeners();
    }
  }

  // Add a new scooter
  Future<void> addScooter(Scooter scooter) async {
    _scooters[scooter.id] = scooter;
    await _saveScooters();

    // If this is the first scooter, set it as active
    if (_scooters.length == 1 || _activeScooterId == null) {
      await setActiveScooter(scooter.id);
    }

    notifyListeners();
  }
  
  // Get saved scooter IDs (for background service)
  Future<List<String>> getSavedScooterIds({bool onlyAutoConnect = false}) async {
    if (onlyAutoConnect) {
      return _scooters.values
          .where((scooter) => scooter.autoConnect)
          .map((scooter) => scooter.id)
          .toList();
    } else {
      return _scooters.keys.toList();
    }
  }
  
  // Alias for removeScooter (for background service)
  Future<void> forgetSavedScooter(String scooterId) async {
    await removeScooter(scooterId);
  }

  // Remove a scooter
  Future<void> removeScooter(String scooterId) async {
    if (_scooters.containsKey(scooterId)) {
      // If it's the active scooter, disconnect it first
      if (_activeScooterId == scooterId) {
        if (_bleConnectionService.isConnected) {
          await _bleConnectionService.disconnect();
        }

        _bleCommands = null;
        _activeScooterId = null;

        // Save the cleared active scooter ID
        final prefs = await SharedPreferences.getInstance();
        prefs.remove('activeScooterId');
      }

      // Try to remove bond with the device
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await BluetoothDevice.fromId(scooterId).removeBond();
        } catch (e) {
          log.warning("Could not remove bond for scooter: $scooterId", e);
        }
      }

      // Remove from the map
      _scooters.remove(scooterId);
      await _saveScooters();

      // If we still have scooters, set a new active one
      if (_scooters.isNotEmpty && _activeScooterId == null) {
        _setMostRecentAsActive();
      }

      notifyListeners();
    }
  }

  // BLE Scanning and connection
  Future<void> attemptToConnectToActiveScooter() async {
    if (_activeScooterId == null || !_scooters.containsKey(_activeScooterId!)) {
      return;
    }

    try {
      // Connect to the device using BLEConnectionService
      await _bleConnectionService.connect(_activeScooterId!);
      
      // Set up BLE commands
      if (_bleConnectionService.characteristicRepository != null) {
        _bleCommands = BLECommandService(
          _bleConnectionService.device!, 
          _bleConnectionService.characteristicRepository
        );
      }

      // Update the scooter's status
      _scooters[_activeScooterId!]?.updateBleConnection(
        connected: true,
        state: ScooterState.unknown, // Will be updated by characteristic listener
      );

      notifyListeners();
    } catch (e, stack) {
      log.warning("Failed to connect to active scooter", e, stack);
      _startScan();
    }
  }

  // Start scanning for scooters
  Future<void> _startScan() async {
    // Get list of scooter IDs we have, for quicker reconnection
    List<String> scooterIds = _scooters.keys.toList();
    
    try {
      await _bleConnectionService.scan(
        savedIds: scooterIds.isNotEmpty ? scooterIds : null,
        preferSavedIds: scooterIds.isNotEmpty,
      );
    } catch (e, stack) {
      log.severe("Failed to start BLE scan", e, stack);
    }
  }

  // Scan for new scooters (public scan method)
  Future<List<BluetoothDevice>> scanForNewScooters({
    List<String> excludeIds = const [],
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _bleConnectionService.scan(
      excludeIds: excludeIds,
      preferSavedIds: false,
    );
  }
  
  // Public method to start scanning for scooters
  Future<void> startScanning() async {
    return _startScan();
  }

  // Start auto-reconnection
  void startAutoReconnect() {
    _bleConnectionService.startAutoReconnect();
  }

  // Stop auto-reconnection
  void stopAutoReconnect() {
    _bleConnectionService.stopAutoReconnect();
  }

  // Command execution
  Future<bool> isCommandAvailable(CommandType command) async {
    // Check BLE first if initialized
    if (_bleCommands != null && await _bleCommands!.isAvailable(command)) {
      return true;
    }
    // Check cloud availability
    return await _cloudCommands.isAvailable(command);
  }
  
  // Background service compatibility methods for common commands
  Future<void> lock() async {
    await executeCommand(CommandType.lock);
  }
  
  Future<void> unlock() async {
    await executeCommand(CommandType.unlock);
  }
  
  Future<void> openSeat() async {
    await executeCommand(CommandType.openSeat);
  }
  
  Future<void> wakeUp() async {
    await executeCommand(CommandType.wakeUp);
  }

  Future<void> executeCommand(
    CommandType command, {
    ConfirmationCallback? onNeedConfirmation,
  }) async {
    log.info("Executing command: $command");

    // Try BLE first if available
    if (_bleCommands != null && await _bleCommands!.isAvailable(command)) {
      log.info("BLE exec: $command");
      if (!await _bleCommands!.execute(command)) {
        throw Exception("BLE command failed: $command");
      }

      // Special handling for certain commands
      if (command == CommandType.lock) {
        if (_hazardLocking) {
          // Flash hazard lights once
          await _hazardOperation(1);
        }
      } else if (command == CommandType.unlock) {
        if (_hazardLocking) {
          // Flash hazard lights twice
          await _hazardOperation(2);
        }

        if (_openSeatOnUnlock) {
          // Open seat after unlocking
          await Future.delayed(const Duration(milliseconds: 500));
          await executeCommand(CommandType.openSeat, onNeedConfirmation: onNeedConfirmation);
        }
      }

      return;
    }

    // Fall back to cloud if available
    if (await _cloudCommands.isAvailable(command)) {
      log.info("Cloud exec: $command");
      if (await _cloudCommands.needsConfirmation(command)) {
        // If confirmation callback provided, use it
        if (onNeedConfirmation != null) {
          bool confirmed = await onNeedConfirmation();
          if (!confirmed) {
            return;
          }
        } else {
          // No confirmation callback = deny command
          throw Exception("Command requires confirmation but no callback provided");
        }
      }

      if (!await _cloudCommands.execute(command)) {
        throw Exception("Cloud command failed: $command");
      }
      return;
    }

    throw Exception("Command not available: $command");
  }

  // Helper method for flashing hazard lights
  Future<void> _hazardOperation(int times) async {
    await executeCommand(CommandType.blinkerBoth);
    await Future.delayed(Duration(milliseconds: 600 * times));
    await executeCommand(CommandType.blinkerOff);
  }

  // Update location
  void updateLocation(LatLng location) {
    if (_activeScooterId != null && _scooters.containsKey(_activeScooterId!)) {
      _scooters[_activeScooterId!]!.updateLocation(location);
    }
  }

  // Handle BLE data updates for active scooter
  void updateBleState(ScooterState? state) {
    if (_activeScooterId != null && _scooters.containsKey(_activeScooterId!)) {
      _scooters[_activeScooterId!]!.updateBleConnection(
        connected: true,
        state: state,
      );
      notifyListeners();
    }
  }

  void updateSeatState(bool closed) {
    if (_activeScooterId != null && _scooters.containsKey(_activeScooterId!)) {
      _scooters[_activeScooterId!]!.updateBleConnection(
        connected: true,
        seatClosed: closed,
      );
      notifyListeners();
    }
  }

  void updateHandlebarsState(bool locked) {
    if (_activeScooterId != null && _scooters.containsKey(_activeScooterId!)) {
      _scooters[_activeScooterId!]!.updateBleConnection(
        connected: true,
        handlebarsLocked: locked,
      );
      notifyListeners();
    }
  }

  void updateBatteryInfo({
    int? primarySOC,
    int? secondarySOC,
    int? cbbSOC,
    bool? cbbCharging,
    int? auxSOC,
    int? primaryCycles,
    int? secondaryCycles,
  }) {
    if (_activeScooterId != null && _scooters.containsKey(_activeScooterId!)) {
      _scooters[_activeScooterId!]!.updateBatteryInfo(
        primarySOC: primarySOC,
        secondarySOC: secondarySOC,
        cbbSOC: cbbSOC,
        cbbCharging: cbbCharging,
        auxSOC: auxSOC,
        primaryCycles: primaryCycles,
        secondaryCycles: secondaryCycles,
      );
      notifyListeners();
    }
  }

  void updateRssi(int rssi) {
    if (_activeScooterId != null && _scooters.containsKey(_activeScooterId!)) {
      _scooters[_activeScooterId!]!.updateBleConnection(
        connected: true,
        rssi: rssi,
      );

      // Auto-unlock if conditions are met
      if (_autoUnlock &&
          !_autoUnlockCooldown &&
          _optionalAuth &&
          rssi > _autoUnlockThreshold &&
          activeScooter?.state == ScooterState.standby) {
        _autoUnlockCooldown = true;
        executeCommand(CommandType.unlock);

        // Reset cooldown after delay
        Future.delayed(const Duration(seconds: 60), () {
          _autoUnlockCooldown = false;
        });
      }
    }
  }

  // Cloud operations
  Future<bool> authenticateCloud(String token) async {
    try {
      await _cloudService.setToken(token);
      return await _cloudService.isAuthenticated;
    } catch (e) {
      return false;
    }
  }
  
  // Background service compatibility method
  Future<bool> attemptLatestAutoConnection() async {
    if (_scooters.isEmpty) return false;
    
    // Find the most recent auto-connect scooter
    Scooter? mostRecent;
    for (var scooter in _scooters.values) {
      if (scooter.autoConnect && (mostRecent == null || scooter.lastConnection.isAfter(mostRecent.lastConnection))) {
        mostRecent = scooter;
      }
    }
    
    if (mostRecent == null) return false;
    
    try {
      await setActiveScooter(mostRecent.id);
      await attemptToConnectToActiveScooter();
      return connected;
    } catch (e) {
      log.warning("Failed to auto-connect to latest scooter", e);
      return false;
    }
  }
  
  // Background service compatibility method for auto-restart
  void startAutoRestart() {
    startAutoReconnect();
  }
  
  // Background service compatibility method for stopping auto-restart
  void stopAutoRestart() {
    stopAutoReconnect();
  }
  
  // Background service compatibility method for connecting to a specific scooter
  Future<void> connectToScooterId(String id) async {
    if (_scooters.containsKey(id)) {
      await setActiveScooter(id);
      await attemptToConnectToActiveScooter();
    } else {
      throw Exception("Scooter with ID $id not found");
    }
  }

  Future<bool> isCloudAuthenticated() async {
    return await _cloudService.isAuthenticated;
  }

  Future<void> logoutCloud() async {
    await _cloudService.logout();
  }

  Future<List<Map<String, dynamic>>> getCloudScooters() async {
    return await _cloudService.getScooters();
  }

  Future<void> refreshCloudData() async {
    await _cloudService.refreshScooters();

    // Update scooters with cloud data
    for (var scooter in _scooters.values) {
      if (scooter.cloudScooterId != null) {
        try {
          final cloudScooters = await _cloudService.getScooters();
          final cloudScooter = cloudScooters.firstWhere(
            (s) => s['id'] == scooter.cloudScooterId,
            orElse: () => throw Exception("Cloud scooter not found"),
          );

          scooter.updateCloudConnection(
            connected: true,
            cloudData: cloudScooter,
          );
        } catch (e) {
          log.warning("Failed to update cloud data for scooter ${scooter.id}", e);
        }
      }
    }

    notifyListeners();
  }
  
  // Add a scooter from cloud data
  Future<void> addCloudScooter(Map<String, dynamic> cloudScooter) async {
    // Create a new scooter with cloud data
    final scooter = Scooter(
      id: "cloud_${cloudScooter['id']}",
      name: cloudScooter['name'] ?? "Cloud Scooter",
      color: cloudScooter['color_id'] ?? 1,
      cloudScooterId: cloudScooter['id'],
      lastCloudSync: DateTime.now(),
    );
    
    // Add the scooter
    await addScooter(scooter);
    
    // Update with cloud data
    scooter.updateCloudConnection(
      connected: true,
      cloudData: cloudScooter,
    );
    
    notifyListeners();
  }

  Future<void> linkScooterToCloud({required String scooterId, required int cloudScooterId}) async {
    if (!_scooters.containsKey(scooterId)) {
      throw Exception("Scooter not found");
    }

    await _cloudService.assignScooter(bleId: scooterId, cloudId: cloudScooterId);
    _scooters[scooterId]!.cloudScooterId = cloudScooterId;

    // Update scooter data from cloud
    await refreshCloudData();
  }

  Future<void> unlinkScooterFromCloud(String scooterId) async {
    if (!_scooters.containsKey(scooterId) || _scooters[scooterId]!.cloudScooterId == null) {
      return;
    }

    await _cloudService.removeAssignment(scooterId);
    _scooters[scooterId]!.cloudScooterId = null;

    notifyListeners();
  }
}
