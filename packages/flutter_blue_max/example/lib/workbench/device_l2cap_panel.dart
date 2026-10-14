import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/workbench/l2cap_channel_card.dart';
import 'package:flutter_blue_max_example/workbench/payload_codec.dart';
import 'package:flutter_blue_max_example/workbench/workbench_card.dart';
import 'package:flutter_blue_max_example/workbench/workbench_controller.dart';

/// Opens outgoing channels only for the device shown in the inspector.
class DeviceL2capPanel extends StatefulWidget {
  const DeviceL2capPanel({super.key, required this.device, required this.controller});

  final BluetoothDevice device;
  final WorkbenchController controller;

  @override
  State<DeviceL2capPanel> createState() => _DeviceL2capPanelState();
}

class _DeviceL2capPanelState extends State<DeviceL2capPanel> {
  final _psm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _secure = true;

  @override
  void dispose() {
    _psm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final device = widget.device;
    final connected = device.isConnected;
    final sessions = c.channels.where((session) => !session.incoming && session.channel.deviceId == device.remoteId);
    final enabled = connected && c.ready && !c.busy('open') && !c.busy('connection');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkbenchCard(
          title: 'L2CAP to this device',
          icon: Icons.cable_rounded,
          subtitle: 'A separate byte stream to ${c.nameOf(device)} over the Bluetooth connection.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!connected)
                const Text('Connect this device above to open an L2CAP channel.')
              else
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('The device must run an L2CAP server. Enter the PSM supplied by that server.'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _psm,
                        enabled: enabled,
                        decoration: const InputDecoration(
                          labelText: 'Remote PSM',
                          hintText: 'Decimal or 0x hexadecimal',
                        ),
                        validator: (value) {
                          try {
                            PayloadCodec.psm(value ?? '');
                          } on FormatException catch (error) {
                            return error.message;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      if (defaultTargetPlatform == TargetPlatform.android)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Require encryption'),
                          value: _secure,
                          onChanged: enabled ? (value) => setState(() => _secure = value) : null,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('On Apple devices, encryption is determined by the remote server.'),
                        ),
                      FilledButton.icon(
                        onPressed: enabled
                            ? () {
                                if (_form.currentState!.validate()) {
                                  c.openChannel(PayloadCodec.psm(_psm.text), device: device, secure: _secure);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.link_rounded),
                        label: Text(c.busy('open') ? 'Opening…' : 'Open channel'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'GATT services do not imply L2CAP support. Discovering GATT services is optional for this channel, '
                'unless the device uses a characteristic to share its PSM. Android requires version 10 or newer.',
              ),
            ],
          ),
        ),
        if (sessions.isEmpty && connected)
          const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('No L2CAP channel open to this device yet.')),
        for (final session in sessions) L2capChannelCard(key: ValueKey(session.key), session: session, controller: c),
      ],
    );
  }
}
