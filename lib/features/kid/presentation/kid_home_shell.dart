import 'package:flutter/material.dart';
import '../../home/tabs/modules_tab.dart';
import 'homework_tab.dart';
import 'kid_account_tab.dart';

class KidHomeShell extends StatefulWidget {
  final int profileId;
  final String profileName;
  final bool isPremium;

  const KidHomeShell({
    super.key,
    required this.profileId,
    required this.profileName,
    required this.isPremium,
  });

  @override
  State<KidHomeShell> createState() => _KidHomeShellState();
}

class _KidHomeShellState extends State<KidHomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      ModulesTab(profileId: widget.profileId, isKid: true),
      HomeworkTab(profileId: widget.profileId),
      KidAccountTab(profileName: widget.profileName, isPremium: widget.isPremium),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined, color: cs.onSurface.withOpacity(0.6)),
            selectedIcon: Icon(Icons.grid_view_rounded, color: cs.primary),
            label: 'Module',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: cs.onSurface.withOpacity(0.6)),
            selectedIcon: Icon(Icons.assignment_rounded, color: cs.primary),
            label: 'Teme',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: cs.onSurface.withOpacity(0.6)),
            selectedIcon: Icon(Icons.person_rounded, color: cs.primary),
            label: 'Cont',
          ),
        ],
      ),
    );
  }
}

