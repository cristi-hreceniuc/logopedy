// lib/features/profiles/presentation/profile_details_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/profile_model.dart';
import '../profile_repository.dart';
import '../selected_profile_cubit.dart';
import 'profile_picker_sheet.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key, required this.profile});
  final ProfileCardDto profile;

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late final repo = ProfilesRepository(GetIt.I<DioClient>());
  late Future<List<LessonProgressDto>> _f;

  @override
  void initState() {
    super.initState();
    _f = repo.lessonProgress(widget.profile.id);
  }

  Future<void> _selectThisProfile() async {
    context.read<SelectedProfileCubit>().set(widget.profile.id);
    await GetIt.I<SecureStore>().saveActiveProfileId(widget.profile.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profil activ: ${widget.profile.name}')));
    setState(() {}); // re-desenăm pentru badge
  }

  Future<void> _pickAnotherProfile() async {
    final picked = await showModalBottomSheet<ProfileCardDto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ProfilePickerSheet(),
    );
    if (picked != null && mounted) {
      // opțional: reîncarcă progresul pentru profilul nou
      _f = repo.lessonProgress(picked.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeId = context.watch<SelectedProfileCubit>().state;
    final isActive = activeId == widget.profile.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.name),
        actions: [
          if (!isActive)
            TextButton(
              onPressed: _selectThisProfile,
              child: const Text('Setează activ'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('Activ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                avatar: const Icon(Icons.check, color: Colors.white, size: 18),
                backgroundColor: cs.primary,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAnotherProfile,
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Schimbă profilul'),
      ),
      body: FutureBuilder<List<LessonProgressDto>>(
        future: _f,
        builder: (c, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = s.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Nu există lecții.'));
          }

          // group by submodule
          final bySub = <int, List<LessonProgressDto>>{};
          for (final e in items) {
            bySub.putIfAbsent(e.submoduleId, () => []).add(e);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: bySub.entries.map((entry) {
              final subTitle = entry.value.first.submoduleTitle;
              final lessons = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...lessons.map((l) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: _statusIcon(l.status, cs),
                        title: Text(l.lessonTitle),
                        subtitle: Text('${l.moduleTitle} • Lecția ${l.lessonId}'),
                        trailing: Text(l.status),
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _statusIcon(String status, ColorScheme cs) {
    switch (status) {
      case 'DONE': return Icon(Icons.check_circle, color: cs.primary);
      case 'UNLOCKED': return Icon(Icons.radio_button_unchecked, color: cs.secondary);
      default: return Icon(Icons.lock, color: cs.outline);
    }
  }
}
