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
    context.select<WorkbenchController, Object?>((c) => c.logs);
    final lines = context
        .read<WorkbenchController>()
        .logs
        .reversed
        .where((line) => line.toLowerCase().contains(_query.toLowerCase()))
        .toList();
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
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filter activity'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final controller = context.read<WorkbenchController>();
                        final copied = await controller.copyToClipboard(controller.logs.join('\n'));
                        if (copied && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Session log copied')));
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy session'),
                    ),
                    TextButton.icon(
                      onPressed: context.read<WorkbenchController>().clearLogs,
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
                    lines[index],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.6,
                      color: lines[index].contains('ERROR') ? Theme.of(context).colorScheme.error : null,
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
