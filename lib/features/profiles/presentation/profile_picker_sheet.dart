// lib/features/profiles/presentation/profile_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/dio_client.dart';
import '../models/profile_model.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/state/active_profile.dart';
import '../profile_repository.dart';
import '../selected_profile_cubit.dart';

class ProfilePickerSheet extends StatefulWidget {
  const ProfilePickerSheet({super.key});
  @override
  State<ProfilePickerSheet> createState() => _ProfilePickerSheetState();
}

class _ProfilePickerSheetState extends State<ProfilePickerSheet> {
  late final repo = ProfilesRepository(GetIt.I<DioClient>());
  late Future<List<ProfileCardDto>> _f;

  @override
  void initState() {
    super.initState();
    _f = repo.list();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeId = context.watch<SelectedProfileCubit>().state;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Text('Alege profilul', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            FutureBuilder<List<ProfileCardDto>>(
              future: _f,
              builder: (_, s) {
                if (!s.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  );
                }
                final list = s.data!;
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nu ai încă profile. Creează unul din ecranul Profile.'),
                  );
                }

                // Grid cu carduri mai mari
                return Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .78,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final selected = p.id == activeId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          context.read<SelectedProfileCubit>().set(p.id);
                          await GetIt.I<SecureStore>().saveActiveProfileId(p.id);
                          GetIt.I<DioClient>().setActiveProfile(p.id);
                          
                          // Update the active profile service
                          await GetIt.I<ActiveProfileService>().set(p.id);

                          if (!mounted) return;
                          Navigator.pop(context, p); // returnează profilul selectat
                        },
                        child: Stack(
                          children: [
                            Card(
                              elevation: selected ? 1.5 : 0.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: CircleAvatar(
                                        radius: 36,
                                        backgroundImage: (p.avatarUri != null && p.avatarUri!.isNotEmpty)
                                            ? NetworkImage(p.avatarUri!)
                                            : null,
                                        child: (p.avatarUri == null || p.avatarUri!.isEmpty)
                                            ? Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(p.name, textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
                                    const Spacer(),
                                    FilledButton(
                                      onPressed: () async {
                                        context.read<SelectedProfileCubit>().set(p.id);
                                        await GetIt.I<SecureStore>().saveActiveProfileId(p.id);
                                        GetIt.I<DioClient>().setActiveProfile(p.id);
                                        
                                        // Update the active profile service
                                        await GetIt.I<ActiveProfileService>().set(p.id);

                                        if (!mounted) return;
                                        Navigator.pop(context, p);
                                      },
                                      child: Text(selected ? 'Selectat' : 'Selectează'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (selected)
                              Positioned(
                                top: 10, right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check, size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Activ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
