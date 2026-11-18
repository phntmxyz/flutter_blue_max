import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_blue_max_example/shared/payload_editor.dart';
import 'package:provider/provider.dart';

/// Characteristic row inside `GattService`.
/// Inspects the actual characteristic instance and its descriptors.
class const GattCharacteristic({super.key, required final BluetoothCharacteristic characteristic})
    extends StatefulWidget {
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
    if (kIsWeb) {
      return;
    }
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

  Future<void> _readCharacteristic() async {
    final c = widget.characteristic;
    await context.read<WorkbenchController>().run(Operation.characteristic(c), () async {
      await c.read();
    });
  }

  Future<void> _toggleNotifications() async {
    final c = widget.characteristic;
    final controller = context.read<WorkbenchController>();
    await controller.run(Operation.characteristic(c), () async {
      final notify = !(kIsWeb ? controller.subscribedOnWeb(c) : _notifying);
      final generation = controller.connectionGeneration(c.device);
      await c.setNotifyValue(notify);
      // Web Bluetooth does not publish a CCCD event, so keep its subscription in the session.
      if (kIsWeb) {
        controller.setSubscribedOnWeb(c, subscribed: notify, generation: generation);
      }
      if (c.properties.read) {
        await c.read();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.characteristic;
    final p = c.properties;
    final operation = Operation.characteristic(c);
    final enabled =
        !context.select<WorkbenchController, bool>((controller) => controller.busy(operation)) && c.device.isConnected;
    final notifying = kIsWeb
        ? context.select<WorkbenchController, bool>((controller) => controller.subscribedOnWeb(c))
        : _notifying;
    final service = context.read<WorkbenchController>().knownService(c.serviceUuid);
    final known = service?.characteristic(c.uuid);
    final isTestEntry = service?.test ?? false;
    final checked = isTestEntry && known != null;
    final expected = checked ? known.matches(p) : null;
    final description = userDescription(c);
    final uuid = c.uuid.str.toUpperCase();
    final name = _displayName(known, description, expected: expected);
    return ExpansionTile(
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: GattTitle(
        title: Text(name ?? uuid, style: name == null ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : null),
        expected: expected,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name != null) Text(uuid, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          if (description != null && description != name) Text(description),
          Text(
            [
              for (final property in GattProperty.of(p)) property.label,
              if (c.instanceId != null) 'Instance ${c.instanceId}',
            ].join(' · '),
          ),
          if (expected == false)
            Text(
              'Expected ${GattProperty.values.where(known!.properties!.contains).map((p) => p.label).join(' · ')}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
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
                          bytes.isEmpty ? 'Empty' : PayloadCodec.hex(bytes),
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
                      onPressed: enabled ? _readCharacteristic : null,
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
                    SubscribeButton(notifying: notifying, onPressed: enabled ? _toggleNotifications : null),
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
                    return context.read<WorkbenchController>().run(operation, () async {
                      await c.write(value, withoutResponse: !p.write || _withoutResponse);
                      if (p.read) {
                        await c.read();
                      }
                    });
                  },
                ),
              ],
              for (final descriptor in c.descriptors) GattDescriptorTile(descriptor: descriptor),
            ],
          ),
        ),
      ],
    );
  }
}

String? _displayName(KnownCharacteristic? known, String? description, {required bool? expected}) {
  if (known == null) {
    return description;
  }
  if (expected == true) {
    return 'Test · ${known.name}';
  }
  return known.name;
}

/// Styled title shared by discovered service and characteristic tiles, with an optional test verdict.
class const GattTitle({super.key, required final Widget title, final bool? expected}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (expected != null) ...[
          if (expected!)
            Icon(Icons.check_circle_rounded, size: 16, color: colors.primary)
          else
            Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
          const SizedBox(width: 6),
        ],
        Flexible(child: title),
      ],
    );
  }
}

/// Descriptor section of an expanded GattCharacteristic.
class const GattDescriptorTile({required final BluetoothDescriptor descriptor}) extends StatefulWidget {
  @override
  State<GattDescriptorTile> createState() => _DescriptorState();
}

class _DescriptorState() extends State<GattDescriptorTile> {
  late final Stream<List<int>> _values = widget.descriptor.lastValueStream;

  Future<void> _readDescriptor() async {
    final d = widget.descriptor;
    await context.read<WorkbenchController>().run(Operation.descriptor(d), () async {
      await d.read();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.descriptor;
    final operation = Operation.descriptor(d);
    final enabled = !context.read<WorkbenchController>().busy(operation) && d.device.isConnected;
    return ExpansionTile(
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text('Descriptor ${d.uuid.str.toUpperCase()}', style: Theme.of(context).textTheme.bodySmall),
      children: [
        StreamBuilder<List<int>>(
          stream: _values,
          builder: (context, snapshot) => SelectableText(PayloadCodec.hex(snapshot.data ?? [])),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: enabled ? _readDescriptor : null, child: const Text('Read descriptor')),
        ),
        PayloadEditor(
          enabled: enabled,
          label: const Text('Write descriptor'),
          onSend: (value) {
            return context.read<WorkbenchController>().run(operation, () async {
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

/// Notification toggle within a GATT characteristic, with behavior owned by the characteristic state.
class const SubscribeButton({super.key, required final bool notifying, required final VoidCallback? onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (notifying) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.notifications_active_outlined, size: 16),
        label: const Text('Unsubscribe'),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.notifications_none, size: 16),
      label: const Text('Subscribe'),
    );
  }
}
