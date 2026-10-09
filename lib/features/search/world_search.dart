import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_shell.dart';
import '../journal/journal_repository.dart';
import '../journal/entry_reader.dart';
import '../locations/location_repository.dart';
import '../locations/locations_screen.dart';
import '../projects/project_repository.dart';
import '../projects/projects_screen.dart';

// Match every word literally, regardless of order, without searching stored URLs.
bool matchesWorldSearch(String text, String query) {
  final visible = text
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) => match[1]!)
      .toLowerCase();
  return query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .every(visible.contains);
}

class WorldSearch extends ConsumerStatefulWidget {
  const WorldSearch({
    super.key,
    required this.worldId,
    required this.worldName,
  });
  final String worldId, worldName;
  @override
  ConsumerState<WorldSearch> createState() => _WorldSearchState();
}

class _WorldSearchState extends ConsumerState<WorldSearch> {
  final controller = TextEditingController();
  final focus = FocusNode();
  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journals = ref.watch(journalProvider(widget.worldId));
    final locations = ref.watch(locationsProvider(widget.worldId));
    final projects = ref.watch(projectsProvider(widget.worldId));
    final sources = [journals, locations, projects];
    final query = controller.text.trim();
    final entries =
        journals.asData?.value
            .where((e) => matchesWorldSearch('${e.title} ${e.body}', query))
            .toList() ??
        [];
    final places =
        locations.asData?.value
            .where(
              (l) => matchesWorldSearch(
                '${l.name} ${l.notes} ${l.dimension} ${coordinateText(l)}',
                query,
              ),
            )
            .toList() ??
        [];
    final builds =
        projects.asData?.value
            .where(
              (p) =>
                  matchesWorldSearch('${p.name} ${p.notes} ${p.status}', query),
            )
            .toList() ??
        [];
    final count = entries.length + places.length + builds.length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            focus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            focus.requestFocus,
      },
      child: AppShell(
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
                        Text(
                          'Search',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.worldName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const ValueKey('world-search'),
                controller: controller,
                focusNode: focus,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search this world',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 16),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            setState(() {});
                            focus.requestFocus();
                          },
                          icon: const Icon(
                            CupertinoIcons.xmark_circle,
                            size: 16,
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Find journal entries, locations, and projects.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        if (sources.any((s) => s.isLoading))
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: CupertinoActivityIndicator(),
                          ),
                        if (sources.any((s) => s.hasError))
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Some results could not be loaded.',
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref.invalidate(
                                    journalProvider(widget.worldId),
                                  );
                                  ref.invalidate(
                                    locationsProvider(widget.worldId),
                                  );
                                  ref.invalidate(
                                    projectsProvider(widget.worldId),
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        if (count == 0 && sources.every((s) => s.hasValue))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'No matches. Try another name or phrase.',
                            ),
                          ),
                        if (count > 0)
                          Text(
                            '$count ${count == 1 ? 'result' : 'results'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (entries.isNotEmpty) section('Journal entries'),
                        for (final entry in entries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(CupertinoIcons.book, size: 18),
                            title: Text(
                              entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => EntryReader(
                                  worldId: widget.worldId,
                                  worldName: widget.worldName,
                                  entryId: entry.id,
                                ),
                              ),
                            ),
                          ),
                        if (places.isNotEmpty) section('Locations'),
                        for (final place in places)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              CupertinoIcons.map_pin,
                              size: 18,
                            ),
                            title: Text(
                              place.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${place.dimension} · ${coordinateText(place)}',
                            ),
                            onTap: () => showLocationDetails(context, place),
                          ),
                        if (builds.isNotEmpty) section('Projects'),
                        for (final build in builds)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              CupertinoIcons.hammer,
                              size: 18,
                            ),
                            title: Text(
                              build.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(build.status),
                            onTap: () => showProjectDetails(
                              context,
                              worldId: widget.worldId,
                              id: build.id,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.labelMedium),
  );
}
