import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../models/scooter.dart';
import '../models/scooter_manager.dart';

class BleScooterSelectionScreen extends StatefulWidget {
  const BleScooterSelectionScreen({super.key});

  @override
  State<BleScooterSelectionScreen> createState() => _BleScooterSelectionScreenState();
}

class _BleScooterSelectionScreenState extends State<BleScooterSelectionScreen> {
  final log = Logger('BleScooterSelectionScreen');
  bool _isScanning = false;
  List<BluetoothDevice> _foundDevices = [];
  BluetoothDevice? _selectedDevice;
  
  // For scooter customization
  final TextEditingController _nameController = TextEditingController(text: "Scooter Pro");
  int _selectedColor = 1;
  
  @override
  void initState() {
    super.initState();
    _startScan();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices = [];
    });
    
    try {
      final manager = Provider.of<ScooterManager>(context, listen: false);
      final devices = await manager.scanForNewScooters(
        timeout: const Duration(seconds: 30),
      );
      
      setState(() {
        _foundDevices = devices;
        _isScanning = false;
      });
      
      if (devices.isEmpty) {
        _showNoDevicesFoundDialog();
      }
    } catch (e, stack) {
      log.severe("Error scanning for devices", e, stack);
      setState(() {
        _isScanning = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FlutterI18n.translate(context, "add_scooter_scan_error"))),
        );
      }
    }
  }
  
  void _showNoDevicesFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, "ble_no_devices_title")),
        content: Text(FlutterI18n.translate(context, "ble_no_devices_message")),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startScan();
            },
            child: Text(FlutterI18n.translate(context, "ble_no_devices_retry")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(FlutterI18n.translate(context, "ble_no_devices_cancel")),
          ),
        ],
      ),
    );
  }
  
  void _selectDevice(BluetoothDevice device) {
    setState(() {
      _selectedDevice = device;
    });
    
    _showCustomizationDialog(device);
  }
  
  void _showCustomizationDialog(BluetoothDevice device) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(FlutterI18n.translate(context, "ble_customize_scooter_title")),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: FlutterI18n.translate(context, "ble_customize_name_label"),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Color selection
                Text(
                  FlutterI18n.translate(context, "ble_customize_color_label"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                // Color grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 10, // Colors 0-9
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          _selectedColor = index;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedColor == index
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(
                            "images/scooter/side_$index.webp",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedDevice = null;
                });
              },
              child: Text(FlutterI18n.translate(context, "ble_customize_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _connectToDevice(device);
              },
              child: Text(FlutterI18n.translate(context, "ble_customize_save")),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _connectToDevice(BluetoothDevice device) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, "ble_connecting_title")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(FlutterI18n.translate(context, "ble_connecting_message")),
          ],
        ),
      ),
    );
    
    try {
      // Create a new scooter with the selected name and color
      final scooter = Scooter(
        id: device.remoteId.toString(),
        name: _nameController.text,
        color: _selectedColor,
        autoConnect: true,
        lastBleConnect: DateTime.now(),
      );
      
      // Add the scooter to the manager
      await manager.addScooter(scooter);
      
      // Connect to the scooter
      await manager.connectToScooterId(device.remoteId.toString());
      
      if (mounted) {
        // Close the loading dialog
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FlutterI18n.translate(
            context, 
            "ble_scooter_added_success",
            translationParams: {"name": _nameController.text}
          ))),
        );
        
        // Return to home screen
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e, stack) {
      log.severe("Error connecting to device", e, stack);
      
      if (mounted) {
        // Close the loading dialog
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FlutterI18n.translate(
            context, 
            "ble_scooter_added_error",
            translationParams: {"error": e.toString()}
          ))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "ble_scooter_selection_title")),
      ),
      body: _isScanning
          ? _buildScanningView()
          : _buildDeviceListView(),
      floatingActionButton: !_isScanning
          ? FloatingActionButton(
              onPressed: _startScan,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }
  
  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            FlutterI18n.translate(context, "ble_scanning_message"),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceListView() {
    if (_foundDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64),
            const SizedBox(height: 16),
            Text(
              FlutterI18n.translate(context, "ble_no_devices_found"),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: Text(FlutterI18n.translate(context, "ble_scan_again")),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _foundDevices.length,
      itemBuilder: (context, index) {
        final device = _foundDevices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(device.platformName.isNotEmpty
              ? device.platformName
              : "Unu Scooter"),
          subtitle: Text(device.remoteId.toString()),
          trailing: ElevatedButton(
            onPressed: () => _selectDevice(device),
            child: Text(FlutterI18n.translate(context, "ble_select_device")),
          ),
        );
      },
    );
  }
}
