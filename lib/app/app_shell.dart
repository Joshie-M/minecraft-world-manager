import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < DesignTokens.desktopBreakpoint) {
            return child;
          }
          final theme = Theme.of(context);
          return Row(
            children: [
              Container(
                width: DesignTokens.sidebarWidth,
                color: theme.colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'World Manager',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Library',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: theme.colorScheme.onSurface,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: .1,
                          ),
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        icon: Icon(
                          CupertinoIcons.square_grid_2x2,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: const Text('Your worlds'),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.lock, size: 12),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Stored on this device',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
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
