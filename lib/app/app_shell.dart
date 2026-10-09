import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) return child;
          final theme = Theme.of(context);
          return Row(
            children: [
              Container(
                width: 228,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(right: BorderSide(color: theme.dividerColor)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.terrain_outlined,
                      size: 30,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'WORLD\nMANAGER',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A home for your adventures',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 42),
                    Text(
                      'LIBRARY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: .08,
                          ),
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        icon: const Icon(Icons.grid_view_outlined, size: 18),
                        label: const Text('Your worlds'),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Local & private',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          );
        },
      ),
    ),
  );
}
