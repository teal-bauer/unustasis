import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../command_service.dart';
import '../domain/scooter_state.dart';
import '../domain/theme_helper.dart';
import '../helper_widgets/snowfall.dart';
import '../models/scooter.dart';
import '../models/scooter_manager.dart';
import '../scooter_service.dart';
import '../widgets/battery_bars.dart';
import '../widgets/scooter_action_button.dart';
import '../widgets/scooter_power_button.dart';
import '../widgets/scooter_selection_dialog.dart';
import '../widgets/scooter_visual.dart';
import '../widgets/seat_button.dart';
import '../widgets/status_text.dart';
import 'add_scooter_screen.dart';
import 'control_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool? forceOpen;
  
  const HomeScreen({
    this.forceOpen,
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final log = Logger('HomeScreen');
  bool _hazards = false;
  bool _snowing = false;

  @override
  void initState() {
    super.initState();
    if (widget.forceOpen != true) {
      log.fine("Redirecting or starting");
      _redirectOrStart();
    }
    _startSeasonal();
  }

  Future<void> _startSeasonal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool("seasonal") ?? true) {
      switch (DateTime.now().month) {
        case 12:
          // December, snow season!
          setState(() {
            _snowing = true;
          });
          break;
        // who knows what else might be in the future?
      }
    }
  }

  void _flashHazards(int times) async {
    setState(() {
      _hazards = true;
    });
    await Future.delayed(Duration(milliseconds: 600 * times));
    setState(() {
      _hazards = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final activeScooter = manager.activeScooter;
    
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDarkMode
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Color.fromARGB(255, 20, 20, 20))
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.white),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              StateCircle(
                connected: manager.connected,
                scooterState: activeScooter?.state,
                scanning: manager.scanning,
              ),
              
              // Optional seasonal effects
              if (_snowing)
                SnowfallBackground(
                  backgroundColor: Colors.transparent,
                  snowflakeColor: context.isDarkMode
                      ? Colors.white.withValues(alpha: .15)
                      : Colors.black.withValues(alpha: .05),
                ),
              
              // Main content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Top bar with scooter name and additional buttons
                      _buildTopBar(context, activeScooter),
                      
                      // Status text
                      const StatusText(),
                      
                      const SizedBox(height: 16),
                      
                      // Battery indicators
                      if (activeScooter?.primarySOC != null)
                        const BatteryBars(),
                      
                      const SizedBox(height: 16),
                      
                      // Scooter visual
                      Expanded(
                        child: ScooterVisual(
                          color: activeScooter?.color ?? 1,
                          state: activeScooter?.state,
                          scanning: manager.scanning,
                          blinkerLeft: _hazards,
                          blinkerRight: _hazards,
                          winter: _snowing,
                        ),
                      ),
                      
                      // Reconnect button if disconnected
                      if (activeScooter == null || !manager.connected)
                        ScooterActionButton(
                          onPressed: () => manager.attemptToConnectToActiveScooter(),
                          icon: Icons.refresh_rounded,
                          label: FlutterI18n.translate(context, "home_reconnect_button"),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Main action buttons
                      _buildActionButtons(context, activeScooter),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Scooter? activeScooter) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scooter selector button
        IconButton(
          icon: const Icon(Icons.electric_scooter),
          onPressed: () => _showScooterSelectionDialog(context),
          tooltip: FlutterI18n.translate(context, 'switch_scooter'),
        ),
        
        const SizedBox(width: 8),
        
        // Scooter name with info screen link
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToStats(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  activeScooter?.name ?? 
                      FlutterI18n.translate(context, "stats_no_name"),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _navigateToSettings(context),
          tooltip: FlutterI18n.translate(context, 'settings'),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Scooter? activeScooter) {
    final manager = Provider.of<ScooterManager>(context);
    final bool connected = manager.connected;
    final scooterState = activeScooter?.state;
    
    // If no scooters are added yet, show a big "Add Scooter" button
    if (activeScooter == null) {
      return ElevatedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddScooterScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(
          FlutterI18n.translate(context, "settings_add_scooter"),
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      );
    }
    
    // Regular action buttons for connected scooters
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: [
        // Seat button
        SeatButton(
          onPressed: () => _handleSeatButtonPress(context),
          seatClosed: activeScooter.seatClosed,
          state: activeScooter.state,
        ),
        
        // Power button (lock/unlock)
        Expanded(
          child: ScooterPowerButton(
            action: scooterState?.isReadyForLockChange == true
                ? () => _handlePowerButtonPress(context, scooterState)
                : null,
            icon: scooterState?.isOn == true
                ? Icons.lock_open
                : Icons.lock_outline,
            label: scooterState?.isOn == true
                ? FlutterI18n.translate(context, "home_lock_button")
                : FlutterI18n.translate(context, "home_unlock_button"),
          ),
        ),
        
        // Controls button
        Expanded(
          child: ScooterActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ControlScreen()),
            ),
            icon: Icons.more_vert_rounded,
            label: FlutterI18n.translate(context, "home_controls_button"),
          ),
        ),
      ],
    );
  }

  void _showScooterSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ScooterSelectionDialog(),
    );
  }

  void _navigateToStats(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StatsScreen()),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _handleSeatButtonPress(BuildContext context) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    try {
      await manager.executeCommand(
        CommandType.openSeat,
        onNeedConfirmation: () => _showCloudConfirmationDialog(context),
      );
    } catch (e, stack) {
      log.severe("Problem opening the seat", e, stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handlePowerButtonPress(BuildContext context, ScooterState? state) async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    if (state == null || !state.isReadyForLockChange) return;

    try {
      if (state.isOn) {
        // Lock flow
        await manager.executeCommand(
          CommandType.lock,
          onNeedConfirmation: () => _showCloudConfirmationDialog(context),
        );

        if (manager.hazardLocking) {
          _flashHazards(1);
        }
      } else if (state == ScooterState.standby) {
        // Unlock flow
        await manager.executeCommand(
          CommandType.unlock,
          onNeedConfirmation: () => _showCloudConfirmationDialog(context),
        );

        if (manager.hazardLocking) {
          _flashHazards(2);
        }
      } else {
        // Wake up flow
        await manager.executeCommand(CommandType.wakeUp);
        // Wait for standby state
        await Future.delayed(const Duration(seconds: 5));
        await manager.executeCommand(
          CommandType.unlock,
          onNeedConfirmation: () => _showCloudConfirmationDialog(context),
        );
      }
    } on SeatOpenException catch (_) {
      log.warning("Seat is open, showing alert");
      _showSeatWarning(context);
    } on HandlebarLockException catch (_) {
      log.warning("Handlebars issue, showing alert");
      _showHandlebarWarning(
        context,
        didNotUnlock: state.isOn, // true if we were trying to unlock
      );
    } catch (e, stack) {
      log.severe("Power button action failed", e, stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<bool> _showCloudConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          FlutterI18n.translate(context, "cloud_command_confirm_title"),
        ),
        content: Text(
          FlutterI18n.translate(context, "cloud_command_confirm_body"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              FlutterI18n.translate(context, "cloud_command_confirm_cancel"),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              FlutterI18n.translate(context, "cloud_command_confirm_confirm"),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSeatWarning(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(FlutterI18n.translate(context, "seat_alert_title")),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(FlutterI18n.translate(context, "seat_alert_body")),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showHandlebarWarning(BuildContext context, {required bool didNotUnlock}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                "assets/anim/handlebars.png",  // Converted from Lottie to static image for simplicity
                height: 160,
              ),
              const SizedBox(height: 24),
              Text(FlutterI18n.translate(
                context,
                "${didNotUnlock ? "locked" : "unlocked"}_handlebar_alert_title"
              )),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(FlutterI18n.translate(
                  context,
                  "${didNotUnlock ? "locked" : "unlocked"}_handlebar_alert_body"
                )),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(FlutterI18n.translate(
                context,
                "${didNotUnlock ? "locked" : "unlocked"}_handlebar_alert_action"
              )),
              onPressed: () {
                final manager = Provider.of<ScooterManager>(context, listen: false);
                if (didNotUnlock) {
                  manager.executeCommand(
                    CommandType.lock,
                    onNeedConfirmation: () => _showCloudConfirmationDialog(context),
                  );
                } else {
                  manager.executeCommand(
                    CommandType.unlock,
                    onNeedConfirmation: () => _showCloudConfirmationDialog(context),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _redirectOrStart() async {
    final manager = Provider.of<ScooterManager>(context, listen: false);
    
    // If there are no scooters, show onboarding
    if (manager.scooters.isEmpty) {
      FlutterNativeSplash.remove();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingScreen(),
        ),
      );
      return;
    }
    
    // Otherwise try to connect to active scooter
    manager.attemptToConnectToActiveScooter();
    
    // Handle biometric authentication if needed
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool("biometrics") ?? false) && mounted) {
      manager.optionalAuth = false;
      final LocalAuthentication auth = LocalAuthentication();
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: FlutterI18n.translate(context, "biometrics_message"),
        );
        if (!didAuthenticate) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              FlutterI18n.translate(context, "biometrics_failed")
            )),
          );
          Navigator.of(context).pop();
          SystemNavigator.pop();
        } else {
          manager.optionalAuth = true;
        }
      } catch (e, stack) {
        log.info("Biometrics failed", e, stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            FlutterI18n.translate(context, "biometrics_failed")
          )),
        );
        Navigator.of(context).pop();
        SystemNavigator.pop();
      }
    } else {
      manager.optionalAuth = true;
    }
    
    FlutterNativeSplash.remove();
  }
}

// StateCircle is a visual component showing the background circle that changes
// based on the scooter's state
class StateCircle extends StatelessWidget {
  final bool scanning;
  final bool connected;
  final ScooterState? scooterState;

  const StateCircle({
    super.key,
    required this.scanning,
    required this.connected,
    required this.scooterState,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      scale: connected
          ? scooterState == ScooterState.parked
              ? 1.5
              : (scooterState == ScooterState.ready)
                  ? 3
                  : 1.2
          : scanning
              ? 1.5
              : 0,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: scooterState?.isOn == true
              ? context.isDarkMode
                  ? HSLColor.fromColor(Theme.of(context).colorScheme.primary)
                      .withLightness(0.18)
                      .toColor()
                  : HSLColor.fromColor(Theme.of(context).colorScheme.primary)
                      .withAlpha(0.3)
                      .toColor()
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainer
                  .withValues(alpha: context.isDarkMode ? 0.5 : 0.7),
        ),
      ),
    );
  }
}