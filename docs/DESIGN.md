# Interface design system

## Direction

A quiet desktop library, inspired by Things, Bear and Apple Notes. Prioritize world
names and notes. Avoid promotional headings, decorative world illustrations,
large cards, visible panel borders and floating actions.

## Shared tokens and components

- Typography: Apple platforms use CupertinoSystemText through Flutter's Cupertino
  theme (the system font mapping); Windows uses Segoe UI, Linux/Android use the
  platform fallback. Body 14–15 px, toolbar/title 17 px, detail heading 24 px.
- Surfaces: white content and soft gray sidebar/fields in light mode; neutral
  charcoal content and a slightly lighter sidebar/fields in dark mode.
- Accent: restrained blue for selection, focus and the primary save action.
  Destructive confirmation retains a red action.
- Geometry: 8 px standard radius, 6 px fields, 12 px dialogs. Main inset 24 px,
  row spacing 12–14 px. No card elevation or decorative translucency.
- Controls: desktop buttons 32 px minimum, mobile buttons 44 px minimum. Shared
  ThemeData controls focus borders, hover treatment, menus and dialogs. Fixed labels above fields prevent floating-label motion; a focus outline keeps
  keyboard location clear. Standard Flutter keyboard focus and accessible semantics remain available.
- Icons: Cupertino's consistent line icons, bundled via cupertino_icons. These
  are cross-platform Flutter icons, not a dependency on Apple's SF Symbols API.
- Navigation: 216 px sidebar at widths >=900 px. Smaller screens omit the sidebar
  and use the toolbar plus detail back action. Lists and forms remain scrollable.

`lib/app/theme.dart` owns colors, typography and geometry. `AppShell` owns the
adaptive sidebar. World rows use the shared theme and open contextual menus for
opening/editing. The overview retains confirmed deletion and unchanged storage.

## Keyboard interactions

- Command+N / Control+N: create a world from the library.
- Command+Enter / Control+Enter: save the active world editor.
- Escape: dismiss an idle editor/dialog through Flutter's dialog handling.
- Tab/Shift+Tab: navigate controls.

No account, remote service, schema or repository operation changed. Native menu
bars, titlebar vibrancy and custom window chrome are deferred: the current UI
uses shared Flutter widgets with native typography and visual cues rather than
claiming every control is an operating-system widget.

## Validation limits

Eight tests exercise disk CRUD, invalid input, keyboard create/save, narrow/wide
light/dark layouts at enlarged text size, and UI CRUD/deletion confirmation.
Linux is the cloud build target. macOS visual appearance and other native targets
need local verification; the user's existing macOS install can test this update.
