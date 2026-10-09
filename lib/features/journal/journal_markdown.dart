import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import '../../core/database/app_database.dart';
import '../locations/location_repository.dart';
import '../locations/locations_screen.dart';
import '../projects/project_repository.dart';
import '../projects/projects_screen.dart';
import 'journal_tags.dart';

class JournalMarkdown extends ConsumerWidget {
  const JournalMarkdown({super.key, required this.worldId, required this.data});
  final String worldId, data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MarkdownBody(
    data: data,
    selectable: true,
    builders: {'a': MentionLinkBuilder(worldId)},
    imageBuilder: (_, _, _) =>
        const Text('Image attachments are coming in a later milestone.'),
  );
}

class MentionLinkBuilder extends MarkdownElementBuilder {
  MentionLinkBuilder(this.worldId);
  final String worldId;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final uri = Uri.tryParse(element.attributes['href'] ?? '');
    final style = (parentStyle ?? Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );
    if (uri == null ||
        uri.scheme != 'world-manager' ||
        !['location', 'project'].contains(uri.host) ||
        uri.pathSegments.length != 1) {
      return Text(element.textContent, style: style);
    }
    final id = uri.pathSegments.single;
    return Consumer(
      builder: (context, ref, _) {
        final locations =
            ref.watch(locationsProvider(worldId)).asData?.value ?? <Location>[];
        final projects =
            ref.watch(projectsProvider(worldId)).asData?.value ?? <Project>[];
        Location? location;
        Project? project;
        for (final l in locations) {
          if (l.id == id) location = l;
        }
        for (final p in projects) {
          if (p.id == id) project = p;
        }
        final kind = uri.host == 'location' ? 'Location' : 'Project';
        final l = location, p = project;
        final available = uri.host == 'location' ? l != null : p != null;
        return RecordPreview(
          name: uri.host == 'location'
              ? l?.name ?? element.textContent
              : p?.name ?? element.textContent,
          kind: kind,
          summary: available
              ? uri.host == 'location'
                    ? '${l!.dimension} · ${coordinateText(l)}'
                    : projectSummary(p!, locations)
              : '$kind is no longer available.',
          notes: uri.host == 'location' ? l?.notes ?? '' : p?.notes ?? '',
          child: Semantics(
            link: true,
            child: InkWell(
              key: ValueKey('mention-${uri.host}-$id'),
              onTap: () {
                if (!available) {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(element.textContent),
                      content: Text(
                        '$kind is no longer available in this world.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } else if (uri.host == 'location') {
                  showLocationDetails(context, l!);
                } else {
                  showProjectDetails(context, worldId: worldId, id: id);
                }
              },
              child: Text(element.textContent, style: style),
            ),
          ),
        );
      },
    );
  }
}
