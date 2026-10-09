# Minecraft World Manager

An offline Flutter companion for Minecraft. The app supports world management and world-scoped journals with Markdown
notes, saved coordinates, world projects, search, and local SQLite persistence.

## Verified in this cloud environment

- Linux release build succeeded.
- Static analysis passed with no issues.
- Twenty-six tests passed: disk CRUD/reopen, invalid data handling, world/journal UI CRUD, keyboard shortcuts,
  world isolation, migrations, coordinate validation/clipboard copying, project/location relationships, journal tags/hover previews, and responsive light/dark layouts.
- The compiled desktop app created a world through its UI. After stopping and
  restarting the process, the world appeared again on its dashboard. A journal
  entry was also saved through the compiled UI and displayed after restart.

Android, iOS, macOS and Windows runners are generated but those platforms have
not been built or tested in this cloud environment. The user confirmed worlds, journals, saved locations and projects working on macOS.
Journal tags and location project lists still need local macOS verification. This is not the full MVP.

## Design preview

![Redesigned dashboard with demonstration worlds](docs/screenshots/dashboard.png)

A compact world library with a quiet sidebar and contextual actions. Your saved
worlds and notes remain local. See [the design system](docs/DESIGN.md) and
[the editor screenshot](docs/screenshots/editor.png).

Keyboard shortcuts: Command+N (Control+N elsewhere) creates a world;
Command+Enter / Control+Enter saves the active editor.

## Cloud development commands

```bash
cd /workspace/minecraft-world-manager
source /workspace/cloud-setup/env.sh
flutter pub get --enforce-lockfile
# Regenerate database code after intentional schema changes:
dart run build_runner build
flutter analyze
flutter test
flutter build linux --no-tree-shake-icons
flutter run -d linux
```

A graphical display is required to view the application. For internal headless
validation, start Xvfb and run the compiled application:

```bash
source /workspace/cloud-setup/env.sh
Xvfb :99 -screen 0 1280x900x24 -nolisten tcp &
export DISPLAY=:99
export GDK_BACKEND=x11
export XDG_DATA_HOME=/workspace/smoke-data
cd /workspace/minecraft-world-manager
./build/linux/x64/release/bundle/minecraft_world_manager
```

Use a separate `XDG_DATA_HOME` for smoke checks to preserve personal app data.
Stop only processes you started when done. No web preview is provided.

## On your own computer

Install Flutter stable and your platform's native build prerequisites, then run:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d <device-id>
```

Linux requires clang, CMake, Ninja, pkg-config and GTK development headers.
Windows requires Visual Studio C++ build tools. Apple builds require macOS/Xcode;
Android requires the Android SDK and compatible JDK. Use `flutter doctor` and
`flutter devices` to inspect your machine. Cloud-specific paths above are not
required on your own computer.

SQLite lives in the OS application-support directory; seeds and accounts are not
required. See [development notes](docs/DECISIONS.md) for architecture and next steps.

## Journal

[Timeline preview](docs/screenshots/journal.png) · [Markdown preview](docs/screenshots/journal-entry.png)

Open a world, choose **Open journal**, then **New entry**. Add a title, notes and
an optional adjusted date/time. Use the bold/italic/list buttons or Markdown,
then **Preview notes** to read the formatted result. **Save entry** (Command+Enter
or Control+Enter) writes locally and returns to the timeline. Search matches title
or note text without mixing worlds. Click a saved entry to read its formatted notes. Choose **Edit entry** when you
want to change it; the entry menu also provides edit/delete actions. The world
overview shows its three most recent entries, which open directly in reading view.

Schema version 2 adds journal entries automatically and preserves existing worlds.
Deleting a world now deletes its journal entries after confirmation. Editing an
entry preserves its original creation timestamp. Leaving an editor with changes
asks before discarding. Unsaved edits are not crash-recovery drafts: save before
quitting the app. Image attachments and free-form labels are future features;
Markdown images do not fetch remote files, and links are currently display-only.

## Saved locations

[Locations preview](docs/screenshots/locations.png)

Open a world and choose **Open locations** in its Saved locations section. Create
or edit a named place with signed whole-number X/Y/Z coordinates, a standard or
custom dimension, and optional notes. Click a location to read its details; use
its actions menu to edit or delete. The copy button copies `X Y Z` with spaces,
without a teleport command or dimension conversion. Search covers names, notes,
dimensions and coordinates. Locations are sorted by name and can be filtered by
dimension. The world overview shows up to three saved locations with direct
view/copy actions.

Schema version 3 adds locations without replacing worlds or journals. Removing
a world also removes its owned locations after confirmation. Coordinates accept
32-bit signed decimal integers rather than imposing edition-specific world limits.
Unsaved editor changes require confirmation before discarding. Tags, categories,
favorites, images and an optional Nether travel helper can follow later.

## Projects

Open a world → **Open projects** → **New project**. Give the project a name,
optional plain-text notes, and a status: Planned, In progress, or Complete. You
can link one saved location from the same world; its current coordinates appear
in the reading view with a copy action. Click a project to read it, then choose
**Edit project** to make changes. The actions menu offers edit/delete. Search
matches names and notes, and the status filter narrows the list. Projects are
ordered by latest update; the world overview shows the latest three.

Schema version 4 adds projects while preserving worlds, journals and locations.
Deleting a linked location removes the link and keeps the project and notes.
Deleting a world also deletes its projects after confirmation. Changes require
explicit saving (Command+Enter / Control+Enter); leaving a changed editor asks
before discarding. Save before quitting—crash-recovery drafts are not implemented.
Task checklists, materials, images, free-form labels and multiple location links are deferred.

## Journal tags & location projects

[Journal hover card](docs/screenshots/journal-tags.png) · [Location project list](docs/screenshots/location-projects.png)

Locations now show **Projects at this location**, including completed projects
with their status. Click a project in this list to read it. The list follows
project edits and location changes automatically.

When creating or editing a journal entry, use **Tag locations & projects** to
select any number of saved records from that world, then **Save entry**. Click a
selected tag again to remove it. These are links to records, not arbitrary text
labels or inline Markdown mentions. Saved entries show compact tags: hover on
desktop for a mini card, or click/tap for full details. Previews include location
coordinates/dimension/notes or project status/notes and its linked location.
Hover previews are also available while choosing tags in the editor.

Schema version 5 adds tag association tables without replacing existing records.
Entry content and tag changes save together. Renaming or editing a tagged record
updates its preview; deleting it removes its tags while preserving the journal
text. If a record disappears during editing, remove its unavailable tag before
saving. Tags participate in unsaved-change confirmation. No new package required.
