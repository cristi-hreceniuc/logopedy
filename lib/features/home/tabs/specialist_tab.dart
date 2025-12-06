// lib/features/home/tabs/specialist_tab.dart
import 'package:flutter/material.dart';

import '../../content/presentation/modules_page.dart';

class SpecialistTab extends StatelessWidget {
  const SpecialistTab({super.key, required this.profileId});
  final int profileId;

  @override
  Widget build(BuildContext context) {
    return ModulesPage(
      profileId: profileId,
      targetAudience: 'SPECIALIST',
    );
  }
}

