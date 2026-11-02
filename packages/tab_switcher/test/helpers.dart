import 'package:flutter/material.dart';
import 'package:tab_switcher/tab_switcher.dart';

/// A tab whose content is a counter with widget-local state.
class CounterTab extends SwitcherTab {
  CounterTab(this.id, {this.unsaved = false, this.group});

  @override
  final String id;

  @override
  final String? group;

  bool unsaved;
  int parked = 0, resumed = 0;
  bool disposed = false;

  @override
  String get title => 'Tab $id';

  @override
  bool get hasUnsavedChanges => unsaved;

  @override
  Widget buildContent(BuildContext context) => _Counter(key: ValueKey('counter-$id'), label: id);

  @override
  void onParked() => parked++;

  @override
  void onResumed() => resumed++;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => setState(() => count++),
          child: Text('${widget.label}:$count'),
        ),
      );
}

Widget app(TabSwitcherController c, {Size? size}) => MaterialApp(
      home: TabSwitcher(
        controller: c,
        headerBuilder: (context, tab) => Row(
          children: [
            Expanded(child: Text(tab == null ? 'grid' : 'header ${tab.id}')),
            TabCountButton(controller: c),
          ],
        ),
      ),
    );
