# tab_switcher

Full-screen tabs like Chrome for Android, for Flutter apps that juggle many screens at once
(an IDE, a browser, an SSH client…). Version 2 is developed inside [nux](https://github.com/nuc134r/nux).

- Swipe the header sideways to switch tabs (the page follows your finger), swipe it down for the grid.
- Grid of cards with previews; swipe a card away to close it, with **Undo**. Long-press for
  pin / close others / your own actions. Tabs with a `group` are shown together.
- **State preservation**: the current tab and the `keepAlive` most recently used ones stay mounted
  (offstage), so scroll positions, text fields and animations survive switching. Older tabs are
  *parked*: unmounted, shown by a preview image, and get `onParked` / `onResumed` calls. Keep state
  that must outlive parking (sessions, buffers) in the tab object itself.
- Unsaved-changes guard: `hasUnsavedChanges` + `controller.confirmClose`.
- Wide screens get a tab strip; back closes the grid first.

```dart
class NoteTab extends SwitcherTab {
  NoteTab(this.id, this.title);
  @override final String id;
  @override final String title;
  @override Widget buildContent(BuildContext context) => NoteEditor(tab: this);
}

final tabs = TabSwitcherController(keepAlive: 3)..open(NoteTab('1', 'Groceries'));

TabSwitcher(
  controller: tabs,
  headerBuilder: (context, tab) => Row(children: [
    Expanded(child: Text(tab?.title ?? 'Tabs')),
    TabCountButton(controller: tabs),
  ]),
);
```

Version 1.0.1 is on pub.dev; 2.0 will be published from this folder once it settles.
