import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import '../command_service.dart';
import '../domain/icomoon.dart';
import '../domain/scooter_state.dart';
import '../models/scooter_manager.dart';
import 'scooter_action_button.dart';

class SeatButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool? seatClosed;
  final ScooterState? state;

  const SeatButton({
    Key? key,
    this.onPressed,
    this.seatClosed,
    this.state,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ScooterManager>(context);
    final bool enabled = (state != null && seatClosed == true && state!.isReadyForSeatOpen == true);

    return Expanded(
      child: FutureBuilder<bool>(
        future: manager.isCommandAvailable(CommandType.openSeat),
        builder: (context, snapshot) {
          return ScooterActionButton(
            onPressed: enabled ? onPressed : null,
            label: seatClosed == false
                ? FlutterI18n.translate(context, "home_seat_button_open")
                : FlutterI18n.translate(context, "home_seat_button_closed"),
            icon: seatClosed == false ? Icomoon.seat_open : Icomoon.seat_closed,
            iconColor: seatClosed == false ? Theme.of(context).colorScheme.error : null,
          );
        },
      ),
    );
  }
}
