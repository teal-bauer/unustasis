import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import '../cloud_service.dart';

class ScooterSettingsScreen extends StatefulWidget {
  final Scooter scooter;

  const ScooterSettingsScreen({
    required this.scooter,
    super.key,
  });

  @override
  State<ScooterSettingsScreen> createState() => _ScooterSettingsScreenState();
}

class _ScooterSettingsScreenState extends State<ScooterSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColor = 1;
  bool _autoConnect = true;
  Map<String, dynamic>? _cloudScooterData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.scooter.name;
    _selectedColor = widget.scooter.color;
    _autoConnect = widget.scooter.autoConnect;
    _loadCloudData();
  }

  Future<void> _loadCloudData() async {
    if (widget.scooter.cloudScooterId != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final manager = Provider.of<ScooterManager>(context, listen: false);
        final cloudScooters = await manager.getCloudScooters();
        final cloudScooter = cloudScooters.firstWhere(
          (s) => s['id'] == widget.scooter.cloudScooterId,
          orElse: () => throw Exception("Cloud scooter not found"),
        );

        setState(() {
          _cloudScooterData = cloudScooter;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final isActive = manager.activeScooterId == widget.scooter.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "scooter_settings_title")),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scooter image
          Center(
            child: Image.asset(
              "images/scooter/side_${widget.scooter.color}.webp",
              height: 160,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Scooter name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: FlutterI18n.translate(context, "scooter_name"),
              border: const OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Color selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FlutterI18n.translate(context, "scooter_color"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildColorOption(context, 0, "black"),
                      _buildColorOption(context, 1, "white"),
                      _buildColorOption(context, 2, "green"),
                      _buildColorOption(context, 3, "gray"),
                      _buildColorOption(context, 4, "orange"),
                      _buildColorOption(context, 5, "red"),
                      _buildColorOption(context, 6, "blue"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Auto-connect toggle
          SwitchListTile(
            title: Text(FlutterI18n.translate(context, "scooter_auto_connect")),
            subtitle: Text(FlutterI18n.translate(context, "scooter_auto_connect_description")),
            value: _autoConnect,
            onChanged: (value) {
              setState(() {
                _autoConnect = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Cloud connection section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FlutterI18n.translate(context, "cloud_connection"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (widget.scooter.cloudScooterId != null && _cloudScooterData != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(FlutterI18n.translate(context, "cloud_scooter_name")),
                          subtitle: Text(_cloudScooterData!['name'] ?? 'Unknown'),
                          leading: const Icon(Icons.cloud_done),
                        ),
                        ListTile(
                          title: Text(FlutterI18n.translate(context, "cloud_scooter_id")),
                          subtitle: Text(widget.scooter.cloudScooterId.toString()),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: Text(FlutterI18n.translate(context, "cloud_open_dashboard")),
                          onPressed: () async {
                            final Uri url = Uri.parse(
                              'https://sunshine.rescoot.org/scooters/${widget.scooter.cloudScooterId}',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.link_off),
                          label: Text(FlutterI18n.translate(context, "cloud_unlink")),
                          onPressed: () => _unlinkFromCloud(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(FlutterI18n.translate(context, "cloud_not_linked")),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_upload),
                          label: Text(FlutterI18n.translate(context, "cloud_link_scooter")),
                          onPressed: () => _showCloudLinkDialog(context),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Save button
          ElevatedButton(
            onPressed: () => _saveChanges(context),
            child: Text(FlutterI18n.translate(context, "save_changes")),
          ),
          
          const SizedBox(height: 16),
          
          // Forget scooter button
          TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(FlutterI18n.translate(context, "forget_scooter")),
            onPressed: () => _showForgetDialog(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, int colorValue, String colorName) {
    final bool isSelected = _selectedColor == colorValue;
    
    // Get color based on colorValue
    Color color;
    switch (colorValue) {
      case 0: color = Colors.black;
      case 1: color = Colors.white;
      case 2: color = Colors.green.shade900;
      case 3: color = Colors.grey;
      case 4: color = Colors.deepOrange.shade400;
      case 5: color = Colors.red;
      case 6: color = Colors.blue;
      default: color = Colors.grey;
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedColor = colorValue;
        });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              )
            : null,
      ),
    );
  }

  Future<void> _saveChanges(BuildContext context) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    // Update scooter name if changed
    if (_nameController.text != widget.scooter.name) {
      await manager.renameSavedScooter(
        id: widget.scooter.id,
        name: _nameController.text,
      );
    }
    
    // Update color if changed
    if (_selectedColor != widget.scooter.color) {
      widget.scooter.color = _selectedColor;
    }
    
    // Update auto-connect if changed
    if (_autoConnect != widget.scooter.autoConnect) {
      widget.scooter.autoConnect = _autoConnect;
    }
    
    Navigator.of(context).pop();
  }

  Future<void> _showForgetDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, "forget_scooter_title")),
        content: Text(FlutterI18n.translate(context, "forget_scooter_message")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(FlutterI18n.translate(context, "cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              FlutterI18n.translate(context, "forget"),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final manager = Provider.of<ScooterManager>(context, listen: false);
      await manager.removeScooter(widget.scooter.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showCloudLinkDialog(BuildContext context) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    // Check if authenticated
    final isAuthenticated = await manager.isCloudAuthenticated();
    if (!isAuthenticated && mounted) {
      // Show authentication dialog
      final token = await _showCloudAuthDialog(context);
      if (token == null) return;
      
      final success = await manager.authenticateCloud(token);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FlutterI18n.translate(context, "cloud_auth_failed"))),
        );
        return;
      }
    }
    
    if (!mounted) return;
    
    // Show cloud scooter selection dialog
    final cloudScooters = await manager.getCloudScooters();
    if (!mounted) return;
    
    if (cloudScooters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FlutterI18n.translate(context, "cloud_no_scooters"))),
      );
      return;
    }
    
    final selectedCloudScooter = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, "cloud_select_scooter")),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cloudScooters.length,
            itemBuilder: (context, index) {
              final scooter = cloudScooters[index];
              return ListTile(
                title: Text(scooter['name'] ?? 'Unknown'),
                subtitle: Text('ID: ${scooter['id']}'),
                onTap: () => Navigator.of(context).pop(scooter),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(FlutterI18n.translate(context, "cancel")),
          ),
        ],
      ),
    );
    
    if (selectedCloudScooter != null && mounted) {
      try {
        await manager.linkScooterToCloud(
          scooterId: widget.scooter.id,
          cloudScooterId: selectedCloudScooter['id'],
        );
        
        // Reload cloud data
        await _loadCloudData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FlutterI18n.translate(context, "cloud_link_failed"))),
          );
        }
      }
    }
  }

  Future<String?> _showCloudAuthDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, "cloud_auth_title")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(FlutterI18n.translate(context, "cloud_auth_message")),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: FlutterI18n.translate(context, "cloud_auth_token"),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(FlutterI18n.translate(context, "cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(FlutterI18n.translate(context, "authenticate")),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkFromCloud(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, "cloud_unlink_title")),
        content: Text(FlutterI18n.translate(context, "cloud_unlink_message")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(FlutterI18n.translate(context, "cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(FlutterI18n.translate(context, "unlink")),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final manager = Provider.of<ScooterManager>(context, listen: false);
      await manager.unlinkScooterFromCloud(widget.scooter.id);
      
      setState(() {
        _cloudScooterData = null;
      });
    }
  }
}
