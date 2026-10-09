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

## Saved locations milestone

Schema version 3 adds Locations (UUID, world ID, name, X/Y/Z, dimension, notes,
creation/update timestamps), with migration tests preserving existing world and
journal data. Foreign keys cascade world deletion. Updates/deletes require both
location and world IDs. Signed decimal coordinates are validated as 32-bit ints,
including negative Y; no edition-dependent height bounds are imposed.

Locations have explicit reading, editing, delete confirmation, dirty-editor
confirmation, name sorting, literal case-insensitive search and dimension filters.
Standard dimensions are Overworld/Nether/End; custom names are supported and
filter labels distinguish custom names from the All dimensions option. Copying
uses the platform clipboard and reports success/failure. World overviews expose
a small location summary with direct read/copy actions. No new package dependency.

Verified: all 18 tests passed across repositories and responsive screens; analysis
found no issues and the Linux release build passed. The compiled UI upgraded the
existing demo database, preserved worlds/journal data, saved a location and copied
its exact coordinates through the real system clipboard. macOS location verification remains
on the user's machine. Future work: images, then tags/categories/favorites and
optional portal travel planning. No coordinate conversion is applied to copying.

## Projects milestone

The user confirmed saved locations working on macOS and approved world projects.
Schema version 4 adds Projects: UUID, world ID, name, plain-text notes, one of
Planned/In progress/Complete, optional location ID, and creation/update timestamps.
World deletion cascades; location deletion sets the project link to null while
preserving its notes. Repository writes validate that links belong to the same
world within a transaction, and updates/deletes require both project and world IDs.

The compact list uses literal case-insensitive name/note search, status filtering,
and most-recent-update ordering. Saved projects open a live reading dialog with an
explicit editor action and coordinate copying for their current linked location.
Editors support explicit save, Command/Control+Enter, unsaved-discard confirmation,
and retained input on save errors. World overviews expose the latest three projects.
No new dependency. Materials/checklists and images are later features.

Verified: analysis passed, all 22 tests passed, Linux release build succeeded.
A schema-3 disk fixture verifies preservation of worlds/journal/locations, project
edits across reopen, and unlinking on location deletion. Responsive project UI
flows cover reading, editing, filtering, discard, and delete confirmation in mobile
dark and desktop light layouts. Older overview UI tests now allow save notifications
to clear and check persisted world data after cancellation, since extra sections
change which rows are visible. The compiled app migrated the isolated demo database
and preserved three worlds, one journal entry and one location. A separately seeded
demo project rendered its notes and linked coordinates in the compiled reading UI.
Synthetic keyboard input did not reach the fields in this headless session; compiled
UI creation was not verified. macOS project validation remains on the user's machine.

## Record relationships and journal tags

The user confirmed projects working on macOS and requested reverse navigation
from locations to projects plus journal tags with hover cards. Location reading
dialogs now follow live world-owned locations and projects; all linked projects,
including Complete, are shown with status and explicit reading navigation.

Schema 5 adds JournalLocationTags and JournalProjectTags with composite primary
keys and cascading foreign keys to entries and tagged records. Journal saves
validate reference ownership and save content and both tag sets atomically.
Omitting a tag set preserves it; passing an empty set removes that type's tags.
Deleting a record removes its associations, preserving journal text. Tag streams
join entries to enforce world scope. No new package dependency.

Editors hydrate saved associations before enabling save, preserve text on load
or write errors, and include tag selections in dirty tracking. Missing selected
records appear as removable unavailable chips. Tag picker and reader share compact
preview cards, using tooltip hover on desktop; reader tags open live detail dialogs
on click/tap. Project cards include status, notes and linked location coordinates.
These tags are record links attached to the entry, not inline Markdown mentions
or free-form labels. Save errors are visible above the editor's scrolling content.

Verification: schema-4 migration/reopen, atomic ownership rejection, replacement,
reference deletion/entry deletion/world deletion cleanup, responsive mobile dark
and desktop light flows, hover cards, tag hydration/removal, tag-only dirty checks,
live project rename/navigation, completed-project display, and stale-tag save-error
recovery. Existing CRUD tests remain enabled. macOS verification of this increment
remains local to the user's machine.

All 26 tests passed; analysis is clean and the final Linux release build passed.
The compiled app upgraded the isolated demo database from schema 4 to 5, preserving
three worlds, a journal entry, a location and a project. Demo tag associations were
seeded separately for the visual check; the compiled reading view displayed their
hover card and the location's project list. Screenshots are committed under docs.
Headless GTK startup required GDK_BACKEND=x11 with Xvfb; the README records that
runtime choice. No real platform-specific macOS build was run in the cloud.

## Inline @mention refinement

User clarified that references should live within journal sentences with @autocomplete,
rather than separate chips. The separate picker is removed. MentionController keeps
visible @labels and tracked UTF-16 ranges while serializing stable IDs as escaped
Markdown links (world-manager://location/<id> and .../project/<id>). Changes before
links shift their ranges; edits within a link unbind it; deleting a link removes its
association on save. Boundary Markdown formatting preserves whole mentions.

Autocomplete is anchored at the caret in an overlay with world-scoped, case-insensitive
name filtering, explicit kind/detail labels, mouse/touch selection, Up/Down navigation,
Enter/Tab selection and Escape dismissal. Emails and code samples remain literal.
Selection and IME composition do not trigger suggestions. Reader and editor preview
share a custom Markdown link builder and live record widgets, with highlighted inline
links, existing hover cards and detail dialogs. Markdown's builder cache does not
observe record edits, so the inline record widget subscribes directly to live streams.
External links remain display-only and remote images remain disabled.

No schema change. Existing chip associations are converted on editor hydration into
inline links appended on a Related: line; only explicit save persists the conversion.
Unedited legacy entries remain readable. The normal save updates body and associations
atomically using the existing repository. Deleted mentions keep their text and show
unavailable details; saving filters missing associations without removing journal prose.
markdown 7.3.1 was already installed transitively and is now declared directly for the
custom builder's typed AST interface; its version and checksum are unchanged.

Validation covers readable-label round trips, escaping, repeated names, range movement,
deletions, code samples, Markdown boundaries, desktop light/mobile dark autocomplete,
email/code exclusions, no matches, Escape, keyboard and tap insertion, preview/read
hover navigation, reverse project lists, editing saved mentions, deleted-record handling,
and legacy-link conversion. The full suite has 33 tests. macOS verification remains local.

Final analysis and Linux build passed. The compiled desktop app accepted @riv,
selected project and location suggestions through the keyboard, saved the resulting
inline links and both associations, and rendered the project hover card in place.
The screenshots show the actual autocomplete menu and saved inline hover card.

## Project checklist milestone

The user approved task checklists before image attachments. Schema 6 adds
ProjectTasks with stable UUID, project FK (cascade), title, completed flag, and
integer position. Repository reads join projects to enforce world scope; every
write validates parent ownership and scopes task IDs to the project inside a
transaction. New positions are allocated in the same transaction to preserve
insertion order. Task changes update the parent project's updatedAt but do not
change its status. Rename preserves completion and position.

The shared project reading dialog includes a compact checklist, completion count,
Add task action, checkbox toggles, task menu edit/delete, and delete confirmation.
It is available through world projects, location lists and journal mentions.
Writes disable pending row controls and surface failure without optimistic model
changes. Task dialogs support Enter and Command/Control+Enter, validation, retained
text after failure, and dirty discard confirmation. No new package dependency.

Verified: all 37 tests passed and static analysis found no issues. New checks cover
schema-5 migration preserving journal links, task edits and completion after disk
reopen, insertion order after deletion, project/world cascade cleanup, invalid/stale
IDs, world/project ownership, responsive dark mobile/light desktop CRUD, cancel
and discard, completion toggles, reopening the reader, and deleted-parent save
failure retaining input. Linux build and macOS verification are reported separately.
