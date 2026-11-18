import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:provider/provider.dart';

/// Activity destination in `WorkbenchApp`.
/// Searchable session output includes native diagnostics and payload previews.
class const ActivityPanel({super.key}) extends StatefulWidget {
  @override
  State<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState() extends State<ActivityPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = context.read<WorkbenchController>();
    return ValueListenableBuilder(
      valueListenable: controller.activity,
      builder: (_, entries, _) => ActivityLog(
        entries: entries,
        query: _query,
        onQueryChanged: (text) => setState(() => _query = text),
        onCopy: () => controller.copyToClipboard(entries.map((entry) => entry.text).join('\n')),
        onClear: controller.clearLogs,
      ),
    );
  }
}

/// The filter and log rows displayed by ActivityPanel, backed by one log snapshot.
class const ActivityLog({
  required final List<ActivityEntry> entries,
  required final String query,
  required final ValueChanged<String> onQueryChanged,
  required final Future<bool> Function() onCopy,
  required final VoidCallback onClear,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final search = query.toLowerCase();
    final lines = entries.reversed.where((entry) => entry.text.toLowerCase().contains(search)).toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session activity', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Newest first. Payloads and device identifiers are included when copying this log.'),
                const SizedBox(height: 20),
                TextField(
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filter activity'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final copied = await onCopy();
                        if (copied && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Session log copied')));
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy session'),
                    ),
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Builder(
          builder: (context) {
            if (lines.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Activity will appear as you explore.')),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverList.separated(
                itemCount: lines.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  return SelectableText(
                    lines[index].text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.6,
                      color: lines[index].severity == ActivitySeverity.error
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
