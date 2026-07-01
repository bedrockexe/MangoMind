import 'package:flutter/material.dart';
import 'package:sweet_insights_admin/Admin/Homepage/fullAccountList.dart';
import 'package:sweet_insights_admin/Admin/Homepage/detailed.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';

/// Dashboard card listing the most recent user accounts, with a "See all"
/// link to the full list. Uses the shared design system so it tracks the app
/// theme (light/dark) automatically.
class FarmersListCard extends StatelessWidget {
  final List<Map<String, dynamic>> farmers;
  final bool loading;

  const FarmersListCard({
    super.key,
    required this.farmers,
    this.loading = false,
  });

  /// Deterministic accent for an avatar, derived from the name so it stays
  /// stable across rebuilds (the old code re-randomized on every frame).
  Color _avatarColor(BuildContext context, String seed) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      const Color(0xFF18A0C1),
      const Color(0xFF8E6DF5),
    ];
    return palette[seed.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final preview = farmers.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space2,
        AppTheme.space4,
        AppTheme.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'User accounts',
            trailing: farmers.isEmpty
                ? null
                : TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      appRoute(const FarmersListPage()),
                    ),
                    child: const Text('See all'),
                  ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(AppTheme.space4),
                    child: _AccountsLoading(),
                  )
                : preview.isEmpty
                ? const SizedBox(
                    height: 220,
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: 'No users yet',
                      message: 'Registered farmer accounts will appear here.',
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < preview.length; i++) ...[
                        if (i != 0)
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        _AccountTile(
                          farmer: preview[i],
                          color: _avatarColor(
                            context,
                            '${preview[i]['first_name'] ?? ''}'
                                '${preview[i]['email_address'] ?? i}',
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.farmer, required this.color});

  final Map<String, dynamic> farmer;
  final Color color;

  String get _initial {
    final first = (farmer['first_name'] ?? '').toString().trim();
    return first.isNotEmpty ? first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final first = (farmer['first_name'] ?? '').toString();
    final last = (farmer['last_name'] ?? '').toString();
    final email = (farmer['email_address'] ?? '').toString();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space1,
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          _initial,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        '$first $last'.trim().isEmpty ? 'Unnamed user' : '$first $last',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: email.isEmpty ? null : Text(email),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        appRoute(UserDetailsPage(farmer: farmer)),
      ),
    );
  }
}

class _AccountsLoading extends StatelessWidget {
  const _AccountsLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(4, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == 3 ? 0 : AppTheme.space4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 200,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
