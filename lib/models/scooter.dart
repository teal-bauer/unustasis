import 'dart:convert';
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/scooter_state.dart';

enum ScooterSourceType { ble, cloud, both }

class Scooter with ChangeNotifier {
  // Basic identification
  String _id; // BLE ID
  String _name;
  int _color;
  int? _cloudScooterId;
  bool _autoConnect;

  // Connectivity state
  bool _bleConnected = false;
  DateTime? _lastBleConnect;
  bool _cloudConnected = false;
  DateTime? _lastCloudSync;

  // Status from BLE
  ScooterState? _state;
  bool? _seatClosed;
  bool? _handlebarsLocked;
  int? _primarySOC;
  int? _secondarySOC;
  int? _cbbSOC;
  bool? _cbbCharging;
  int? _auxSOC;
  int? _primaryCycles;
  int? _secondaryCycles;
  int? _rssi;
  LatLng? _lastLocation;

  // Status from cloud (some values might be duplicated from BLE)
  DateTime? _lastPing;
  Map<String, dynamic>? _cloudData;

  // Constructor for new scooters or loading from storage
  Scooter({
    required String id,
    String? name,
    int? color,
    int? cloudScooterId,
    bool? autoConnect,
    DateTime? lastBleConnect,
    DateTime? lastCloudSync,
    LatLng? lastLocation,
    int? primarySOC,
    int? secondarySOC,
    int? cbbSOC,
    int? auxSOC,
    int? primaryCycles,
    int? secondaryCycles,
  })  : _id = id,
        _name = name ?? "Scooter Pro",
        _color = color ?? 1,
        _cloudScooterId = cloudScooterId,
        _autoConnect = autoConnect ?? true,
        _lastBleConnect = lastBleConnect,
        _lastCloudSync = lastCloudSync,
        _lastLocation = lastLocation,
        _primarySOC = primarySOC,
        _secondarySOC = secondarySOC,
        _cbbSOC = cbbSOC,
        _auxSOC = auxSOC,
        _primaryCycles = primaryCycles,
        _secondaryCycles = secondaryCycles;

  // Getters
  String get id => _id;
  String get name => _name;
  int get color => _color;
  int? get cloudScooterId => _cloudScooterId;
  bool get autoConnect => _autoConnect;
  bool get bleConnected => _bleConnected;
  DateTime? get lastBleConnect => _lastBleConnect;
  bool get cloudConnected => _cloudConnected;
  DateTime? get lastCloudSync => _lastCloudSync;
  ScooterState? get state => _state;
  bool? get seatClosed => _seatClosed;
  bool? get handlebarsLocked => _handlebarsLocked;
  int? get primarySOC => _primarySOC;
  int? get secondarySOC => _secondarySOC;
  int? get cbbSOC => _cbbSOC;
  bool? get cbbCharging => _cbbCharging;
  int? get auxSOC => _auxSOC;
  int? get primaryCycles => _primaryCycles;
  int? get secondaryCycles => _secondaryCycles;
  int? get rssi => _rssi;
  LatLng? get lastLocation => _lastLocation;
  DateTime? get lastPing => _lastPing ?? _lastBleConnect ?? _lastCloudSync;
  Map<String, dynamic>? get cloudData => _cloudData;

  // Derived properties
  ScooterSourceType get sourceType {
    bool hasBle = _lastBleConnect != null;
    bool hasCloud = _cloudScooterId != null;

    if (hasBle && hasCloud) return ScooterSourceType.both;
    if (hasBle) return ScooterSourceType.ble;
    if (hasCloud) return ScooterSourceType.cloud;

    // Default fallback, should never happen
    return ScooterSourceType.ble;
  }

  DateTime get lastConnection {
    // Return the most recent connection timestamp
    if (_lastBleConnect != null && _lastCloudSync != null) {
      return _lastBleConnect!.isAfter(_lastCloudSync!) ? _lastBleConnect! : _lastCloudSync!;
    } else if (_lastBleConnect != null) {
      return _lastBleConnect!;
    } else if (_lastCloudSync != null) {
      return _lastCloudSync!;
    } else {
      return DateTime.now(); // Fallback
    }
  }

  // Setters that trigger notifications
  set name(String value) {
    if (_name != value) {
      _name = value;
      notifyListeners();
      saveToPrefs();
    }
  }

  set color(int value) {
    if (_color != value) {
      _color = value;
      notifyListeners();
      saveToPrefs();
    }
  }

  set cloudScooterId(int? value) {
    if (_cloudScooterId != value) {
      _cloudScooterId = value;
      notifyListeners();
      saveToPrefs();
    }
  }

  set autoConnect(bool value) {
    if (_autoConnect != value) {
      _autoConnect = value;
      notifyListeners();
      saveToPrefs();
    }
  }

  // Update methods for BLE data
  void updateBleConnection({
    required bool connected,
    ScooterState? state,
    bool? seatClosed,
    bool? handlebarsLocked,
    int? rssi,
  }) {
    bool changed = false;

    if (_bleConnected != connected) {
      _bleConnected = connected;
      changed = true;
    }

    if (connected) {
      _lastBleConnect = DateTime.now();
      _lastPing = _lastBleConnect;
      changed = true;
    }

    if (state != null && _state != state) {
      _state = state;
      changed = true;
    }

    if (seatClosed != null && _seatClosed != seatClosed) {
      _seatClosed = seatClosed;
      changed = true;
    }

    if (handlebarsLocked != null && _handlebarsLocked != handlebarsLocked) {
      _handlebarsLocked = handlebarsLocked;
      changed = true;
    }

    if (rssi != null && _rssi != rssi) {
      _rssi = rssi;
      changed = true;
    }

    if (changed) {
      notifyListeners();
      saveToPrefs();
    }
  }

  // Update battery information
  void updateBatteryInfo({
    int? primarySOC,
    int? secondarySOC,
    int? cbbSOC,
    bool? cbbCharging,
    int? auxSOC,
    int? primaryCycles,
    int? secondaryCycles,
  }) {
    bool changed = false;

    if (primarySOC != null && _primarySOC != primarySOC) {
      _primarySOC = primarySOC;
      changed = true;
    }

    if (secondarySOC != null && _secondarySOC != secondarySOC) {
      _secondarySOC = secondarySOC;
      changed = true;
    }

    if (cbbSOC != null && _cbbSOC != cbbSOC) {
      _cbbSOC = cbbSOC;
      changed = true;
    }

    if (cbbCharging != null && _cbbCharging != cbbCharging) {
      _cbbCharging = cbbCharging;
      changed = true;
    }

    if (auxSOC != null && _auxSOC != auxSOC) {
      _auxSOC = auxSOC;
      changed = true;
    }

    if (primaryCycles != null && _primaryCycles != primaryCycles) {
      _primaryCycles = primaryCycles;
      changed = true;
    }

    if (secondaryCycles != null && _secondaryCycles != secondaryCycles) {
      _secondaryCycles = secondaryCycles;
      changed = true;
    }

    if (changed) {
      _lastPing = DateTime.now();
      notifyListeners();
      saveToPrefs();
    }
  }

  // Update location
  void updateLocation(LatLng location) {
    _lastLocation = location;
    notifyListeners();
    saveToPrefs();
  }

  // Update cloud connection and data
  void updateCloudConnection({
    required bool connected,
    Map<String, dynamic>? cloudData,
  }) {
    bool changed = false;

    if (_cloudConnected != connected) {
      _cloudConnected = connected;
      changed = true;
    }

    if (connected) {
      _lastCloudSync = DateTime.now();
      changed = true;
    }

    if (cloudData != null) {
      _cloudData = cloudData;

      // Only update from cloud if we don't have a custom name set
      if (_name == "Scooter Pro" && _color == 1) {
        // Extract information from cloud data to update scooter
        if (cloudData.containsKey('name') && cloudData['name'] != null) {
          _name = cloudData['name'];
          changed = true;
        }
        if (cloudData.containsKey('color_id') && cloudData['color_id'] != null) {
          _color = cloudData['color_id'];
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
      saveToPrefs();
    }
  }

  // Reset to disconnected state
  void resetConnection() {
    _bleConnected = false;
    _state = ScooterState.disconnected;
    notifyListeners();
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': _id,
      'name': _name,
      'color': _color,
      'cloudScooterId': _cloudScooterId,
      'autoConnect': _autoConnect,
      'lastBleConnect': _lastBleConnect?.millisecondsSinceEpoch,
      'lastCloudSync': _lastCloudSync?.millisecondsSinceEpoch,
      'lastLocation': _lastLocation?.toJson(),
      'primarySOC': _primarySOC,
      'secondarySOC': _secondarySOC,
      'cbbSOC': _cbbSOC,
      'auxSOC': _auxSOC,
      'primaryCycles': _primaryCycles,
      'secondaryCycles': _secondaryCycles,
    };
  }

  // Create from JSON
  factory Scooter.fromJson(Map<String, dynamic> json) {
    return Scooter(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      cloudScooterId: json['cloudScooterId'],
      autoConnect: json['autoConnect'] ?? true,
      lastBleConnect:
          json['lastBleConnect'] != null ? DateTime.fromMillisecondsSinceEpoch(json['lastBleConnect']) : null,
      lastCloudSync: json['lastCloudSync'] != null ? DateTime.fromMillisecondsSinceEpoch(json['lastCloudSync']) : null,
      lastLocation: json['lastLocation'] != null ? LatLng.fromJson(json['lastLocation']) : null,
      primarySOC: json['primarySOC'],
      secondarySOC: json['secondarySOC'],
      cbbSOC: json['cbbSOC'],
      auxSOC: json['auxSOC'],
      primaryCycles: json['primaryCycles'],
      secondaryCycles: json['secondaryCycles'],
    );
  }

  // Save to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> scootersMap = {};

    if (prefs.containsKey('scooters')) {
      scootersMap = jsonDecode(prefs.getString('scooters')!) as Map<String, dynamic>;
    }

    scootersMap[_id] = toJson();
    await prefs.setString('scooters', jsonEncode(scootersMap));
  }

  // Check if this scooter is active
  bool isConnected() {
    return _bleConnected || _cloudConnected;
  }

  // Range calculation utility
  int calculateRange() {
    int primaryRange = _primarySOC != null ? (45 * (_primarySOC! / 100)).round() : 0;
    int secondaryRange = _secondarySOC != null ? (45 * (_secondarySOC! / 100)).round() : 0;
    return primaryRange + secondaryRange;
  }

  int calculateNonThrottledRange() {
    int primaryRange = _primarySOC != null ? (Math.max(0, (_primarySOC! - 20) / 100 * 45)).round() : 0;
    int secondaryRange = _secondarySOC != null ? (Math.max(0, (_secondarySOC! - 20) / 100 * 45)).round() : 0;
    return primaryRange + secondaryRange;
  }
}
