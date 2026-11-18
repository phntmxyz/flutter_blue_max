import 'package:context_plus/context_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_bindings.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/l2cap/l2cap_channel_card.dart';
import 'package:flutter_blue_max_example/l2cap/psm.dart';
import 'package:flutter_blue_max_example/shared/workbench_card.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// L2CAP tab of the selected device inspector in `DevicesPanel`.
/// Opens outgoing channels only for the device shown in the inspector.
class const DeviceL2capPanel({super.key, required final BluetoothDevice device}) extends StatefulWidget {
  @override
  State<DeviceL2capPanel> createState() => _DeviceL2capPanelState();
}

class _DeviceL2capPanelState() extends State<DeviceL2capPanel> {
  final _form = FormGroup({
    'psm': FormControl<int>(validators: [Validators.required]),
  });
  final _psmAccessor = _PsmAccessor();
  bool _secure = true;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = workbenchRef.of(context);
    final device = widget.device;
    workbenchRef.watchSnapshot(
      context,
      (c) => [
        device.isConnected,
        c.ready,
        c.busy(Operation.open),
        c.busy(Operation.connection),
        c.nameOf(device),
        c.outgoingChannelState(device.remoteId),
      ],
    );
    final connected = device.isConnected;
    final sessions = c.channelSessions.where((s) => !s.incoming && s.channel.deviceId == device.remoteId);
    final connectionReady = connected && c.ready;
    final channelIdle = !c.busy(Operation.open);
    final connectionIdle = !c.busy(Operation.connection);
    final enabled = connectionReady && channelIdle && connectionIdle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkbenchCard(
          title: const Text('L2CAP to this device'),
          icon: Icons.cable_rounded,
          subtitle: Text('A separate byte stream to ${c.nameOf(device)} over the Bluetooth connection.'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (_) {
                  if (!connected) {
                    return const Text('Connect this device above to open an L2CAP channel.');
                  }
                  return ReactiveForm(
                    formGroup: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('The device must run an L2CAP server. Enter the PSM supplied by that server.'),
                        const SizedBox(height: 16),
                        ReactiveTextField<int>(
                          formControlName: 'psm',
                          valueAccessor: _psmAccessor,
                          readOnly: !enabled,
                          decoration: const InputDecoration(
                            labelText: 'Remote PSM',
                            hintText: 'Decimal or 0x hexadecimal',
                          ),
                          validationMessages: {
                            ValidationMessage.required: (_) {
                              return 'Enter a PSM from 1 to 65535, in decimal or 0x hexadecimal.';
                            },
                          },
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (_) {
                            if (defaultTargetPlatform == TargetPlatform.android) {
                              return SwitchListTile(
                                value: _secure,
                                onChanged: enabled ? (value) => setState(() => _secure = value) : null,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Require encryption'),
                              );
                            }
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('On Apple devices, encryption is determined by the remote server.'),
                            );
                          },
                        ),
                        if (!channelIdle)
                          FilledButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Opening…'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: enabled
                                ? () {
                                    if (!_form.valid) {
                                      _form.markAllAsTouched();
                                      return;
                                    }
                                    c.openChannel(_form.value['psm']! as int, device: device, secure: _secure);
                                  }
                                : null,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Open channel'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'GATT services do not imply L2CAP support. Discovering GATT services is optional for this channel, '
                'unless the device uses a characteristic to share its PSM. Android requires version 10 or newer.',
              ),
            ],
          ),
        ),
        if (!sessions.any((s) => !s.closed) && connected)
          const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('No L2CAP channel open to this device yet.')),
        for (final session in sessions) L2capChannelCard(key: ValueKey(session.key), session: session),
      ],
    );
  }
}

/// Parses the view once; the form and submission share the validated integer.
class _PsmAccessor() extends ControlValueAccessor<int, String> {
  @override
  int? viewToModelValue(String? viewValue) {
    try {
      return parsePsm(viewValue ?? '');
    } on FormatException {
      return null;
    }
  }

  @override
  String modelToViewValue(int? modelValue) => modelValue?.toString() ?? '';
}
