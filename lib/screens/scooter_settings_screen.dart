import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logging/logging.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import '../screens/settings_screen.dart';

class ScooterSettingsScreen extends StatefulWidget {
  final Scooter scooter;

  const ScooterSettingsScreen({
    super.key,
    required this.scooter,
  });

  @override
  State<ScooterSettingsScreen> createState() => _ScooterSettingsScreenState();
}

class _ScooterSettingsScreenState extends State<ScooterSettingsScreen> {
  final log = Logger('ScooterSettingsScreen');
  bool showColorOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkColorOnboarding();
  }

  Future<void> _checkColorOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showColorOnboarding = prefs.getBool("color_onboarded") != true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final isActive = widget.scooter.id == manager.activeScooterId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scooter.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scooter image and color selection
          _buildScooterVisual(context),

          const SizedBox(height: 16),

          // Scooter name
          _buildNameSection(context),

          const SizedBox(height: 16),

          // Scooter details
          _buildDetailsSection(context),

          const SizedBox(height: 16),

          // Location section
          if (widget.scooter.lastLocation != null)
            _buildLocationSection(context),

          const SizedBox(height: 16),

          // Auto-connect setting
          if (manager.scooters.length > 1)
            _buildAutoConnectSection(context),

          const SizedBox(height: 16),

          // Cloud connection
          _buildCloudSection(context),

          const SizedBox(height: 24),

          // Action buttons
          _buildActionButtons(context, isActive),
        ],
      ),
    );
  }

  Widget _buildScooterVisual(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Column(
        children: [
          Image.asset(
            "images/scooter/side_${widget.scooter.color}.webp",
            height: 160,
          ),
          if (showColorOnboarding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text(
                FlutterI18n.translate(context, "settings_color_onboarding"),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.scooter.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showRenameDialog(context),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              title: const Text("ID"),
              subtitle: Text(widget.scooter.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, "stats_title_scooter"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(FlutterI18n.translate(context, "stats_state")),
              subtitle: Text(
                widget.scooter.state != null 
                  ? FlutterI18n.translate(context, "state_name_${widget.scooter.state.toString().split('.').last}")
                  : FlutterI18n.translate(context, "state_name_disconnected"),
              ),
            ),
            ListTile(
              title: Text(FlutterI18n.translate(context, "stats_last_ping_title")),
              subtitle: Text(
                widget.scooter.lastConnection.toString().substring(0, 16),
              ),
              onTap: () {
                Fluttertoast.showToast(
                  msg: widget.scooter.lastConnection.toString().substring(0, 16),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, "stats_location"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(FlutterI18n.translate(context, "stats_last_seen_near")),
              subtitle: Text(
                "${widget.scooter.lastLocation!.latitude}, ${widget.scooter.lastLocation!.longitude}",
              ),
              trailing: const Icon(Icons.map_outlined),
              onTap: () {
                MapsLauncher.launchCoordinates(
                  widget.scooter.lastLocation!.latitude,
                  widget.scooter.lastLocation!.longitude,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoConnectSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, "stats_settings_section_connection"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(FlutterI18n.translate(context, "stats_scooter_auto_connect")),
              subtitle: Text(
                widget.scooter.autoConnect
                  ? FlutterI18n.translate(context, "stats_scooter_auto_connect_on_description")
                  : FlutterI18n.translate(context, "stats_scooter_auto_connect_off_description"),
              ),
              value: widget.scooter.autoConnect,
              onChanged: (value) {
                setState(() {
                  widget.scooter.autoConnect = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSection(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, "stats_settings_section_cloud"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            if (widget.scooter.cloudScooterId != null)
              ListTile(
                title: Text(FlutterI18n.translate(context, "cloud_scooter_linked")),
                subtitle: Text(FlutterI18n.translate(
                  context, 
                  "cloud_scooter_linked_id",
                  translationParams: {"id": widget.scooter.cloudScooterId.toString()}
                )),
                trailing: IconButton(
                  icon: const Icon(Icons.link_off),
                  onPressed: () async {
                    try {
                      await manager.unlinkScooterFromCloud(widget.scooter.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(FlutterI18n.translate(context, "cloud_unlink_success"))),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(FlutterI18n.translate(context, "cloud_unlink_error"))),
                      );
                    }
                  },
                ),
              )
            else
              ListTile(
                title: Text(FlutterI18n.translate(context, "cloud_scooter_not_linked")),
                subtitle: Text(FlutterI18n.translate(context, "cloud_scooter_not_linked_desc")),
                trailing: IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () {
                    // Navigate to cloud settings
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isActive) {
    final manager = Provider.of<ScooterManager>(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isActive)
          ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth_connected),
            label: Text(FlutterI18n.translate(context, "settings_connect")),
            onPressed: () async {
              try {
                await manager.setActiveScooter(widget.scooter.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(FlutterI18n.translate(
                      context, 
                      "settings_connect_success",
                      translationParams: {"name": widget.scooter.name}
                    ))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(FlutterI18n.translate(
                      context, 
                      "settings_connect_failed",
                      translationParams: {"name": widget.scooter.name}
                    ))),
                  );
                }
              }
            },
          ),
          
        ElevatedButton.icon(
          icon: const Icon(Icons.delete_outline),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          label: Text(FlutterI18n.translate(context, "settings_forget")),
          onPressed: () => _showForgetDialog(context),
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    final controller = TextEditingController(text: widget.scooter.name);
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(FlutterI18n.translate(context, "stats_name")),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: FlutterI18n.translate(context, "stats_name"),
            ),
          ),
          actions: [
            TextButton(
              child: Text(FlutterI18n.translate(context, "stats_rename_cancel")),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(FlutterI18n.translate(context, "stats_rename_save")),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  manager.renameSavedScooter(
                    id: widget.scooter.id,
                    name: controller.text,
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int selectedColor = widget.scooter.color;
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(FlutterI18n.translate(context, "settings_color")),
                  const SizedBox(height: 4),
                  Text(
                    FlutterI18n.translate(context, "settings_color_info"),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildColorOption(context, "black", 0, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    _buildColorOption(context, "white", 1, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    _buildColorOption(context, "green", 2, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    _buildColorOption(context, "gray", 3, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    _buildColorOption(context, "orange", 4, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    _buildColorOption(context, "red", 5, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    _buildColorOption(context, "blue", 6, selectedColor, (value) {
                      setState(() => selectedColor = value);
                    }),
                    // Special colors for easter eggs
                    if (_isSpecialName(widget.scooter.name, "Rpyvcfr"))
                      _buildColorOption(context, "eclipse", 7, selectedColor, (value) {
                        setState(() => selectedColor = value);
                      }),
                    if (_isSpecialName(widget.scooter.name, "Xbev"))
                      _buildColorOption(context, "idioteque", 8, selectedColor, (value) {
                        setState(() => selectedColor = value);
                      }),
                    if (_isSpecialName(widget.scooter.name, "Ubire"))
                      _buildColorOption(context, "hover", 9, selectedColor, (value) {
                        setState(() => selectedColor = value);
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(FlutterI18n.translate(context, "stats_rename_cancel")),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text(FlutterI18n.translate(context, "stats_rename_save")),
                  onPressed: () {
                    widget.scooter.color = selectedColor;
                    
                    // Mark color onboarding as completed
                    if (showColorOnboarding) {
                      prefs.setBool("color_onboarded", true);
                      setState(() {
                        showColorOnboarding = false;
                      });
                    }
                    
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    String colorName,
    int colorValue,
    int selectedValue,
    void Function(int) onChanged,
  ) {
    Color color;
    switch (colorValue) {
      case 0:
        color = Colors.black;
        break;
      case 1:
        color = Colors.white;
        break;
      case 2:
        color = Colors.green.shade900;
        break;
      case 3:
        color = Colors.grey;
        break;
      case 4:
        color = Colors.deepOrange.shade400;
        break;
      case 5:
        color = Colors.red;
        break;
      case 6:
        color = Colors.blue;
        break;
      case 7:
        color = Colors.grey.shade800;
        break;
      case 8:
        color = Colors.teal.shade200;
        break;
      case 9:
        color = Colors.lightBlue;
        break;
      default:
        color = Colors.black;
    }
    
    return RadioListTile<int>(
      title: Text(FlutterI18n.translate(context, "color_$colorName")),
      value: colorValue,
      groupValue: selectedValue,
      onChanged: (value) => onChanged(value!),
      secondary: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade500,
            width: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _showForgetDialog(BuildContext context) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(FlutterI18n.translate(context, "forget_alert_title")),
          content: Text(FlutterI18n.translate(context, "forget_alert_body")),
          actions: [
            TextButton(
              child: Text(FlutterI18n.translate(context, "forget_alert_cancel")),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(FlutterI18n.translate(context, "forget_alert_confirm")),
              onPressed: () async {
                final scooterName = widget.scooter.name;
                await manager.removeScooter(widget.scooter.id);
                
                if (mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to previous screen
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(FlutterI18n.translate(
                      context,
                      "forget_alert_success",
                      translationParams: {"name": scooterName},
                    ))),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  bool _isSpecialName(String name, String encoded) {
    return name == _rot13(encoded);
  }

  String _rot13(String input) {
    return input.split('').map((char) {
      if (RegExp(r'[a-z]').hasMatch(char)) {
        return String.fromCharCode(((char.codeUnitAt(0) - 97 + 13) % 26) + 97);
      } else if (RegExp(r'[A-Z]').hasMatch(char)) {
        return String.fromCharCode(((char.codeUnitAt(0) - 65 + 13) % 26) + 65);
      } else {
        return char;
      }
    }).join('');
  }
}
