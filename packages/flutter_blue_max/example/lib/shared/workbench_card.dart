import 'package:flutter/material.dart';

/// Consistent section spacing for the phone and desktop workspaces.
class WorkbenchCard extends StatelessWidget {
  const WorkbenchCard({super.key, required this.title, this.subtitle, required this.child, this.icon});

  /// Inherits the section's titleMedium text style.
  final Widget title;

  /// Inherits the section's bodySmall text style.
  final Widget? subtitle;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: DefaultTextStyle(style: Theme.of(context).textTheme.titleMedium!, child: title),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              DefaultTextStyle(style: Theme.of(context).textTheme.bodySmall!, child: subtitle!),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
