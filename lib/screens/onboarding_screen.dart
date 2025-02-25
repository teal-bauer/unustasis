import 'dart:io';

import 'package:appcheck/appcheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud_service.dart';
import '../domain/scooter_state.dart';
import '../domain/theme_helper.dart';
import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import '../widgets/scooter_visual.dart';
import 'home_screen.dart';
import 'support_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final log = Logger('OnboardingScreen');
  int tapCount = 0;
  bool _isScanning = false;
  bool _bluetoothEnabled = true;
  bool _showingCloudLogin = false;
  bool _isCloudLoading = false;
  bool _isCloudAuthenticated = false;
  List<BluetoothDevice> _foundDevices = [];
  BluetoothDevice? _selectedDevice;
  
  // For scooter customization
  final TextEditingController _nameController = TextEditingController(text: "Scooter Pro");
  int _selectedColor = 1;

  @override
  void initState() {
    super.initState();
    // Check for old app on startup
    _warnOfOldApp();
  }

  void _warnOfOldApp() async {
    final appCheck = AppCheck();
    log.info("Checking for old app");
    bool appInstalled = false;
    if (Platform.isAndroid) {
      appInstalled = await appCheck.isAppInstalled('com.unumotors.app');
    } else if (Platform.isIOS) {
      appInstalled = await appCheck.isAppInstalled('com.unumotors.app://');
    }
    if (appInstalled) {
      showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(FlutterI18n.translate(context, "old_app_alert_title")),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(FlutterI18n.translate(context, "old_app_alert_body")),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(FlutterI18n.translate(
                    context, "old_app_alert_acknowledge")),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      log.info("Old app not detected");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkCloudStatus() async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    final cloudService = CloudService(manager);
    
    setState(() {
      _isCloudLoading = true;
    });
    
    try {
      final isAuth = await cloudService.isAuthenticated;
      setState(() {
        _isCloudAuthenticated = isAuth;
        _isCloudLoading = false;
      });
    } catch (e) {
      setState(() {
        _isCloudAuthenticated = false;
        _isCloudLoading = false;
      });
    }
  }

  Future<void> _startSetup() async {
    log.info("Starting setup");
    
    setState(() {
      _isScanning = true;
    });
    
    try {
      final manager = Provider.of<ScooterManager>(context, listen: false);
      
      // Check if Bluetooth is available
      try {
        log.info("Checking Bluetooth availability");
        
        // Get the Bluetooth adapter state directly
        final adapterState = await FlutterBluePlus.adapterState.first;
        log.info("Bluetooth adapter state: $adapterState");
        
        final isBluetoothAvailable = adapterState == BluetoothAdapterState.on;
        log.info("Bluetooth available: $isBluetoothAvailable");
        
        setState(() {
          _bluetoothEnabled = isBluetoothAvailable;
          if (!isBluetoothAvailable) {
            _isScanning = false;
          }
        });
        
        if (isBluetoothAvailable) {
          // Start scanning for BLE devices
          _startScan();
        } else {
          log.info("Bluetooth is disabled, showing message");
          // Bluetooth is disabled, show message
          setState(() {
            _isScanning = false;
          });
          
          // Show a dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(FlutterI18n.translate(context, "ble_bluetooth_disabled_title")),
              content: Text(FlutterI18n.translate(context, "ble_bluetooth_disabled_message")),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(FlutterI18n.translate(context, "ble_bluetooth_disabled_ok")),
                ),
              ],
            ),
          );
        }
      } catch (e, stack) {
        log.severe("Error checking Bluetooth availability", e, stack);
        setState(() {
          _bluetoothEnabled = false;
          _isScanning = false;
        });
      }
      
      // Check cloud status
      _checkCloudStatus();
    } catch (e, stack) {
      log.severe("Error in _startSetup", e, stack);
      setState(() {
        _isScanning = false;
        _bluetoothEnabled = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting setup: ${e.toString()}")),
        );
      }
    }
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
    } catch (e, stack) {
      log.severe("Error scanning for devices", e, stack);
      setState(() {
        _isScanning = false;
      });
      
      if (mounted) {
        // Check if this is a Bluetooth disabled error
        if (e.toString().contains("bluetooth must be turned on")) {
          setState(() {
            _bluetoothEnabled = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FlutterI18n.translate(context, "add_scooter_scan_error"))),
          );
        }
      }
    }
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
        
        // Go to home screen
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ));
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
  
  void _showCloudLogin() {
    setState(() {
      _showingCloudLogin = true;
    });
  }

  void _hideCloudLogin() {
    setState(() {
      _showingCloudLogin = false;
    });
  }

  Widget _buildCloudTokenDialog() {
    final TextEditingController tokenController = TextEditingController();
    final manager = Provider.of<ScooterManager>(context, listen: false);
    final cloudService = CloudService(manager);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, "cloud_token_title"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(FlutterI18n.translate(context, "cloud_token_description")),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              decoration: InputDecoration(
                labelText: FlutterI18n.translate(context, "cloud_token_label"),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                // Open dashboard in browser
                final url = Uri.parse('https://sunshine.rescoot.org/dashboard');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: Text(FlutterI18n.translate(context, "cloud_token_get")),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _hideCloudLogin,
                  child: Text(FlutterI18n.translate(context, "cloud_token_cancel")),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final token = tokenController.text.trim();
                    if (token.isEmpty) return;
                    
                    try {
                      await cloudService.setToken(token);
                      if (mounted) {
                        _hideCloudLogin();
                        // Refresh the screen to show cloud scooters
                        setState(() {
                          _isCloudAuthenticated = true;
                          _isCloudLoading = false;
                        });
                        // Show cloud scooters
                        _showCloudScooters();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(FlutterI18n.translate(
                            context, 
                            "cloud_token_invalid",
                            translationParams: {"error": e.toString()}
                          ))),
                        );
                      }
                    }
                  },
                  child: Text(FlutterI18n.translate(context, "cloud_token_save")),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCloudScooters() {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    final cloudService = CloudService(manager);
    
    setState(() {
      _isCloudLoading = true;
    });
    
    cloudService.refreshScooters().then((scooters) {
      if (mounted) {
        setState(() {
          _isCloudLoading = false;
        });
        
        if (scooters.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FlutterI18n.translate(context, "cloud_no_scooters"))),
          );
          return;
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(FlutterI18n.translate(context, "cloud_select_scooter")),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: scooters.length,
                itemBuilder: (context, index) {
                  final scooter = scooters[index];
                  return ListTile(
                    leading: Image.asset(
                      "images/scooter/side_${scooter['color_id'] ?? 1}.webp",
                      height: 60,
                    ),
                    title: Text(scooter['name']),
                    onTap: () async {
                      Navigator.pop(context);
                      
                      try {
                        await manager.addCloudScooter(scooter);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(FlutterI18n.translate(
                              context, 
                              "cloud_scooter_added",
                              translationParams: {"name": scooter['name']}
                            ))),
                          );
                          // Go to home screen
                          Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(FlutterI18n.translate(
                              context, 
                              "cloud_scooter_add_error",
                              translationParams: {"error": e.toString()}
                            ))),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(FlutterI18n.translate(context, "cloud_select_cancel")),
              ),
            ],
          ),
        );
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _isCloudLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FlutterI18n.translate(
            context, 
            "cloud_refresh_error",
            translationParams: {"error": e.toString()}
          ))),
        );
      }
    });
  }

  Widget _buildBottomContent() {
    if (!_isScanning && _foundDevices.isEmpty && !_showingCloudLogin) {
      // Initial welcome screen
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FlutterI18n.translate(context, "onboarding_step0_heading"),
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            FlutterI18n.translate(context, "onboarding_step0_body"),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _startSetup,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                FlutterI18n.translate(context, "onboarding_step0_button"),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    } else if (_isScanning) {
      // Scanning UI
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            FlutterI18n.translate(context, "ble_scanning_message"),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _showCloudLogin,
            icon: const Icon(Icons.cloud),
            label: Text(FlutterI18n.translate(context, "add_scooter_cloud_login")),
          ),
        ],
      );
    } else if (!_bluetoothEnabled) {
      // Bluetooth disabled UI
      return Column(
        children: [
          const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            FlutterI18n.translate(context, "ble_bluetooth_disabled_message"),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _bluetoothEnabled = true;
              });
              _startScan();
            },
            icon: const Icon(Icons.refresh),
            label: Text(FlutterI18n.translate(context, "ble_scan_again")),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showCloudLogin,
            icon: const Icon(Icons.cloud),
            label: Text(FlutterI18n.translate(context, "add_scooter_cloud")),
          ),
        ],
      );
    } else if (_foundDevices.isNotEmpty) {
      // Found devices list
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FlutterI18n.translate(context, "ble_scooter_selection_title"),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
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
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.refresh),
                label: Text(FlutterI18n.translate(context, "ble_scan_again")),
              ),
              OutlinedButton.icon(
                onPressed: _showCloudLogin,
                icon: const Icon(Icons.cloud),
                label: Text(FlutterI18n.translate(context, "add_scooter_cloud")),
              ),
            ],
          ),
        ],
      );
    } else if (_showingCloudLogin) {
      // Cloud login UI
      return _buildCloudTokenDialog();
    }
    
    // Default empty widget
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness:
                context.isDarkMode ? Brightness.dark : Brightness.light),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SupportScreen(),
                ));
              },
              icon: const Icon(Icons.help_outline))
        ],
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.15),
            radius: 1,
            colors: [
              Theme.of(context).colorScheme.surfaceContainer,
              Theme.of(context).colorScheme.onTertiary,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Scooter visual
              Expanded(
                child: GestureDetector(
                  // Easter egg - tap 27 times to skip onboarding
                  onTap: () {
                    tapCount++;
                    if (tapCount >= 27) {
                      log.info('27 taps detected! Skipping onboarding...');
                      tapCount = 0;
                      // Schedule navigation after the build is complete
                      Future.microtask(() {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (context) => const HomeScreen(forceOpen: true),
                        ));
                      });
                    }
                  },
                  child: ScooterVisual(
                    state: ScooterState.disconnected,
                    scanning: _isScanning,
                    blinkerLeft: false,
                    blinkerRight: false,
                  ),
                ),
              ),
              
              // Bottom content area
              _buildBottomContent(),
            ],
          ),
        ),
      ),
    );
  }
}
