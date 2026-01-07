// lib/features/home/tabs/modules_tab.dart
import 'package:flutter/material.dart';

import '../../content/presentation/modules_page.dart';

class ModulesTab extends StatelessWidget {
  const ModulesTab({
    super.key, 
    required this.profileId,
    this.isKid = false,
  });
  
  final int profileId;
  final bool isKid;

  @override
  Widget build(BuildContext context) {
    return ModulesPage(profileId: profileId, isKid: isKid);
  }
}
