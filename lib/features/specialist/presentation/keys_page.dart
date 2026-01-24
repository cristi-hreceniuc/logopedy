import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/dio_client.dart';
import '../../profiles/models/profile_model.dart';
import '../../profiles/profile_repository.dart';
import '../data/keys_api.dart';
import '../models/license_key_dto.dart';
import '../models/key_stats_dto.dart';

class KeysPage extends StatefulWidget {
  const KeysPage({super.key});

  @override
  State<KeysPage> createState() => _KeysPageState();
}

class _KeysPageState extends State<KeysPage> {
  late final KeysApi _api;
  List<LicenseKeyDTO>? _keys;
  KeyStatsDTO? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = KeysApi(GetIt.I<DioClient>());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([_api.listKeys(), _api.getKeyStats()]);

      if (mounted) {
        setState(() {
          _keys = results[0] as List<LicenseKeyDTO>;
          _stats = results[1] as KeyStatsDTO;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Nu am putut încărca cheile. Încearcă din nou.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetKey(LicenseKeyDTO key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetare cheie'),
        content: Text(
          'Ești sigur că vrei să resetezi cheia pentru "${key.profileName}"?\n\n'
          'Aceasta va șterge profilul și tot progresul asociat. Cheia va putea fi refolosită.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Resetează'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.resetKey(key.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cheia a fost resetată cu succes')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Eroare: ${e.toString()}')));
        }
      }
    }
  }

  void _copyKey(String keyUuid) {
    Clipboard.setData(ClipboardData(text: keyUuid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cheia a fost copiată'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareKey(BuildContext ctx, String keyUuid, String? profileName) {
    final childText = profileName != null && profileName.isNotEmpty
        ? 'pentru $profileName'
        : 'pentru copilul tău';
    
    final shareText = '''🎓 Iată cheia de licență $childText pentru aplicația Logopedy!

🔑 Cheie: $keyUuid

Pași de activare:
1. Descarcă aplicația Logopedy
2. Apasă pe "Am o cheie de acces"
3. Introdu cheia de mai sus

Mulțumim că folosești Logopedy! 💚''';

    // Get the button position for iPad share sheet anchor
    final box = ctx.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    Share.share(
      shareText,
      subject: 'Cheie Logopedy',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _activateKey(LicenseKeyDTO key) async {
    // Fetch profiles that don't have a key linked (we need to check on server)
    // For now, we'll show all profiles and let the user choose
    final profilesRepo = ProfilesRepository(GetIt.I<DioClient>());

    List<ProfileCardDto> profiles;
    try {
      profiles = await profilesRepo.list();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare la încărcarea profilelor: ${e.toString()}'),
          ),
        );
      }
      return;
    }

    if (profiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu ai profile create. Creează un profil mai întâi.'),
          ),
        );
      }
      return;
    }

    // Show profile selection dialog
    final selectedProfile = await showDialog<ProfileCardDto>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selectează un profil'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF2F3F6),
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(profile.name),
                subtitle: profile.premium
                    ? Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('Premium', style: TextStyle(fontSize: 12)),
                        ],
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(profile),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anulează'),
          ),
        ],
      ),
    );

    if (selectedProfile == null) return;

    // Confirm activation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmare activare'),
        content: Text(
          'Vrei să asociezi cheia cu profilul "${selectedProfile.name}"?\n\n'
          'Copilul va putea folosi această cheie pentru a accesa aplicația.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Activează'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.activateKey(key.id, selectedProfile.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cheia a fost asociată cu "${selectedProfile.name}"',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Eroare: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheile mele'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: cs.error),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reîncearcă'),
                  ),
                ],
              ),
            )
          : _buildContent(cs),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _StatsCard(
                    label: 'Total',
                    value: _stats?.total.toString() ?? '-',
                    icon: Icons.key,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsCard(
                    label: 'Folosite',
                    value: _stats?.used.toString() ?? '-',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsCard(
                    label: 'Disponibile',
                    value: _stats?.available.toString() ?? '-',
                    icon: Icons.hourglass_empty,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Lista cheilor',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // Keys list
        if (_keys == null || _keys!.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nu ai chei încă.',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final key = _keys![index];
              return _KeyCard(
                licenseKey: key,
                onCopy: () => _copyKey(key.keyUuid),
                onShare: (ctx) => _shareKey(ctx, key.keyUuid, key.profileName),
                onReset: key.isUsed ? () => _resetKey(key) : null,
                onActivate: key.isAvailable ? () => _activateKey(key) : null,
              );
            }, childCount: _keys!.length),
          ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final LicenseKeyDTO licenseKey;
  final VoidCallback onCopy;
  final void Function(BuildContext) onShare;
  final VoidCallback? onReset;
  final VoidCallback? onActivate;

  const _KeyCard({
    required this.licenseKey,
    required this.onCopy,
    required this.onShare,
    this.onReset,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final neutralFill =
        Theme.of(context).inputDecorationTheme.fillColor ??
        const Color(0xFFF2F3F6);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: licenseKey.isAvailable
                        ? Colors.green.withOpacity(0.1)
                        : const Color(0xFFF2F3F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    licenseKey.isAvailable ? 'Disponibilă' : 'Folosită',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: licenseKey.isAvailable
                          ? Colors.green
                          : cs.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: onCopy,
                  tooltip: 'Copiază cheia',
                ),
                Builder(
                  builder: (btnContext) => IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () => onShare(btnContext),
                    tooltip: 'Trimite cheia',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Key UUID
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neutralFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.key,
                    size: 16,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      licenseKey.keyUuid,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (licenseKey.isUsed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    licenseKey.profileName ?? 'Profil necunoscut',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (licenseKey.activatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Activată: ${_formatDate(licenseKey.activatedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (onReset != null)
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Resetează cheia'),
                  style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                ),
            ] else if (licenseKey.isAvailable) ...[
              const SizedBox(height: 12),
              Text(
                'Această cheie nu este asociată cu niciun profil.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),
              if (onActivate != null)
                FilledButton.icon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Asociază cu un profil'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
