// lib/pages/home_shell.dart
//
// HomeShell: keeps the 3 main tabs (Documents / Scan / Profile) alive in an
// IndexedStack so switching tabs is INSTANT and does not rebuild the page or
// re-read Hive every time (the old Navigator.pushReplacement caused lag).
//
// BottomNav looks up this shell via `HomeShell.switchTab(context, index)`.
// If no shell is found (e.g. a page opened standalone), BottomNav falls back
// to its old push-based navigation, so nothing breaks.

import 'package:flutter/material.dart';

import 'documents_page.dart';
import 'profile_page.dart';
import 'scan_page.dart';

class HomeShell extends StatefulWidget {
  final int initialIndex;

  const HomeShell({super.key, this.initialIndex = 0});

  /// Switch the active tab from anywhere below the shell (used by BottomNav).
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<HomeShellState>();
    state?.setTab(index);
  }

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  void setTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // All three pages stay alive; only the visible one is shown.
    // Each page keeps its own Scaffold + BottomNav, so the highlighted tab
    // is correct automatically (Documents=0, Scan=1, Profile=2).
    return IndexedStack(
      index: _index,
      children: const [DocumentsPage(), ScanPage(), ProfilePage()],
    );
  }
}
