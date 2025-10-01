// lib/features/content/presentation/modules_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/dio_client.dart';
import '../content_repository.dart';
import '../models/dtos.dart';
import '../models/modules_details_dto.dart';
import 'submodule_page.dart';

class ModulesPage extends StatefulWidget {
  const ModulesPage({super.key, required this.profileId});
  final int profileId;

  @override
  State<ModulesPage> createState() => _ModulesPageState();
}

class _ModulesPageState extends State<ModulesPage> {
  late final repo = ContentRepository(GetIt.I<DioClient>());
  late Future<List<ModuleDto>> _f;

  @override
  void initState() {
    super.initState();
    _f = repo.modules(widget.profileId);
  }

  Future<void> _openModule(ModuleDto m) async {
    // 1) ia detaliile modulului (lista de submodule)
    late final ModuleDetailsDto md;
    try {
      md = await repo.moduleDetails(widget.profileId, m.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu pot încărca submodulele: $e')),
      );
      return;
    }

    if (!mounted) return;

    // 2) dacă nu are submodule, anunță
    if (md.submodules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modulul nu are submodule disponibile.')),
      );
      return;
    }

    // 3) arată un bottom sheet cu lista de submodule
    final chosen = await showModalBottomSheet<SubmoduleLite>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42, height: 5,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(m.title,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: md.submodules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = md.submodules[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: Theme.of(ctx).colorScheme.surface,
                    title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: (s.introText == null || s.introText!.isEmpty)
                        ? null
                        : Text(s.introText!),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || chosen == null) return;

    // 4) navighează către SubmodulePage cu submoduleId corect
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmodulePage(
          profileId: widget.profileId,
          submoduleId: chosen.id,
          title: chosen.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Module')),
      body: FutureBuilder<List<ModuleDto>>(
        future: _f,
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final modules = s.data!;
          if (modules.isEmpty) return const Center(child: Text('Nu sunt module'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final m = modules[i];
              return InkWell(
                onTap: () => _openModule(m),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: m.introText == null ? null : Text(m.introText!),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
