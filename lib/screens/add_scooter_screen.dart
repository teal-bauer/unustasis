import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../models/scooter_manager.dart';
import '../models/scooter.dart';
import '../cloud_service.dart';
import '../domain/format_utils.dart';

class AddScooterScreen extends StatefulWidget {
  const AddScooterScreen({super.key});

  @override
  State<AddScooterScreen> createState() => _AddScooterScreenState();
}

class _AddScooterScreenState extends State<AddScooterScreen> {
  final log = Logger('AddScooterScreen');
  
  // States for adding different kinds of scooters
  bool _isScanning = false;
  bool _isLoadingCloud = false;
  List<BluetoothDevice> _foundDevices = [];
  List<Map<String, dynamic>> _cloudScooters = [];
  
  // Step in the process
  enum AddScooterStep {
    chooseMethod, // Choose between BLE/Cloud
    scanningBle, // Scanning for BLE scooters
    selectingBle, // Select from found BLE scooters
    configuringBle, // Configure a selected BLE scooter
    selectingCloud, // Select from cloud scooters
  }
  
  AddScooterStep _currentStep = AddScooterStep.chooseMethod;
  
  // Selected scooter data
  BluetoothDevice? _selectedBleDevice;
  Map<String, dynamic>? _selectedCloudScooter;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController(text: "Scooter Pro");
  int _selectedColor = 1;
  
  @override
  void initState() {
    super.initState();
    _checkCloudStatus();
  }
  
  // Check if cloud is authenticated for showing appropriate options
  Future<void> _checkCloudStatus() async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    final isAuthenticated = await manager.isCloudAuthenticated();
    
    if (isAuthenticated) {
      _loadCloudScooters();
    }
  }
  
  // Load cloud scooters if authenticated
  Future<void> _loadCloudScooters() async {
    setState(() {
      _isLoadingCloud = true;
    });
    
    try {
      final manager = Provider.of<ScooterManager>(context, listen: false);
      final scooters = await manager.getCloudScooters();
      
      setState(() {
        _cloudScooters = scooters;
        _isLoadingCloud = false;
      });
    } catch (e, stack) {
      log.warning('Failed to load cloud scooters', e, stack);
      setState(() {
        _isLoadingCloud = false;
      });
    }
  }
  
  // Start BLE scan for scooters
  Future<void> _startBleScan() async {
    setState(() {
      _isScanning = true;
      _currentStep = AddScooterStep.scanningBle;
      _foundDevices = [];
    });
    
    try {
      final manager = Provider.of<ScooterManager>(context, listen: false);
      
      // Get list of scooter IDs we already have
      final existingIds = manager.scooters.keys.toList();
      
      final devices = await manager.scanForNewScooters(
        excludeIds: existingIds,
        timeout: const Duration(seconds: 30),
      );
      
      setState(() {
        _foundDevices = devices;
        _isScanning = false;
        
        if (devices.isEmpty) {
          // If no devices found, go back to choice
          _currentStep = AddScooterStep.chooseMethod;
        } else if (devices.length == 1) {
          // If only one device found, select it directly
          _selectedBleDevice = devices.first;
          _currentStep = AddScooterStep.configuringBle;
        } else {
          // If multiple devices found, show selection
          _currentStep = AddScooterStep.selectingBle;
        }
      });
    } catch (e, stack) {
      log.severe('Error scanning for scooters', e, stack);
      setState(() {
        _isScanning = false;
        _currentStep = AddScooterStep.chooseMethod;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: ${e.toString()}')),
      );
    }
  }
  
  // Select a BLE device from the found list
  void _selectBleDevice(BluetoothDevice device) {
    setState(() {
      _selectedBleDevice = device;
      _currentStep = AddScooterStep.configuringBle;
    });
  }
  
  // Go to cloud scooter selection
  void _showCloudScooters() {
    setState(() {
      _currentStep = AddScooterStep.selectingCloud;
    });
  }
  
  // Select a cloud scooter
  void _selectCloudScooter(Map<String, dynamic> scooter) {
    setState(() {
      _selectedCloudScooter = scooter;
      
      // Pre-fill the name and color from cloud data
      if (scooter.containsKey('name') && scooter['name'] != null) {
        _nameController.text = scooter['name'];
      }
      
      if (scooter.containsKey('color_id') && scooter['color_id'] != null) {
        _selectedColor = scooter['color_id'];
      }
      
      _currentStep = AddScooterStep.configuringBle;
    });
  }
  
  // Create a new scooter from BLE device
  Future<void> _createBleScooter() async {
    if (_selectedBleDevice == null) {
      return;
    }
    
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    // Create a new scooter instance
    final Scooter scooter = Scooter(
      id: _selectedBleDevice!.remoteId.toString(),
      name: _nameController.text,
      color: _selectedColor,
      lastBleConnect: DateTime.now(),
    );
    
    // Add to manager
    await manager.addScooter(scooter);
    
    // Link with cloud if selected
    if (_selectedCloudScooter != null) {
      try {
        await manager.linkScooterToCloud(
          scooterId: scooter.id,
          cloudScooterId: _selectedCloudScooter!['id'],
        );
      } catch (e, stack) {
        log.warning('Failed to link with cloud', e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloud linking failed: ${e.toString()}')),
        );
      }
    }
    
    // Go back to home screen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, 'add_scooter')),
      ),
      body: _buildCurrentStep(),
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case AddScooterStep.chooseMethod:
        return _buildChooseMethodStep();
      case AddScooterStep.scanningBle:
        return _buildScanningStep();
      case AddScooterStep.selectingBle:
        return _buildSelectBleStep();
      case AddScooterStep.configuringBle:
        return _buildConfigureStep();
      case AddScooterStep.selectingCloud:
        return _buildSelectCloudStep();
    }
  }
  
  Widget _buildChooseMethodStep() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlutterI18n.translate(context, 'how_to_add_scooter'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          // BLE option
          Card(
            child: ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(FlutterI18n.translate(context, 'add_via_bluetooth')),
              subtitle: Text(FlutterI18n.translate(context, 'add_via_bluetooth_desc')),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _startBleScan,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Cloud option
          FutureBuilder<bool>(
            future: Provider.of<ScooterManager>(context, listen: false).isCloudAuthenticated(),
            builder: (context, snapshot) {
              final bool cloudAvailable = snapshot.data == true;
              
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.cloud,
                    color: cloudAvailable ? null : Colors.grey,
                  ),
                  title: Text(FlutterI18n.translate(context, 'add_via_cloud')),
                  subtitle: Text(
                    cloudAvailable
                        ? FlutterI18n.translate(context, 'add_via_cloud_desc')
                        : FlutterI18n.translate(context, 'cloud_not_connected'),
                  ),
                  trailing: cloudAvailable 
                      ? const Icon(Icons.arrow_forward_ios)
                      : null,
                  onTap: cloudAvailable ? _showCloudScooters : _navigateToCloudSettings,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildScanningStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            FlutterI18n.translate(context, 'scanning_for_scooters'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            FlutterI18n.translate(context, 'make_sure_scooter_on'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectBleStep() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlutterI18n.translate(context, 'select_scooter'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            FlutterI18n.translate(context, 'found_scooters', 
              translationParams: {'count': _foundDevices.length.toString()}),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView.builder(
              itemCount: _foundDevices.length,
              itemBuilder: (context, index) {
                final device = _foundDevices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(device.platformName.isNotEmpty 
                        ? device.platformName 
                        : 'Unu Scooter'),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _selectBleDevice(device),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(FlutterI18n.translate(context, 'scan_again')),
              onPressed: _startBleScan,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfigureStep() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlutterI18n.translate(context, 'configure_scooter'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          // Scooter ID
          if (_selectedBleDevice != null) 
            Text(
              'ID: ${_selectedBleDevice!.remoteId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          
          // Cloud link info if applicable
          if (_selectedCloudScooter != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.cloud_done,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  FlutterI18n.translate(
                    context, 
                    'linked_to_cloud',
                    translationParams: {'name': _selectedCloudScooter!['name']},
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Name field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: FlutterI18n.translate(context, 'scooter_name'),
              border: const OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Color selection
          Text(
            FlutterI18n.translate(context, 'scooter_color'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 120,
            child: _buildColorSelection(),
          ),
          
          const Spacer(),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createBleScooter,
              child: Text(FlutterI18n.translate(context, 'save_scooter')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectCloudStep() {
    if (_isLoadingCloud) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_cloudScooters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                FlutterI18n.translate(context, 'no_cloud_scooters'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(FlutterI18n.translate(context, 'refresh')),
                onPressed: _loadCloudScooters,
              ),
            ],
          ),
        ),
      );
    }
    
    // Filter out scooters that are already linked
    final manager = Provider.of<ScooterManager>(context);
    final linkedCloudIds = manager.scooters.values
        .where((s) => s.cloudScooterId != null)
        .map((s) => s.cloudScooterId)
        .toList();
    
    final availableScooters = _cloudScooters
        .where((s) => !linkedCloudIds.contains(s['id']))
        .toList();
    
    if (availableScooters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                FlutterI18n.translate(context, 'all_cloud_scooters_linked'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlutterI18n.translate(context, 'select_cloud_scooter'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView.builder(
              itemCount: availableScooters.length,
              itemBuilder: (context, index) {
                final scooter = availableScooters[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Image.asset(
                      "images/scooter/side_${scooter['color_id'] ?? 1}.webp",
                      height: 40,
                    ),
                    title: Text(scooter['name'] ?? 'Unu Scooter'),
                    subtitle: Text(
                      FlutterI18n.translate(
                        context, 
                        'last_seen',
                        translationParams: {
                          'time': FormatUtils.formatLastSeen(scooter['last_seen_at']),
                        },
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _startBleScan(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildColorSelection() {
    // List of available colors
    final List<Map<String, dynamic>> colors = [
      {'id': 0, 'name': 'color_black', 'color': Colors.black},
      {'id': 1, 'name': 'color_white', 'color': Colors.white},
      {'id': 2, 'name': 'color_green', 'color': Colors.green.shade900},
      {'id': 3, 'name': 'color_gray', 'color': Colors.grey},
      {'id': 4, 'name': 'color_orange', 'color': Colors.deepOrange.shade400},
      {'id': 5, 'name': 'color_red', 'color': Colors.red},
      {'id': 6, 'name': 'color_blue', 'color': Colors.blue},
    ];
    
    // Special colors for certain names (as in original code)
    if (_nameController.text == "Eclipse") {
      colors.add({'id': 7, 'name': 'color_eclipse', 'color': Colors.grey.shade800});
    }
    if (_nameController.text == "Kbiq") {
      colors.add({'id': 8, 'name': 'color_idioteque', 'color': Colors.teal.shade200});
    }
    if (_nameController.text == "Hover") {
      colors.add({'id': 9, 'name': 'color_hover', 'color': Colors.lightBlue});
    }
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final colorData = colors[index];
        final selected = _selectedColor == colorData['id'];
        
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _selectedColor = colorData['id']),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorData['color'],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.grey,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          color: colorData['id'] == 1 
                              ? Colors.black 
                              : Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                FlutterI18n.translate(context, colorData['name']),
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _navigateToCloudSettings() {
    // TODO: Navigate to cloud settings
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        FlutterI18n.translate(context, 'connect_to_cloud_first')
      )),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}