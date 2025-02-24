import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/log_helper.dart';
import '../domain/scooter_keyless_distance.dart';
import '../domain/theme_helper.dart';
import '../models/scooter_manager.dart';
import 'support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final log = Logger('SettingsScreen');
  bool biometrics = false;
  bool autoUnlock = false;
  bool seasonal = true;
  ScooterKeylessDistance autoUnlockDistance = ScooterKeylessDistance.regular;
  bool openSeatOnUnlock = false;
  bool hazardLocking = false;
  bool osmConsent = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final manager = context.read<ScooterManager>();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      biometrics = prefs.getBool("biometrics") ?? false;
      autoUnlock = manager.autoUnlock;
      autoUnlockDistance = ScooterKeylessDistance.fromThreshold(manager.autoUnlockThreshold) ??
          ScooterKeylessDistance.regular;
      openSeatOnUnlock = manager.openSeatOnUnlock;
      hazardLocking = manager.hazardLocking;
      osmConsent = prefs.getBool("osmConsent") ?? true;
      seasonal = prefs.getBool("seasonal") ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "stats_settings_section_about")),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Scooter Settings
          _buildSectionHeader(FlutterI18n.translate(context, "stats_settings_section_scooter")),
          _buildScooterSettingsSection(),

          // App Settings
          _buildSectionHeader(FlutterI18n.translate(context, "stats_settings_section_app")),
          _buildAppSettingsSection(),

          // Cloud Settings
          _buildSectionHeader(FlutterI18n.translate(context, "stats_settings_section_cloud")),
          _buildCloudSettingsSection(),

          // About Section
          _buildSectionHeader(FlutterI18n.translate(context, "stats_settings_section_about")),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildScooterSettingsSection() {
    final manager = context.read<ScooterManager>();
    return Column(
      children: [
        SwitchListTile(
          title: Text(FlutterI18n.translate(context, "settings_auto_unlock")),
          subtitle: Text(FlutterI18n.translate(context, "settings_auto_unlock_description")),
          value: autoUnlock,
          onChanged: (value) {
            manager.setAutoUnlock(value);
            setState(() {
              autoUnlock = value;
            });
          },
        ),
        if (autoUnlock)
          ListTile(
            title: Text(
              "${FlutterI18n.translate(context, "settings_auto_unlock_threshold")}: ${autoUnlockDistance.name(context)}",
            ),
            subtitle: Slider(
              value: autoUnlockDistance.threshold.toDouble(),
              min: ScooterKeylessDistance.getMinThresholdDistance().threshold.toDouble(),
              max: ScooterKeylessDistance.getMaxThresholdDistance().threshold.toDouble(),
              divisions: ScooterKeylessDistance.values.length - 1,
              label: autoUnlockDistance.getFormattedThreshold(),
              onChanged: (threshold) {
                final distance = ScooterKeylessDistance.fromThreshold(threshold.toInt());
                manager.setAutoUnlockThreshold(threshold.toInt());
                setState(() {
                  autoUnlockDistance = distance;
                });
              },
            ),
          ),
        SwitchListTile(
          title: Text(FlutterI18n.translate(context, "settings_open_seat_on_unlock")),
          subtitle: Text(FlutterI18n.translate(context, "settings_open_seat_on_unlock_description")),
          value: openSeatOnUnlock,
          onChanged: (value) {
            manager.setOpenSeatOnUnlock(value);
            setState(() {
              openSeatOnUnlock = value;
            });
          },
        ),
        SwitchListTile(
          title: Text(FlutterI18n.translate(context, "settings_hazard_locking")),
          subtitle: Text(FlutterI18n.translate(context, "settings_hazard_locking_description")),
          value: hazardLocking,
          onChanged: (value) {
            manager.setHazardLocking(value);
            setState(() {
              hazardLocking = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAppSettingsSection() {
    return Column(
      children: [
        // Biometrics
        FutureBuilder<List<BiometricType>>(
          future: LocalAuthentication().getAvailableBiometrics(),
          builder: (context, biometricsOptionsSnap) {
            if (biometricsOptionsSnap.hasData && biometricsOptionsSnap.data!.isNotEmpty) {
              return SwitchListTile(
                title: Text(FlutterI18n.translate(context, "settings_biometrics")),
                subtitle: Text(FlutterI18n.translate(context, "settings_biometrics_description")),
                value: biometrics,
                onChanged: (value) async {
                  final LocalAuthentication auth = LocalAuthentication();
                  try {
                    final bool didAuthenticate = await auth.authenticate(
                      localizedReason: FlutterI18n.translate(context, "biometrics_message")
                    );
                    if (didAuthenticate) {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      prefs.setBool("biometrics", value);
                      setState(() {
                        biometrics = value;
                      });
                    } else {
                      Fluttertoast.showToast(
                        msg: FlutterI18n.translate(context, "biometrics_failed"),
                      );
                    }
                  } catch (e, stack) {
                    log.warning("Biometrics error", e, stack);
                    Fluttertoast.showToast(
                      msg: FlutterI18n.translate(context, "biometrics_failed"),
                    );
                  }
                },
              );
            }
            return Container();
          },
        ),

        // Theme
        ListTile(
          title: Text(FlutterI18n.translate(context, "settings_theme")),
          trailing: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(FlutterI18n.translate(context, "theme_light")),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(FlutterI18n.translate(context, "theme_dark")),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(FlutterI18n.translate(context, "theme_system")),
              ),
            ],
            selected: {EasyDynamicTheme.of(context).themeMode!},
            onSelectionChanged: (newTheme) {
              context.setThemeMode(newTheme.first);
            },
          ),
        ),

        // OSM Consent
        SwitchListTile(
          title: Text(FlutterI18n.translate(context, "settings_osm_consent")),
          subtitle: Text(FlutterI18n.translate(context, "settings_osm_consent_description")),
          value: osmConsent,
          onChanged: (value) async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("osmConsent", value);
            setState(() {
              osmConsent = value;
            });
          },
        ),

        // Seasonal Effects
        if (DateTime.now().month == 12)
          SwitchListTile(
            title: Text(FlutterI18n.translate(context, "settings_seasonal")),
            subtitle: Text(FlutterI18n.translate(context, "settings_color_info")),
            value: seasonal,
            onChanged: (value) async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setBool("seasonal", value);
              setState(() {
                seasonal = value;
              });
            },
          ),
      ],
    );
  }

  Widget _buildCloudSettingsSection() {
    return Column(
      children: [
        ListTile(
          title: Text(FlutterI18n.translate(context, "cloud_connect")),
          subtitle: Text(FlutterI18n.translate(context, "cloud_connect_desc")),
          onTap: () {
            // TODO: Implement cloud connection logic
            // This could open a dialog or navigate to a cloud connection screen
          },
        ),
        ListTile(
          title: Text(FlutterI18n.translate(context, "cloud_refresh")),
          subtitle: Text(FlutterI18n.translate(context, "cloud_refresh_desc")),
          onTap: () async {
            final manager = context.read<ScooterManager>();
            try {
              await manager.refreshCloudData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(FlutterI18n.translate(context, "cloud_refresh_desc"))),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(FlutterI18n.translate(context, "cloud_refresh_error"))),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      children: [
        // Support
        ListTile(
          title: Text(FlutterI18n.translate(context, "settings_support")),
          leading: const Icon(Icons.help_outline),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SupportScreen()),
            );
          },
        ),

        // Report an issue
        ListTile(
          title: Text(FlutterI18n.translate(context, "settings_report")),
          leading: const Icon(Icons.bug_report_outlined),
          onTap: () {
            LogHelper.startBugReport(context);
          },
        ),

        // Privacy Policy
        ListTile(
          title: Text(FlutterI18n.translate(context, "settings_privacy_policy")),
          leading: const Icon(Icons.privacy_tip_outlined),
          onTap: () {
            launchUrl(Uri.parse("https://unumotors.com/de-de/privacy-policy-of-unu-app/"));
          },
        ),

        // App Version
        FutureBuilder(
          future: PackageInfo.fromPlatform(),
          builder: (context, packageInfo) {
            return ListTile(
              title: Text(FlutterI18n.translate(context, "settings_app_version")),
              subtitle: Text(packageInfo.hasData
                  ? "${packageInfo.data!.version} (${packageInfo.data!.buildNumber})"
                  : "..."),
            );
          },
        ),

        // Licenses
        FutureBuilder(
          future: PackageInfo.fromPlatform(),
          builder: (context, packageInfo) {
            return ListTile(
              title: Text(FlutterI18n.translate(context, "settings_licenses")),
              leading: const Icon(Icons.code_rounded),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: packageInfo.hasData
                      ? packageInfo.data!.appName
                      : "Unustasis",
                  applicationVersion: packageInfo.hasData
                      ? packageInfo.data!.version
                      : "?.?.?",
                );
              },
            );
          },
        ),
      ],
    );
  }
}