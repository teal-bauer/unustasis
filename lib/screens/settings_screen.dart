import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../stats/settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "settings_title")),
      ),
      body: const SettingsSection(),
    );
  }
}
