import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/data/presentation/cubit/auth_cubit.dart';
import 'tabs/account_tab.dart';
import 'tabs/profiles_tab.dart';
import 'tabs/modules_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profileId});
  final int profileId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const AccountTab(),
      const ProfilesTab(),
      ModulesTab(profileId: widget.profileId), // placeholder
    ];

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => prev.authenticated && !curr.authenticated,
      listener: (context, state) {
        // Log out -> LogopedyApp te duce automat la LoginPage
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Contul meu',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Module',
            ),
          ],
        ),
      ),
    );
  }
}
