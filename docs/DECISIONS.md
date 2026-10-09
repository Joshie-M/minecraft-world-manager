# Development record

## Accepted architecture

- Flutter/Dart across Android, iOS, macOS, Windows and Linux.
- Riverpod connects screens to repositories; Drift owns SQLite and migrations.
- Offline operation with no account or backend, UUID IDs, and UTC timestamps.
- Feature folders separate screens and data operations; avoid extra layers until
  application logic warrants them.
- Image files and world-scoped associations are planned for later work.
- sqlite3 3.x bundles verified native assets; its obsolete sqlite3_flutter_libs
  companion was removed based on the package's upgrade guidance.

## Completed foundation

World dashboard, overview, create/edit/delete, input validation, save feedback and
error handling, adaptive grid, system light/dark theme, SQLite schema version 1,
generated database code, dependency lockfile and all five native platform runners.
Initial metadata: name, edition, description, ID and timestamps.

## Validation

Linux release build and static analysis passed. Seven tests passed, covering disk
CRUD/reopen, invalid input/missing updates, UI creation/edit/deletion, and narrow/wide layouts in both themes at 150% text size. The
compiled app created a world and displayed it after an actual process restart.
Headless smoke data is isolated at /workspace/smoke-data.

## Cloud setup

Pinned Flutter source: abaf9c523780a608bd46686fd5e53740a07077f8.
SDK: /workspace/toolchains/flutter. Required extra network domain:
storage.googleapis.com. Tool caches use writable workspace paths; Flutter
analytics is suppressed. Debian-signed packages are downloaded and extracted to
/workspace/linux-deps/root because this machine cannot install system packages.
Source /workspace/cloud-setup/env.sh to activate the tools. These dependencies and
helpers are outside the app repository and are retained by environment snapshots.

## Known limits and next steps

Other target platforms remain unverified. Native app identity uses the generated
com.example placeholder; choose a permanent identifier before distribution.
No archive/favorite actions or remaining world metadata yet. No backup, image
handling, journal, locations, builds or discoveries yet. Future schema changes
must include upgrade migrations and tests. Next milestone: journal CRUD with
Markdown notes, world isolation, search, save feedback and tests.

## UI redesign

The user prefers a modern, platform-neutral app over default Android styling.
The shared theme now uses neutral backgrounds, restrained forest-green accents,
outlined form fields, compact rounded buttons, and flat bordered cards. Desktop
windows have a library sidebar; smaller windows retain one content column.
World cards use decorative landscape illustrations rather than implying a world
screenshot exists. Overview and editor share the visual language. Deletion uses
red accents and remains confirmed. No persistence changes or extra dependencies.

A short-window empty-state overflow was caught during UI testing and fixed by
making the empty state scroll naturally. Continue refining this direction with
user feedback before adding journal screens. The user reported the original app
running on macOS; the redesigned macOS build still needs their local verification.

Linux release verification exposed incorrect icon glyphs with Flutter's default
font subsetting. Rebuilding with `--no-tree-shake-icons` restored the icons; use
that flag for Linux release builds until the SDK issue is resolved. Debug builds
on the Mac still need the user's visual check.

## macOS-inspired refinement

Supersedes the illustrated-card direction. The library now uses compact world
rows, a quiet sidebar and toolbar, neutral light/dark surfaces, restrained blue
accents, Cupertino line icons and platform system typography. Create/edit/delete
and SQLite persistence remain intact. Added contextual open/edit actions and
Command/Control keyboard shortcuts for creation and saving. See DESIGN.md for
shared design tokens and component rules. Eight tests pass. Native macOS visual
verification remains pending on the user's machine.

## Journal milestone

Schema version 2 adds world-owned JournalEntries with stable UUIDs, title,
Markdown body, occurrence time, and creation/update timestamps. A version-1
migration test verifies existing worlds survive. Foreign keys cascade world
removal to its entries; updates/deletes require both entry and world IDs. Search
is literal and case-insensitive across title/body within the selected world.
Chronological order uses occurrence time, newest first.

Shared desktop styling extends to a timeline and focused full-page editor.
flutter_markdown_plus renders Markdown locally; remote images are not loaded.
Explicit save feedback and dirty-editor discard confirmation are implemented;
crash recovery/autosaved drafts are deferred and the editor says to save before
closing the app. Missing-parent or deleted-entry saves preserve editor text and
show errors. Images, tags, coordinate/link associations and date filters remain
later increments. Next milestone: named coordinates.

Journal validation: 13 tests passed, analysis found no issues, and the Linux
release build succeeded. The compiled UI migrated a version-1 demo database,
preserved three worlds, saved a Markdown entry, rendered its bold text and
displayed the entry after process restart. macOS journal validation remains local.

## Journal navigation correction

User reported successful macOS saving but entry clicks unexpectedly opened the
editor. Saved entries now open a dedicated reading view with formatted Markdown,
date and explicit Edit entry action. The reader follows the live world-scoped
stream so saved edits appear immediately. World overviews show the three most
recent entries with direct reading links; Open journal retains the full searchable
timeline. No schema changes. Responsive journal flow tests now verify reading
from both the timeline and overview, explicit editing and return navigation.
