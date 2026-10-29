import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_tracker.dart';
import 'package:flutter_blue_max_example/advertisements/parser_editor.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';

/// The inspected peer's latest advertisement, its parsers and an optional live history of all of them.
class const AdvertisementCard({
  super.key,
  required final BluetoothDevice device,
  required final WorkbenchController controller,
}) extends StatefulWidget {
  /// Enough rows to see a payload rotate without rebuilding a long list per advertisement.
  static const visibleEntries = 25;

  @override
  State<AdvertisementCard> createState() => _AdvertisementCardState();
}

class _AdvertisementCardState() extends State<AdvertisementCard> {
  String _query = '';
  bool _changesOnly = false;
  bool _parsedOnly = false;

  WorkbenchController get c => widget.controller;
  BluetoothDevice get device => widget.device;

  Future<void> _editParser({AdvertisementParser? previous}) => ParserEditorPage.open(
    context,
    c,
    previous: previous,
    device: device.remoteId,
    advertisement: c.selectedAdvertisement?.advertisementData,
  );

  @override
  Widget build(BuildContext context) {
    final advertisement = c.selectedAdvertisement;
    final parsers = c.parsersFor(device.remoteId);
    final tracker = c.advertisementTracker?.remoteId == device.remoteId ? c.advertisementTracker : null;
    // Global parsers for other payloads stay in the Library tab instead of crowding every device.
    final relevant = [
      for (final parser in parsers)
        if (parser.device != null ||
            (advertisement != null && parser.readsFrom(advertisement.advertisementData)) ||
            (tracker?.history.any((entry) => parser.readsFrom(entry.data)) ?? false))
          parser,
    ];
    final tracking = tracker != null && c.tracking;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: const Text('Advertisement'),
        subtitle: Text(
          [
            if (advertisement != null) ...[
              '${advertisement.rssi} dBm',
              if (advertisement.advertisementData.connectable) 'Connectable' else 'Broadcast only',
            ],
            if (tracking) 'Tracking ${tracker.count}' else if (tracker != null) '${tracker.count} tracked',
          ].join(' · '),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (advertisement != null)
            SelectableText(
              describeAdvertisement(advertisement.advertisementData, parsers: parsers).join('\n'),
              style: mono,
            ),
          const Divider(height: 32),
          Text('Parsers', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Parsers for the payloads of this device. Manage all parsers in the Library tab.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final parser in relevant)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(parser.name),
              subtitle: Text(parser.summary),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit parser',
                    onPressed: () => _editParser(previous: parser),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove parser',
                    onPressed: () => c.removeParser(parser),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _editParser, icon: const Icon(Icons.add), label: const Text('Add parser')),
          const Divider(height: 32),
          Text('Tracker', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Scans for this device only, including repeated advertisements. Connecting stops the scan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          () {
            final enabled = c.ready && !c.busy('scan');
            if (tracking) {
              return FilledButton.icon(
                onPressed: enabled ? c.stopTracking : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop tracking'),
              );
            }
            return OutlinedButton.icon(
              onPressed: enabled ? () => c.trackAdvertisements(device) : null,
              icon: const Icon(Icons.timeline_rounded),
              label: const Text('Track advertisements'),
            );
          }(),
          if (tracking) ...[const SizedBox(height: 14), const LinearProgressIndicator(minHeight: 2)],
          if (tracker != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${tracker.count} advertisements')),
                if (tracker.averageInterval != null)
                  Chip(label: Text('Ø ${tracker.averageInterval!.inMilliseconds} ms')),
                if (tracker.minRssi != null) Chip(label: Text('${tracker.minRssi} … ${tracker.maxRssi} dBm')),
                Chip(label: Text('${tracker.payloadChanges} payload changes')),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list), hintText: 'Filter history'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Changes only'),
                  selected: _changesOnly,
                  onSelected: (value) => setState(() => _changesOnly = value),
                ),
                FilterChip(
                  label: const Text('Parsed only'),
                  selected: _parsedOnly,
                  onSelected: (value) => setState(() => _parsedOnly = value),
                ),
              ],
            ),
            if (tracker.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Waiting for the first advertisement…'),
              )
            else
              ...() {
                final search = _query.trim().toLowerCase();
                final rows =
                    [
                      for (final entry in tracker.history)
                        if (!_changesOnly || entry.changed)
                          (
                            entry: entry,
                            time: entry.time.toIso8601String().substring(11, 23),
                            parsed: parsedValues(entry.data, parsers),
                          ),
                    ].where((row) {
                      if (_parsedOnly && row.parsed.isEmpty) {
                        return false;
                      }
                      if (search.isEmpty) {
                        return true;
                      }
                      final searchable = [
                        row.time,
                        '${row.entry.rssi} dBm',
                        ...describeAdvertisement(row.entry.data, parsers: parsers),
                      ].join('\n').toLowerCase();
                      return searchable.contains(search);
                    }).toList();
                return [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${rows.length} of ${tracker.history.length} recent advertisements',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  // Parsed values appear on every row; the full payload only on the newest and on changes.
                  for (final (index, row) in rows.take(AdvertisementCard.visibleEntries).indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row.time} · ${row.entry.rssi} dBm'
                            '${row.entry.interval == null ? '' : ' · +${row.entry.interval!.inMilliseconds} ms'}',
                            style: mono,
                          ),
                          if (index == 0 || row.entry.changed)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: row.entry.changed
                                    ? Theme.of(context).colorScheme.tertiaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                describeAdvertisement(row.entry.data, parsers: parsers).join('\n'),
                                style: mono,
                              ),
                            )
                          else
                            for (final value in row.parsed)
                              Text('  ↳ $value', style: mono.copyWith(color: Theme.of(context).colorScheme.primary)),
                        ],
                      ),
                    ),
                ];
              }(),
          ],
        ],
      ),
    );
  }
}
