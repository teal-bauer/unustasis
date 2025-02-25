import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/scooter_manager.dart';
import '../cloud_service.dart';
import 'ble_scooter_selection_screen.dart';
import 'settings_screen.dart';

class AddScooterScreen extends StatefulWidget {
  const AddScooterScreen({super.key});

  @override
  State<AddScooterScreen> createState() => _AddScooterScreenState();
}

class _AddScooterScreenState extends State<AddScooterScreen> {
  bool _isSearching = false;
  bool _isCloudLoading = false;
  bool _isCloudAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkCloudStatus();
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

  void _startBleSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BleScooterSelectionScreen()),
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
                          Navigator.pop(context); // Return to previous screen
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

  void _showCloudLogin() {
    showDialog(
      context: context,
      builder: (context) => _buildCloudTokenDialog(context),
    );
  }

  Widget _buildCloudTokenDialog(BuildContext context) {
    final TextEditingController tokenController = TextEditingController();
    final manager = Provider.of<ScooterManager>(context, listen: false);
    final cloudService = CloudService(manager);
    
    return AlertDialog(
      title: Text(FlutterI18n.translate(context, "cloud_token_title")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(FlutterI18n.translate(context, "cloud_token_cancel")),
        ),
        TextButton(
          onPressed: () async {
            final token = tokenController.text.trim();
            if (token.isEmpty) return;
            
            try {
              await cloudService.setToken(token);
              if (mounted) {
                Navigator.pop(context);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "add_scooter_title")),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Text(
                FlutterI18n.translate(context, "add_scooter_header"),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                FlutterI18n.translate(context, "add_scooter_description"),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // BLE Search button
              ElevatedButton.icon(
                onPressed: _isSearching ? null : _startBleSearch,
                icon: _isSearching 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
                label: Text(
                  _isSearching
                    ? FlutterI18n.translate(context, "add_scooter_searching")
                    : FlutterI18n.translate(context, "add_scooter_search"),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  minimumSize: const Size(double.infinity, 60),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              
              // Cloud button
              ElevatedButton.icon(
                onPressed: _isCloudLoading 
                  ? null 
                  : (_isCloudAuthenticated ? _showCloudScooters : _showCloudLogin),
                icon: _isCloudLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud),
                label: Text(
                  _isCloudLoading
                    ? FlutterI18n.translate(context, "add_scooter_cloud_loading")
                    : (_isCloudAuthenticated
                        ? FlutterI18n.translate(context, "add_scooter_cloud")
                        : FlutterI18n.translate(context, "add_scooter_cloud_login")),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  minimumSize: const Size(double.infinity, 60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
