import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/gatt_characteristic.dart';
import 'package:flutter_blue_max_example/l2cap/device_l2cap_panel.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_blue_max_example/shared/workbench_card.dart';

/// Adapts discovery and inspection from a two-pane desktop layout to a phone.
class DevicesPanel extends StatefulWidget {
  const DevicesPanel({super.key, required this.controller, this.active = true});
  final WorkbenchController controller;
  final bool active;

  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final list = _discovery(context);
        final detail = _DeviceDetails(
          key: ValueKey(widget.controller.selected?.remoteId),
          controller: widget.controller,
          onBack: wide ? null : () => setState(() => _showDetails = false),
        );
        if (wide) {
          return Row(
            children: [
              SizedBox(width: 330, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }
        return PopScope(
          canPop: !_showDetails || !widget.active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && widget.active) {
              setState(() => _showDetails = false);
            }
          },
          child: _showDetails && widget.controller.selected != null ? detail : list,
        );
      },
    );
  }

  Widget _discovery(BuildContext context) {
    final c = widget.controller;
    final results = c.visibleDevices;
    return RefreshIndicator(
      onRefresh: c.refreshScan,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nearby devices', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text('Explore advertisements and GATT services.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: c.setQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Name, ID or service UUID',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: c.ready && !c.busy('scan') ? c.scan : null,
                      icon: Icon(c.scanning ? Icons.stop_rounded : Icons.radar_rounded),
                      label: Text(c.scanning ? 'Stop scan' : 'Start scan'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (c.systemDevices.isNotEmpty) ...[
                    ExpansionTile(
                      title: const Text('Connected to the system'),
                      subtitle: const Text('These peers may be connected through another app.'),
                      children: [
                        for (final device in c.systemDevices)
                          ListTile(
                            title: Text(c.nameOf(device)),
                            subtitle: Text(device.remoteId.str),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              c.select(device);
                              setState(() => _showDetails = true);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (c.connectedDevices.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final device in c.connectedDevices)
                          ActionChip(
                            avatar: const Icon(Icons.link, size: 16),
                            label: Text(c.nameOf(device), overflow: TextOverflow.ellipsis),
                            onPressed: () {
                              c.select(device);
                              setState(() => _showDetails = true);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('${results.length} devices', style: Theme.of(context).textTheme.labelMedium),
                      Text(
                        c.scanning ? 'Scanning…' : 'Strongest signal first',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (c.scanning) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_searching_rounded, size: 42, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        c.query.isNotEmpty ? 'No matching devices' : 'Your next connection starts here',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text('Keep your peripheral nearby and start a scan.', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final result = results[index];
                  final selected = c.selected == result.device;
                  return Card(
                    color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      title: Text(c.nameOf(result.device), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(
                            result.device.remoteId.str,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${result.rssi} dBm · '
                            '${result.advertisementData.connectable ? 'Connectable' : 'Broadcast only'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        c.select(result.device);
                        setState(() => _showDetails = true);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceDetails extends StatefulWidget {
  const _DeviceDetails({super.key, required this.controller, this.onBack});
  final WorkbenchController controller;
  final VoidCallback? onBack;

  @override
  State<_DeviceDetails> createState() => _DeviceDetailsState();
}

class _DeviceDetailsState extends State<_DeviceDetails> {
  bool _l2cap = false;
  WorkbenchController get controller => widget.controller;
  VoidCallback? get onBack => widget.onBack;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final device = c.selected;
    if (device == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.developer_board_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'A closer look at Bluetooth.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Select a device to inspect its services, read values and subscribe to notifications.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final available = c.connected && c.ready && !c.busy('connection');
    final advertisement = c.selectedAdvertisement;
    return CustomScrollView(
      key: ValueKey(device.remoteId),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverList.list(
            children: [
              if (onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Devices'),
                  ),
                ),
              Text(c.nameOf(device), style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: SelectableText(device.remoteId.str, style: Theme.of(context).textTheme.bodySmall)),
                  IconButton(
                    tooltip: 'Copy device ID',
                    onPressed: () => Clipboard.setData(ClipboardData(text: device.remoteId.str)),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(c.connected ? Icons.link : Icons.link_off, size: 16),
                    label: Text(c.connected ? 'Connected' : 'Disconnected'),
                  ),
                  if (c.connected) Chip(label: Text('MTU ${c.mtu ?? device.mtuNow} B')),
                  if (c.rssi != null && c.connected) Chip(label: Text('${c.rssi} dBm')),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: c.connectingDevice == device
                        ? (c.busy('cancelConnection') ? null : c.cancelConnect)
                        : c.ready &&
                              !c.busy('connection') &&
                              (c.connected || (advertisement?.advertisementData.connectable ?? true))
                        ? (c.connected ? c.disconnect : c.connect)
                        : null,
                    icon: Icon(c.connected ? Icons.link_off : Icons.link),
                    label: Text(
                      c.connectingDevice == device
                          ? 'Cancel connection'
                          : c.busy('connection')
                          ? 'Working…'
                          : c.connected
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: available && !c.busy('rssi') ? c.readRssi : null,
                    icon: const Icon(Icons.signal_cellular_alt),
                    label: const Text('Read RSSI'),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.android) ...[
                    OutlinedButton(
                      onPressed: available ? () => _mtuDialog(context) : null,
                      child: const Text('Request MTU'),
                    ),
                    OutlinedButton(
                      onPressed: available && !c.busy('bond') ? () => c.run('bond', device.createBond) : null,
                      child: const Text('Create bond'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              if (advertisement != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: const Text('Advertisement'),
                    subtitle: Text(
                      '${advertisement.rssi} dBm · '
                      '${advertisement.advertisementData.connectable ? 'Connectable' : 'Broadcast only'}',
                    ),
                    expandedAlignment: Alignment.centerLeft,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      SelectableText(
                        [
                          'Name: ${advertisement.advertisementData.advName}',
                          if (advertisement.advertisementData.txPowerLevel != null)
                            'TX power: ${advertisement.advertisementData.txPowerLevel} dBm',
                          if (advertisement.advertisementData.appearance != null)
                            'Appearance: 0x${advertisement.advertisementData.appearance!.toRadixString(16)}',
                          for (final uuid in advertisement.advertisementData.serviceUuids) 'Service: $uuid',
                          for (final entry in advertisement.advertisementData.manufacturerData.entries)
                            'Manufacturer 0x${entry.key.toRadixString(16)}: ${PayloadCodec.hex(entry.value)}',
                          for (final entry in advertisement.advertisementData.serviceData.entries)
                            'Service data ${entry.key}: ${PayloadCodec.hex(entry.value)}',
                        ].join('\n'),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        PinnedHeaderSliver(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.account_tree_outlined), label: Text('GATT')),
                  ButtonSegment(value: true, icon: Icon(Icons.cable_rounded), label: Text('L2CAP')),
                ],
                selected: {_l2cap},
                onSelectionChanged: (value) => setState(() => _l2cap = value.single),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverToBoxAdapter(
            child: _l2cap
                ? DeviceL2capPanel(key: ValueKey(device.remoteId), device: device, controller: c)
                : WorkbenchCard(
                    title: 'GATT explorer',
                    icon: Icons.account_tree_outlined,
                    subtitle:
                        'Discover services after connecting. '
                        'Only operations supported by each characteristic are shown.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: available && !c.busy('discover') ? c.discover : null,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(c.busy('discover') ? 'Discovering…' : 'Discover services'),
                        ),
                        if (c.services.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No services discovered in this connection.'),
                          ),
                        for (final service in c.services)
                          ExpansionTile(
                            key: ValueKey('${device.remoteId}:${service.primaryServiceUuid}:${service.uuid}'),
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              service.uuid.str.toUpperCase(),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                            ),
                            subtitle: Text(
                              '${service.characteristics.length} characteristics · '
                              '${service.isPrimary ? 'Primary' : 'Secondary'} service',
                            ),
                            children: [
                              for (final characteristic in service.characteristics)
                                GattCharacteristic(
                                  key: ObjectKey(characteristic),
                                  characteristic: characteristic,
                                  controller: c,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _mtuDialog(BuildContext context) async {
    var input = '${controller.mtu ?? controller.selected!.mtuNow}';
    final form = GlobalKey<FormState>();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request MTU'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            onChanged: (value) => input = value,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Bytes (23–517)'),
            validator: (value) {
              final mtu = int.tryParse(value ?? '');
              return mtu == null || mtu < 23 || mtu > 517 ? 'Enter a value from 23 to 517.' : null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input));
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (value != null) {
      await controller.requestMtu(value);
    }
  }
}
