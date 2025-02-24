import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scooter_manager.dart';
import '../screens/add_scooter_screen.dart';
import '../screens/scooter_settings_screen.dart';
import '../widgets/scooter_card.dart';

class ScooterSection extends StatefulWidget {
  const ScooterSection({
    super.key,
    required this.dataIsOld,
  });

  final bool dataIsOld;

  @override
  State<ScooterSection> createState() => _ScooterSectionState();
}

class _ScooterSectionState extends State<ScooterSection> {
  int color = 1;
  String? nameCache;
  TextEditingController nameController = TextEditingController();
  FocusNode nameFocusNode = FocusNode();

  void setColor(int newColor) async {
    setState(() {
      color = newColor;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt("color", color);
  }

  void setupInitialColor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      color = prefs.getInt("color") ?? 1;
    });
  }

  @override
  void initState() {
    super.initState();
    setupInitialColor();
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final scooters = manager.scooters.values.toList();
    final activeScooterId = manager.activeScooterId;
    
    // Sort scooters: active first, then by most recently connected
    scooters.sort((a, b) {
      if (a.id == activeScooterId) return -1;
      if (b.id == activeScooterId) return 1;
      return b.lastConnection.compareTo(a.lastConnection);
    });
    
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      children: [
        // Scooter cards
        ...scooters.map((scooter) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ScooterCard(
              scooter: scooter,
              isActive: scooter.id == activeScooterId,
              showConnect: true,
              onTap: () {
                if (scooter.id != activeScooterId) {
                  manager.setActiveScooter(scooter.id);
                }
              },
              onSettings: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScooterSettingsScreen(scooter: scooter),
                  ),
                );
              },
            ),
          );
        }),
        
        // Add scooter button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddScooterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              FlutterI18n.translate(context, "settings_add_scooter"),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    nameFocusNode.dispose();
    super.dispose();
  }
}
