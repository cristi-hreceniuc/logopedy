import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/data/presentation/cubit/auth_cubit.dart';
import '../../session/session_info.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: FutureBuilder<SessionInfo?>(
        future: SessionInfo.fromStorage(),
        builder: (context, snap) {
          final info = snap.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primary.withOpacity(.12),
                    child: Icon(Icons.person, size: 36, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info?.email ?? 'Utilizator',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        if (info?.userId != null)
                          Text('UID: ${info!.userId}',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(.7))),
                        const SizedBox(height: 8),
                        if (info?.isPremium == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.primary.withOpacity(.2)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.star_rounded, size: 16, color: cs.primary),
                              const SizedBox(width: 6),
                              Text('Premium',
                                  style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detalii cont',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _Row(label: 'Email', value: info?.email ?? '—'),
                      _Row(
                          label: 'Status',
                          value: (info?.isPremium ?? false)
                              ? 'Premium'
                              : 'Standard'),
                      _Row(
                          label: 'Expiră la',
                          value: info?.expiresAt != null
                              ? info!.expiresAt!.toLocal().toString()
                              : '—'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, st) {
                  return FilledButton.icon(
                    onPressed: st.loading ? null : () => context.read<AuthCubit>().logout(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label, style: TextStyle(color: cs.onSurfaceVariant))),
          Expanded(
              child:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
