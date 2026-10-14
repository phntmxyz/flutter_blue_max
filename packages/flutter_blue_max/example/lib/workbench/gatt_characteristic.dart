import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/workbench/payload_codec.dart';
import 'package:flutter_blue_max_example/workbench/payload_editor.dart';
import 'package:flutter_blue_max_example/workbench/workbench_controller.dart';

/// Inspects the actual characteristic instance and its descriptors.
class GattCharacteristic extends StatefulWidget {
  const GattCharacteristic({super.key, required this.characteristic, required this.controller});

  final BluetoothCharacteristic characteristic;
  final WorkbenchController controller;

  @override
  State<GattCharacteristic> createState() => _GattCharacteristicState();
}

class _GattCharacteristicState extends State<GattCharacteristic> {
  bool _withoutResponse = false;
  bool _writing = false;
  late final Stream<List<int>> _values = widget.characteristic.lastValueStream;

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
                      onPressed: enabled
                          ? () => widget.controller.run(key, () async {
                              await c.read();
                            })
                          : null,
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
                    OutlinedButton.icon(
                      onPressed: enabled
                          ? () => widget.controller.run(key, () async {
                              await c.setNotifyValue(!c.isNotifying);
                            })
                          : null,
                      icon: Icon(
                        c.isNotifying ? Icons.notifications_active_outlined : Icons.notifications_none,
                        size: 16,
                      ),
                      label: Text(c.isNotifying ? 'Unsubscribe' : 'Subscribe'),
                    ),
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
                  label: 'Write characteristic',
                  onSend: (value) => widget.controller.run(key, () async {
                    await c.write(value, withoutResponse: !p.write || _withoutResponse);
                  }),
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

class _Descriptor extends StatefulWidget {
  const _Descriptor({required this.descriptor, required this.controller});
  final BluetoothDescriptor descriptor;
  final WorkbenchController controller;

  @override
  State<_Descriptor> createState() => _DescriptorState();
}

class _DescriptorState extends State<_Descriptor> {
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
            onPressed: enabled
                ? () => widget.controller.run(key, () async {
                    await d.read();
                  })
                : null,
            child: const Text('Read descriptor'),
          ),
        ),
        if (d.uuid != Guid('2902'))
          PayloadEditor(
            enabled: enabled,
            label: 'Write descriptor',
            onSend: (value) => widget.controller.run(key, () async {
              await d.write(value);
            }),
          )
        else
          const Padding(padding: EdgeInsets.all(8), child: Text('Use Subscribe above to configure notifications.')),
      ],
    );
  }
}
