// lib/features/home/tabs/profiles_tab.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../../profiles/data/profiles_repository.dart';
import '../../profiles/models/profile_model.dart';
import '../../profiles/presentation/profile_details_page.dart';

class ProfilesTab extends StatefulWidget {
  const ProfilesTab({super.key});

  @override
  State<ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<ProfilesTab> {
  late final repo = ProfilesRepository(GetIt.I<DioClient>());
  late Future<List<ProfileCardDto>> _f;

  @override
  void initState() {
    super.initState();
    _f = repo.listProfiles();
  }

  Future<void> _refresh() async {
    setState(() { _f = repo.listProfiles(); });
    await _f;
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final avatarCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left:16,right:16,
            top:16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Profil nou', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nume profil')),
            const SizedBox(height: 8),
            TextField(controller: avatarCtrl, decoration: const InputDecoration(labelText: 'Avatar URL (opțional)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final created = await repo.createProfile(name: name, avatarUri: avatarCtrl.text.trim().isEmpty ? null : avatarCtrl.text.trim());
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil creat')));
                  await _refresh();
                },
                child: const Text('Creează'),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: FutureBuilder<List<ProfileCardDto>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = s.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.group, size: 56, color: cs.outline),
                  const SizedBox(height: 12),
                  Text('Nu ai încă profile.', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('Adaugă un profil nou folosind butonul + de mai jos.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(.7))),
                ]),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  return _ProfileCard(
                    p: p,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileDetailsPage(profile: p)),
                    ),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateSheet,
          icon: const Icon(Icons.add),
          label: const Text('Profil nou'),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.p, required this.onTap});
  final ProfileCardDto p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: cs.shadow.withOpacity(.04), blurRadius: 8, offset: const Offset(0,4))]
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: p.premium
                    ? Icon(Icons.star_rounded, color: cs.primary, size: 22)
                    : const SizedBox(height: 22, width: 22),
              ),
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primary.withOpacity(.1),
                  backgroundImage: (p.avatarUri != null && p.avatarUri!.isNotEmpty)
                      ? NetworkImage(p.avatarUri!)
                      : null,
                  child: (p.avatarUri == null || p.avatarUri!.isEmpty)
                      ? Icon(Icons.person, color: cs.primary, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(p.name, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              LinearProgressIndicator(
                value: (p.totalLessons==0) ? 0 : (p.completedLessons / p.totalLessons),
                borderRadius: BorderRadius.circular(10),
                minHeight: 8,
              ),
              const SizedBox(height: 6),
              Text('${p.progressPercent}% complet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurface.withOpacity(.7))),
            ],
          ),
        ),
      ),
    );
  }
}
