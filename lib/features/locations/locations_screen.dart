import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_shell.dart';
import '../../core/database/app_database.dart';
import 'location_repository.dart';
import 'location_editor.dart';

Future<void> copyCoordinates(BuildContext context, Location location) async {
  try {
    await Clipboard.setData(ClipboardData(text: coordinateText(location)));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Coordinates copied.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not copy coordinates. Please try again.'),
        ),
      );
    }
  }
}

Future<void> showLocationDetails(BuildContext context, Location location) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(location.name),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(location.dimension),
                const SizedBox(height: 16),
                const Text('X / Y / Z'),
                const SizedBox(height: 8),
                SelectableText(
                  coordinateText(location),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
                ),
                if (location.notes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SelectableText(location.notes),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => copyCoordinates(context, location),
            icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
            label: const Text('Copy coordinates'),
          ),
        ],
      ),
    );

class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({
    super.key,
    required this.worldId,
    required this.worldName,
  });
  final String worldId;
  final String worldName;
  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  String query = '';
  String? dimension;
  Future<void> edit([Location? location]) async {
    final saved = await showLocationEditor(
      context,
      worldId: widget.worldId,
      location: location,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location saved on this device.')),
      );
    }
  }

  Future<void> delete(Location location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text(
          'Permanently delete "${location.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(locationRepositoryProvider)
          .delete(worldId: widget.worldId, id: location.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete location. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to world',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Locations', style: theme.textTheme.titleLarge),
                      Text(
                        widget.worldName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => edit(),
                  icon: const Icon(CupertinoIcons.plus, size: 16),
                  label: const Text('New location'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search locations',
                prefixIcon: Icon(CupertinoIcons.search, size: 16),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: ref
                .watch(locationsProvider(widget.worldId))
                .when(
                  loading: () =>
                      const Center(child: CupertinoActivityIndicator()),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load locations.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(locationsProvider(widget.worldId)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (all) {
                    final available = {
                      ...dimensions,
                      ...all.map((l) => l.dimension),
                    }.toList();
                    final effectiveDimension = available.contains(dimension)
                        ? dimension
                        : null;
                    final needle = query.trim().toLowerCase();
                    final filtered = all
                        .where(
                          (l) =>
                              (effectiveDimension == null ||
                                  l.dimension == effectiveDimension) &&
                              '${l.name} ${l.notes} ${l.dimension} ${coordinateText(l)}'
                                  .toLowerCase()
                                  .contains(needle),
                        )
                        .toList();
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(effectiveDimension),
                            initialValue: effectiveDimension ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Dimension filter',
                            ),
                            items: ['', ...available]
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d.isEmpty
                                          ? 'All dimensions'
                                          : dimensions.contains(d)
                                          ? d
                                          : 'Custom: $d',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => dimension = value == '' ? null : value,
                            ),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      all.isEmpty
                                          ? 'Save a place worth returning to.'
                                          : 'No matching locations.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final location = filtered[index];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      title: Text(
                                        location.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            coordinateText(location),
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          Text(
                                            location.dimension,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      onTap: () => showLocationDetails(
                                        context,
                                        location,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Copy coordinates',
                                            onPressed: () => copyCoordinates(
                                              context,
                                              location,
                                            ),
                                            icon: const Icon(
                                              CupertinoIcons.doc_on_doc,
                                              size: 16,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: 'Location actions',
                                            icon: const Icon(
                                              CupertinoIcons.ellipsis,
                                            ),
                                            onSelected: (value) =>
                                                value == 'edit'
                                                ? edit(location)
                                                : delete(location),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit location'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete location'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class WorldLocationsSection extends ConsumerWidget {
  const WorldLocationsSection({
    super.key,
    required this.worldId,
    required this.worldName,
  });
  final String worldId;
  final String worldName;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      const SizedBox(height: 20),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Saved locations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    LocationsScreen(worldId: worldId, worldName: worldName),
              ),
            ),
            child: const Text('Open locations'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ref
          .watch(locationsProvider(worldId))
          .when(
            loading: () => const CupertinoActivityIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(locationsProvider(worldId)),
              child: const Text('Retry loading locations'),
            ),
            data: (locations) => locations.isEmpty
                ? const Text('No locations saved yet.')
                : Column(
                    children: locations
                        .take(3)
                        .map(
                          (location) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(location.name),
                            subtitle: Text(
                              '${location.dimension} · ${coordinateText(location)}',
                            ),
                            onTap: () => showLocationDetails(context, location),
                            trailing: IconButton(
                              tooltip: 'Copy coordinates',
                              onPressed: () =>
                                  copyCoordinates(context, location),
                              icon: const Icon(
                                CupertinoIcons.doc_on_doc,
                                size: 16,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
    ],
  );
}
