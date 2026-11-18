import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_card.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/gatt_service.dart';
import 'package:flutter_blue_max_example/l2cap/device_l2cap_panel.dart';
import 'package:flutter_blue_max_example/shared/workbench_card.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Devices destination of `WorkbenchApp`: discovery and details share two panes on desktop, one on phones.
/// [active] is false on hidden destinations so this panel does not intercept their system back gesture.
class const DevicesPanel({super.key, final bool active = true}) extends StatefulWidget {
  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState() extends State<DevicesPanel> {
  bool _showDetails = false;

  /// Outlives the search field, which narrow layouts drop while the details are shown.
  late final _query = TextEditingController(text: context.read<WorkbenchController>().query);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<WorkbenchController, Object?>((c) => c.deviceState);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final list = DeviceDiscoveryList(
          queryController: _query,
          onSelect: (device) {
            context.read<WorkbenchController>().select(device);
            setState(() => _showDetails = true);
          },
        );
        final detail = DeviceDetails(
          key: ValueKey(context.read<WorkbenchController>().selected?.remoteId),
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
            if (didPop) {
              return;
            }
            // Hidden destinations receive this callback when another panel blocks the pop.
            if (widget.active) {
              setState(() => _showDetails = false);
            }
          },
          child: _showDetails && context.read<WorkbenchController>().selected != null ? detail : list,
        );
      },
    );
  }
}

/// Selected peer inspector within DevicesPanel, including GATT, advertisements and L2CAP.
class const DeviceDetails({super.key, final VoidCallback? onBack}) extends StatefulWidget {
  @override
  State<DeviceDetails> createState() => _DeviceDetailsState();
}

class _DeviceDetailsState() extends State<DeviceDetails> {
  bool _l2cap = false;
  WorkbenchController get controller => context.read<WorkbenchController>();
  VoidCallback? get onBack => widget.onBack;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final device = c.selected;
    if (device == null) {
      return Center(
        child: SingleChildScrollView(
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
    final available = c.connected && c.ready && !c.busy(Operation.connection);
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
                    onPressed: () => c.copyToClipboard(device.remoteId.str),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  () {
                    if (c.connected) {
                      return const Chip(avatar: Icon(Icons.link, size: 16), label: Text('Connected'));
                    }
                    return const Chip(avatar: Icon(Icons.link_off, size: 16), label: Text('Disconnected'));
                  }(),
                  if (c.supportsMtu && c.connected && c.mtu != null) Chip(label: Text('MTU ${c.mtu} B')),
                  if (c.rssi != null && c.connected) Chip(label: Text('${c.rssi} dBm')),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  () {
                    final isConnectingThisPeer = c.connectingDevice == device;
                    final connectionIdle = !c.busy(Operation.connection);
                    final allowsConnection = advertisement?.advertisementData.connectable ?? true;
                    final canConnect = c.ready && connectionIdle && (c.connected || allowsConnection);
                    if (isConnectingThisPeer) {
                      return FilledButton.icon(
                        onPressed: c.busy(Operation.cancelConnection) ? null : c.cancelConnect,
                        icon: Icon(c.connected ? Icons.link_off : Icons.link),
                        label: const Text('Cancel connection'),
                      );
                    }
                    if (!connectionIdle) {
                      return FilledButton.icon(
                        onPressed: null,
                        icon: Icon(c.connected ? Icons.link_off : Icons.link),
                        label: const Text('Working…'),
                      );
                    }
                    if (c.connected) {
                      return FilledButton.icon(
                        onPressed: canConnect ? c.disconnect : null,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                      );
                    }
                    return FilledButton.icon(
                      onPressed: canConnect ? c.connect : null,
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                    );
                  }(),
                  if (!kIsWeb)
                    OutlinedButton.icon(
                      onPressed: available && !c.busy(Operation.rssi(device)) ? c.readRssi : null,
                      icon: const Icon(Icons.signal_cellular_alt),
                      label: const Text('Read RSSI'),
                    ),
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                    OutlinedButton(
                      onPressed: available ? () => _mtuDialog(context, c, device) : null,
                      child: const Text('Request MTU'),
                    ),
                    OutlinedButton(
                      onPressed: (() {
                        if (!available || c.busy(Operation.bond)) {
                          return null;
                        }
                        return () => c.run(Operation.bond, device.createBond);
                      })(),
                      child: const Text('Create bond'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              if (!kIsWeb && (advertisement != null || c.advertisementTracker?.remoteId == device.remoteId))
                AdvertisementCard(device: device),
            ],
          ),
        ),
        if (c.supportsL2cap)
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
            child: (() {
              if (_l2cap && c.supportsL2cap) {
                return DeviceL2capPanel(key: ValueKey(device.remoteId), device: device);
              }
              return WorkbenchCard(
                title: const Text('GATT explorer'),
                icon: Icons.account_tree_outlined,
                subtitle: const Text(
                  'Discover services after connecting. '
                  'Only operations supported by each characteristic are shown.',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.busy(Operation.discover))
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Discovering…'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: available ? c.discover : null,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Discover services'),
                      ),
                    if (c.services.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No services discovered in this connection.'),
                      ),
                    for (final service in c.services)
                      GattService(
                        key: ValueKey('${device.remoteId}:${service.primaryServiceUuid}:${service.uuid}'),
                        service: service,
                      ),
                  ],
                ),
              );
            })(),
          ),
        ),
      ],
    );
  }

  Future<void> _mtuDialog(BuildContext context, WorkbenchController controller, BluetoothDevice device) async {
    final initialMtu = controller.mtu ?? device.mtuNow;
    final generation = controller.connectionGeneration(device);
    final value = await showDialog<int>(
      context: context,
      builder: (_) => MtuRequestDialog(initialMtu: initialMtu),
    );
    if (value != null) {
      await controller.requestMtu(device, value, generation: generation);
    }
  }
}

/// Discovery column in the Devices destination; coordinates scan state and selection.
class const DeviceDiscoveryList({
  super.key,
  required final TextEditingController queryController,
  required final ValueChanged<BluetoothDevice> onSelect,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.read<WorkbenchController>();
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
                  Text(
                    (() {
                      if (kIsWeb) {
                        return 'Choose a device in the browser to explore GATT services.';
                      }
                      return 'Explore advertisements and GATT services.';
                    })(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (c.localName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    Text('This device: ${c.localName}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: queryController,
                    onChanged: c.setQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Name, ID or service UUID',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: () {
                      final canScan = c.ready && !c.busy(Operation.scan);
                      if (c.scanning) {
                        return FilledButton.icon(
                          onPressed: canScan ? c.scan : null,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop scan'),
                        );
                      }
                      return FilledButton.icon(
                        onPressed: canScan ? c.scan : null,
                        icon: const Icon(Icons.radar_rounded),
                        label: const Text('Start scan'),
                      );
                    }(),
                  ),
                  const SizedBox(height: 14),
                  if (c.systemDevices.isNotEmpty) ...[
                    ExpansionTile(
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      title: const Text('Connected to the system'),
                      subtitle: const Text('These peers may be connected through another app.'),
                      children: [
                        for (final device in c.systemDevices)
                          ListTile(
                            title: Text(c.nameOf(device)),
                            subtitle: Text(device.remoteId.str),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              onSelect(device);
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
                              onSelect(device);
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
                        (() {
                          if (c.scanning) {
                            return 'Scanning…';
                          }
                          if (kIsWeb) {
                            return 'Selected devices';
                          }
                          return 'In order of discovery';
                        })(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Reserves the indicator's space so the list does not shift when a scan starts or stops.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            sliver: SliverToBoxAdapter(
              child: SizedBox(height: 2, child: c.scanning ? const LinearProgressIndicator(minHeight: 2) : null),
            ),
          ),
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
                  final String signal;
                  if (kIsWeb) {
                    signal = 'Selected in browser';
                  } else {
                    signal =
                        '${result.rssi} dBm · ${result.advertisementData.connectable ? 'Connectable' : 'Broadcast only'}';
                  }
                  return ScanResultTile(
                    title: Text(c.nameOf(result.device), maxLines: 1, overflow: TextOverflow.ellipsis),
                    identifier: Text(result.device.remoteId.str, maxLines: 1, overflow: TextOverflow.ellipsis),
                    signal: Text(signal),
                    selected: selected,
                    onTap: () => onSelect(result.device),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A discovered advertiser row, distinct from system-connected peer rows.
class const ScanResultTile({
  super.key,
  required final Widget title,
  required final Widget identifier,
  required final Widget signal,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: title,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              child: identifier,
            ),
            const SizedBox(height: 5),
            DefaultTextStyle(style: Theme.of(context).textTheme.bodySmall!, child: signal),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// The dialog owns its form until the closing route has finished animating.
class const MtuRequestDialog({super.key, required final int initialMtu}) extends StatefulWidget {
  @override
  State<MtuRequestDialog> createState() => _MtuRequestDialogState();
}

class _MtuRequestDialogState() extends State<MtuRequestDialog> {
  late final form = FormGroup({
    'mtu': FormControl<int>(
      value: widget.initialMtu,
      validators: [Validators.required, Validators.min(23), Validators.max(517)],
    ),
  });

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request MTU'),
      content: ReactiveForm(
        formGroup: form,
        child: ReactiveTextField<int>(
          formControlName: 'mtu',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Bytes (23–517)'),
          validationMessages: {
            for (final error in [ValidationMessage.required, ValidationMessage.min, ValidationMessage.max])
              error: (_) => 'Enter a value from 23 to 517.',
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!form.valid) {
              form.markAllAsTouched();
              return;
            }
            Navigator.pop(context, form.value['mtu']);
          },
          child: const Text('Request'),
        ),
      ],
    );
  }
}
