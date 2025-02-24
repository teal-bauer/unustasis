import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';

import '../domain/format_utils.dart';
import '../domain/scooter_state.dart';
import '../models/scooter.dart';
import '../models/scooter_manager.dart';

class ScooterDetailsScreen extends StatefulWidget {
  final Scooter scooter;
  
  const ScooterDetailsScreen({
    Key? key,
    required this.scooter,
  }) : super(key: key);

  @override
  State<ScooterDetailsScreen> createState() => _ScooterDetailsScreenState();
}

class _ScooterDetailsScreenState extends State<ScooterDetailsScreen> {
  final log = Logger('ScooterDetailsScreen');
  
  // UI state
  bool _isEditing = false;
  bool _isCloudLinking = false;
  
  // Controllers
  late TextEditingController _nameController;
  int _selectedColor = 1;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.scooter.name);
    _selectedColor = widget.scooter.color;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? FlutterI18n.translate(context, 'edit_scooter')
              : widget.scooter.name,
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: FlutterI18n.translate(context, 'edit'),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: FlutterI18n.translate(context, 'save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scooter visualization card
            _buildScooterCard(),
            
            const SizedBox(height: 24),
            
            // Edit mode or display mode
            _isEditing ? _buildEditForm() : _buildDetailsSections(),
            
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScooterCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Scooter image
            SizedBox(
              width: 120,
              child: Image.asset(
                "images/scooter/side_${_isEditing ? _selectedColor : widget.scooter.color}.webp",
                fit: BoxFit.contain,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Scooter details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditing)
                    TextField(
                      controller: _nameController,
                      style: Theme.of(context).textTheme.titleLarge,
                      decoration: InputDecoration(
                        labelText: FlutterI18n.translate(context, 'scooter_name'),
                        border: const OutlineInputBorder(),
                      ),
                    )
                  else
                    Text(
                      widget.scooter.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  _buildConnectionIndicators(),
                  
                  if (widget.scooter.state != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.scooter.state!.name(context),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  
                  if (widget.scooter.primarySOC != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.scooter.calculateRange()} km ${FlutterI18n.translate(context, "stats_total_range")}',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionIndicators() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // BLE indicator
        Chip(
          avatar: Icon(
            widget.scooter.bleConnected 
                ? Icons.bluetooth_connected 
                : Icons.bluetooth,
            size: 16,
            color: widget.scooter.bleConnected 
                ? Theme.of(context).colorScheme.onPrimary 
                : null,
          ),
          label: Text(
            FlutterI18n.translate(
              context,
              widget.scooter.bleConnected 
                  ? 'ble_connected' 
                  : 'ble_disconnected'
            ),
          ),
          backgroundColor: widget.scooter.bleConnected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.surfaceVariant,
          labelStyle: TextStyle(
            color: widget.scooter.bleConnected 
                ? Theme.of(context).colorScheme.onPrimary 
                : null,
          ),
        ),
        
        // Cloud indicator
        if (widget.scooter.cloudScooterId != null)
          Chip(
            avatar: Icon(
              widget.scooter.cloudConnected 
                  ? Icons.cloud_done 
                  : Icons.cloud,
              size: 16,
              color: widget.scooter.cloudConnected 
                  ? Theme.of(context).colorScheme.onPrimary 
                  : null,
            ),
            label: Text(
              FlutterI18n.translate(
                context,
                widget.scooter.cloudConnected 
                    ? 'cloud_connected' 
                    : 'cloud_disconnected'
              ),
            ),
            backgroundColor: widget.scooter.cloudConnected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.surfaceVariant,
            labelStyle: TextStyle(
              color: widget.scooter.cloudConnected 
                  ? Theme.of(context).colorScheme.onPrimary 
                  : null,
            ),
          ),
      ],
    );
  }
  
  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FlutterI18n.translate(context, 'scooter_color'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        
        // Color selection
        SizedBox(
          height: 120,
          child: _buildColorSelection(),
        ),
        
        const SizedBox(height: 16),
        
        // Auto-connect option
        SwitchListTile(
          title: Text(FlutterI18n.translate(context, 'stats_scooter_auto_connect')),
          subtitle: Text(widget.scooter.autoConnect
            ? FlutterI18n.translate(context, 'stats_scooter_auto_connect_on_description')
            : FlutterI18n.translate(context, 'stats_scooter_auto_connect_off_description')),
          value: widget.scooter.autoConnect,
          onChanged: (value) {
            final manager = Provider.of<ScooterManager>(context, listen: false);
            widget.scooter.autoConnect = value;
          },
        ),
      ],
    );
  }
  
  Widget _buildDetailsSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic info section
        _buildSection(
          title: FlutterI18n.translate(context, 'basic_info'),
          children: [
            _buildInfoItem(
              icon: Icons.info_outline,
              label: FlutterI18n.translate(context, 'scooter_id'),
              value: widget.scooter.id,
              copyable: true,
            ),
            
            if (widget.scooter.cloudScooterId != null)
              _buildInfoItem(
                icon: Icons.cloud_outlined,
                label: FlutterI18n.translate(context, 'cloud_id'),
                value: widget.scooter.cloudScooterId.toString(),
                copyable: true,
              ),
              
            _buildInfoItem(
              icon: Icons.bluetooth,
              label: FlutterI18n.translate(context, 'stats_scooter_auto_connect'),
              value: widget.scooter.autoConnect
                ? FlutterI18n.translate(context, 'enabled')
                : FlutterI18n.translate(context, 'disabled'),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Connection info section
        _buildSection(
          title: FlutterI18n.translate(context, 'connection_info'),
          children: [
            if (widget.scooter.lastBleConnect != null)
              _buildInfoItem(
                icon: Icons.access_time,
                label: FlutterI18n.translate(context, 'last_ble_connection'),
                value: FormatUtils.formatLastSeen(
                  widget.scooter.lastBleConnect!.toIso8601String()
                ),
              ),
              
            if (widget.scooter.lastCloudSync != null)
              _buildInfoItem(
                icon: Icons.cloud_sync,
                label: FlutterI18n.translate(context, 'last_cloud_sync'),
                value: FormatUtils.formatLastSeen(
                  widget.scooter.lastCloudSync!.toIso8601String()
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Battery status section (if available)
        if (widget.scooter.primarySOC != null || widget.scooter.secondarySOC != null)
          _buildSection(
            title: FlutterI18n.translate(context, 'battery_status'),
            children: [
              if (widget.scooter.primarySOC != null)
                _buildBatteryItem(
                  label: FlutterI18n.translate(context, 'stats_primary_name'),
                  value: widget.scooter.primarySOC!,
                  cycles: widget.scooter.primaryCycles,
                ),
                
              if (widget.scooter.secondarySOC != null && widget.scooter.secondarySOC! > 0)
                _buildBatteryItem(
                  label: FlutterI18n.translate(context, 'stats_secondary_name'),
                  value: widget.scooter.secondarySOC!,
                  cycles: widget.scooter.secondaryCycles,
                ),
                
              if (widget.scooter.cbbSOC != null)
                _buildBatteryItem(
                  label: FlutterI18n.translate(context, 'stats_cbb_name'),
                  value: widget.scooter.cbbSOC!,
                  showBar: false,
                ),
                
              if (widget.scooter.auxSOC != null)
                _buildBatteryItem(
                  label: FlutterI18n.translate(context, 'stats_aux_name'),
                  value: widget.scooter.auxSOC!,
                  showBar: false,
                ),
            ],
          ),
          
        const SizedBox(height: 16),
        
        // Location section
        if (widget.scooter.lastLocation != null)
          _buildSection(
            title: FlutterI18n.translate(context, 'stats_location'),
            children: [
              _buildInfoItem(
                icon: Icons.location_on_outlined,
                label: FlutterI18n.translate(context, 'stats_last_seen_near'),
                value: '${widget.scooter.lastLocation!.latitude}, ${widget.scooter.lastLocation!.longitude}',
                onTap: () {
                  MapsLauncher.launchCoordinates(
                    widget.scooter.lastLocation!.latitude,
                    widget.scooter.lastLocation!.longitude,
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
  
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onTap,
                  child: Row(
                    children: [
                      Expanded(child: Text(value)),
                      if (copyable)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: value));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                FlutterI18n.translate(context, 'copied_to_clipboard')
                              )),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (onTap != null)
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBatteryItem({
    required String label,
    required int value,
    int? cycles,
    bool showBar = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$value%',
                style: TextStyle(
                  color: value <= 15 
                      ? Theme.of(context).colorScheme.error 
                      : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (cycles != null) ...[
                const SizedBox(width: 8),
                Text(
                  '(${cycles.toString()} ${FlutterI18n.translate(context, 'cycles')})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              color: value <= 15 
                  ? Theme.of(context).colorScheme.error 
                  : Theme.of(context).colorScheme.primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    final manager = Provider.of<ScooterManager>(context);
    final bool isActiveScooter = manager.activeScooterId == widget.scooter.id;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connect button (if not active)
        if (!isActiveScooter)
          ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth_connected),
            label: Text(FlutterI18n.translate(context, 'connect_to_scooter')),
            onPressed: () {
              manager.setActiveScooter(widget.scooter.id);
              Navigator.of(context).pop();
            },
          ),
          
        const SizedBox(height: 16),
        
        // Cloud link/unlink button
        FutureBuilder<bool>(
          future: manager.isCloudAuthenticated(),
          builder: (context, snapshot) {
            final bool isCloudAuthenticated = snapshot.data == true;
            
            if (widget.scooter.cloudScooterId != null) {
              // Unlink option
              return OutlinedButton.icon(
                icon: const Icon(Icons.link_off),
                label: Text(FlutterI18n.translate(context, 'unlink_from_cloud')),
                onPressed: _isCloudLinking 
                    ? null 
                    : () => _unlinkFromCloud(manager),
              );
            } else if (isCloudAuthenticated) {
              // Link option
              return OutlinedButton.icon(
                icon: const Icon(Icons.cloud_sync),
                label: Text(FlutterI18n.translate(context, 'link_to_cloud')),
                onPressed: _isCloudLinking 
                    ? null 
                    : () => _linkToCloud(manager),
              );
            } else {
              // Disabled link option
              return OutlinedButton.icon(
                icon: const Icon(Icons.cloud_off),
                label: Text(FlutterI18n.translate(context, 'cloud_not_connected')),
                onPressed: null,
              );
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Forget/delete button
        TextButton.icon(
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          label: Text(
            FlutterI18n.translate(context, 'forget_scooter'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          onPressed: () => _forgetScooter(manager),
        ),
      ],
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
                  width: 50,
                  height: 50,
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
  
  void _saveChanges() {
    widget.scooter.name = _nameController.text;
    widget.scooter.color = _selectedColor;
    
    setState(() {
      _isEditing = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        FlutterI18n.translate(context, 'changes_saved')
      )),
    );
  }
  
  Future<void> _linkToCloud(ScooterManager manager) async {
    setState(() {
      _isCloudLinking = true;
    });
    
    try {
      // Show scooter selection dialog
      final cloudScooters = await manager.getCloudScooters();
      
      if (!mounted) return;
      
      // Filter out scooters that are already linked
      final linkedCloudIds = manager.scooters.values
          .where((s) => s.cloudScooterId != null)
          .map((s) => s.cloudScooterId)
          .toList();
      
      final availableScooters = cloudScooters
          .where((s) => !linkedCloudIds.contains(s['id']))
          .toList();
      
      if (availableScooters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            FlutterI18n.translate(context, 'all_cloud_scooters_linked')
          )),
        );
        return;
      }
      
      final selectedScooter = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _buildCloudScooterDialog(availableScooters),
      );
      
      if (selectedScooter != null && mounted) {
        // Link the scooter
        await manager.linkScooterToCloud(
          scooterId: widget.scooter.id,
          cloudScooterId: selectedScooter['id'],
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            FlutterI18n.translate(
              context, 
              'cloud_assignment_success',
              translationParams: {'name': selectedScooter['name']},
            ),
          )),
        );
      }
    } catch (e, stack) {
      log.severe('Error linking to cloud', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            FlutterI18n.translate(
              context, 
              'cloud_assignment_error',
              translationParams: {'error': e.toString()},
            ),
          )),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCloudLinking = false;
        });
      }
    }
  }
  
  Future<void> _unlinkFromCloud(ScooterManager manager) async {
    setState(() {
      _isCloudLinking = true;
    });
    
    try {
      await manager.unlinkScooterFromCloud(widget.scooter.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            FlutterI18n.translate(context, 'unlinked_from_cloud')
          )),
        );
      }
    } catch (e, stack) {
      log.severe('Error unlinking from cloud', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            FlutterI18n.translate(
              context, 
              'cloud_unlink_error',
              translationParams: {'error': e.toString()},
            ),
          )),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCloudLinking = false;
        });
      }
    }
  }
  
  Future<void> _forgetScooter(ScooterManager manager) async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(FlutterI18n.translate(context, 'forget_alert_title')),
        content: Text(FlutterI18n.translate(context, 'forget_alert_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(FlutterI18n.translate(context, 'forget_alert_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(FlutterI18n.translate(context, 'forget_alert_confirm')),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm && mounted) {
      await manager.removeScooter(widget.scooter.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          FlutterI18n.translate(
            context, 
            'forget_alert_success',
            translationParams: {'name': widget.scooter.name},
          ),
        )),
      );
      
      Navigator.of(context).pop();
    }
  }
  
  Widget _buildCloudScooterDialog(List<Map<String, dynamic>> scooters) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, 'select_cloud_scooter'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: scooters.length,
                itemBuilder: (context, index) {
                  final scooter = scooters[index];
                  return ListTile(
                    leading: Image.asset(
                      "images/scooter/side_${scooter['color_id'] ?? 1}.webp",
                      height: 40,
                    ),
                    title: Text(scooter['name'] ?? 'Unknown'),
                    subtitle: Text(
                      FlutterI18n.translate(
                        context, 
                        'last_seen',
                        translationParams: {
                          'time': FormatUtils.formatLastSeen(scooter['last_seen_at']),
                        },
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(scooter),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(FlutterI18n.translate(context, 'cancel')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}