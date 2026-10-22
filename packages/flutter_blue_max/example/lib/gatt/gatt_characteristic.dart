import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_blue_max_example/shared/payload_editor.dart';

/// Inspects the actual characteristic instance and its descriptors.
class const GattCharacteristic({
  super.key,
  required final BluetoothCharacteristic characteristic,
  required final WorkbenchController controller,
}) extends StatefulWidget {
  @override
  State<GattCharacteristic> createState() => _GattCharacteristicState();
}

class _GattCharacteristicState() extends State<GattCharacteristic> {
  bool _withoutResponse = false;
  bool _writing = false;
  bool _notifying = false;
  late final Stream<List<int>> _values = widget.characteristic.lastValueStream;

  StreamSubscription<List<int>>? _notificationChanges;

  @override
  void initState() {
    super.initState();
    _notifying = widget.characteristic.isNotifying;
    for (final descriptor in widget.characteristic.descriptors) {
      if (descriptor.uuid == Guid('2902')) {
        // CCCD events may arrive after the operation future and also after direct writes.
        _notificationChanges = descriptor.lastValueStream.listen((value) {
          if (mounted) {
            setState(() {
              _notifying = value.isNotEmpty && (value.first & 0x03) != 0;
            });
          }
        });
        break;
      }
    }
  }

  @override
  void dispose() {
    unawaited(_notificationChanges?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.characteristic;
    final p = c.properties;
    final key = 'gatt:${c.remoteId}:${c.serviceUuid}:${c.uuid}:${c.instanceId}';
    final enabled = !widget.controller.busy(key) && c.device.isConnected;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(c.uuid.str.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
      subtitle: Text(
        [
          if (p.read) 'Read',
          if (p.write) 'Write',
          if (p.writeWithoutResponse) 'Write without response',
          if (p.notify) 'Notify',
          if (p.indicate) 'Indicate',
          if (c.instanceId != null) 'Instance ${c.instanceId}',
        ].join(' · '),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<int>>(
                stream: _values,
                builder: (context, snapshot) {
                  final bytes = snapshot.data ?? [];
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${bytes.length} bytes', style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 6),
                        SelectableText(
                          bytes.isEmpty ? 'No value received yet' : PayloadCodec.hex(bytes),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        if (bytes.isNotEmpty)
                          Text(PayloadCodec.text(bytes), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.read)
                    OutlinedButton.icon(
                      onPressed: (() {
                        if (enabled) {
                          return () async {
                            await widget.controller.run(key, () async {
                              await c.read();
                            });
                          };
                        }
                        return null;
                      })(),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Read'),
                    ),
                  if (p.write || p.writeWithoutResponse)
                    OutlinedButton.icon(
                      onPressed: enabled ? () => setState(() => _writing = !_writing) : null,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Write'),
                    ),
                  if (p.notify || p.indicate)
                    () {
                      final VoidCallback? toggleNotifications;
                      if (enabled) {
                        toggleNotifications = () async {
                          await widget.controller.run(key, () async {
                            final notify = !_notifying;
                            await c.setNotifyValue(notify);
                            // Web Bluetooth does not publish a CCCD write event.
                            if (kIsWeb) {
                              // Browser subscriptions have no native CCCD event.
                              if (mounted) {
                                setState(() => _notifying = notify);
                              }
                            }
                            if (p.read) {
                              await c.read();
                            }
                          });
                        };
                      } else {
                        toggleNotifications = null;
                      }
                      if (_notifying) {
                        return OutlinedButton.icon(
                          onPressed: toggleNotifications,
                          icon: const Icon(Icons.notifications_active_outlined, size: 16),
                          label: const Text('Unsubscribe'),
                        );
                      }
                      return OutlinedButton.icon(
                        onPressed: toggleNotifications,
                        icon: const Icon(Icons.notifications_none, size: 16),
                        label: const Text('Subscribe'),
                      );
                    }(),
                ],
              ),
              if (_writing) ...[
                const SizedBox(height: 12),
                if (p.write && p.writeWithoutResponse)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Without response'),
                    value: _withoutResponse,
                    onChanged: enabled ? (value) => setState(() => _withoutResponse = value) : null,
                  ),
                PayloadEditor(
                  enabled: enabled,
                  label: const Text('Write characteristic'),
                  onSend: (value) {
                    return widget.controller.run(key, () async {
                      await c.write(value, withoutResponse: !p.write || _withoutResponse);
                      if (p.read) {
                        await c.read();
                      }
                    });
                  },
                ),
              ],
              for (final descriptor in c.descriptors)
                _Descriptor(descriptor: descriptor, controller: widget.controller),
            ],
          ),
        ),
      ],
    );
  }
}

class const _Descriptor({required final BluetoothDescriptor descriptor, required final WorkbenchController controller})
    extends StatefulWidget {
  @override
  State<_Descriptor> createState() => _DescriptorState();
}

class _DescriptorState() extends State<_Descriptor> {
  late final Stream<List<int>> _values = widget.descriptor.lastValueStream;

  @override
  Widget build(BuildContext context) {
    final d = widget.descriptor;
    final key = 'descriptor:${d.remoteId}:${d.serviceUuid}:${d.characteristicUuid}:${d.uuid}:${d.instanceId}';
    final enabled = !widget.controller.busy(key) && d.device.isConnected;
    return ExpansionTile(
      title: Text('Descriptor ${d.uuid.str.toUpperCase()}', style: Theme.of(context).textTheme.bodySmall),
      children: [
        StreamBuilder<List<int>>(
          stream: _values,
          builder: (context, snapshot) => SelectableText(PayloadCodec.hex(snapshot.data ?? [])),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: (() {
              if (enabled) {
                return () async {
                  await widget.controller.run(key, () async {
                    await d.read();
                  });
                };
              }
              return null;
            })(),
            child: const Text('Read descriptor'),
          ),
        ),
        PayloadEditor(
          enabled: enabled,
          label: const Text('Write descriptor'),
          onSend: (value) {
            return widget.controller.run(key, () async {
              await d.write(value);
            });
          },
        ),
        if (d.uuid == Guid('2902'))
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Subscribe configures this descriptor. Direct CCCD writes may be rejected by the platform.'),
          ),
      ],
    );
  }
}
