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

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = _index == index;
    final cs = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => setState(() => _index = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEA2233) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFEA2233).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.white : const Color(0xFF2D72D2),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF2D72D2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const ProfilesTab(),
      ModulesTab(profileId: widget.profileId),
      const AccountTab(),
    ];

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => prev.authenticated && !curr.authenticated,
      listener: (context, state) {
        // Log out -> LogopedyApp te duce automat la LoginPage
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.group_outlined, Icons.group, 'Profile'),
                  _buildNavItem(1, Icons.menu_book_outlined, Icons.menu_book, 'Module'),
                  _buildNavItem(2, Icons.person_outline, Icons.person, 'Contul meu'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
