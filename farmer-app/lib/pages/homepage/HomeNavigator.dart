import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/transitions.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/interactions.dart';
import 'package:insights/pages/homepage/Home/weather_widget.dart';
import 'package:insights/pages/homepage/Home/irrigation_reco.dart';
import 'package:insights/pages/homepage/Home/mango_test.dart';
import 'package:insights/pages/homepage/Home/trainingspage.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeRootState();
}

class _HomeRootState extends State<Home> {
  int _refreshToken = 0;

  // The flagship action gets a spotlight; the rest become tool tiles.
  late final _Feature _spotlight = _Feature(
    id: 'disease',
    title: 'Scan your mango',
    subtitle: 'Detect diseases & ripeness instantly with on-device AI',
    cta: 'Scan now',
    icon: Icons.center_focus_strong,
    color: AppTheme.brandGreen,
    destinationBuilder: (ctx) => const MangoDetector(),
  );

  late final List<_Feature> _tools = [
    _Feature(
      id: 'irrigation',
      title: 'Smart Irrigation',
      subtitle: 'Watering advice',
      cta: 'Get Advice',
      icon: Icons.water_drop,
      color: const Color(0xFF18A0C1),
      destinationBuilder: (ctx) => const IrrigationPage(
        lat: 13.928880330206127,
        lon: 120.95075460563223,
      ),
    ),
    _Feature(
      id: 'training',
      title: 'Training',
      subtitle: 'Learn techniques',
      cta: 'Start Learning',
      icon: Icons.school,
      color: const Color(0xFF8E6DF5),
      destinationBuilder: (ctx) => const FarmerTrainingsPage(),
    ),
  ];

  void _openFeature(_Feature feature) {
    Navigator.of(
      context,
    ).push(appRoute(Builder(builder: feature.destinationBuilder)));
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewPadding.bottom +
        MediaQuery.of(context).viewInsets.bottom;

    return RefreshIndicator.adaptive(
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const _HeroHeader(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpotlightCard(
                  feature: _spotlight,
                  onTap: () => _openFeature(_spotlight),
                ).animate().fadeIn(duration: 350.ms).slideY(
                  begin: 0.12,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                ),
                const SizedBox(height: 22),
                const SectionHeader('Your Tools'),
                const SizedBox(height: 4),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tools.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 150,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                      ),
                  itemBuilder: (context, index) {
                    final f = _tools[index];
                    return _ToolTile(feature: f, onTap: () => _openFeature(f))
                        .animate()
                        .fadeIn(delay: (120 + index * 90).ms, duration: 350.ms)
                        .slideY(
                          begin: 0.15,
                          delay: (120 + index * 90).ms,
                          duration: 350.ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
                const SizedBox(height: 26),
                const SectionHeader('Field Weather'),
                const SizedBox(height: 8),
                WeatherPanel(key: ValueKey(_refreshToken)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed gradient header with the farmer's avatar, a time-of-day greeting
/// + name, and today's date. Reads the user doc live (shimmer-free graceful
/// fallback while loading / offline).
class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  String _greetingWord() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dateLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final stream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandGreen, AppTheme.brandGreenDeep],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: stream == null
              ? _content(context, name: '', photoUrl: null, dateLabel: dateLabel)
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snap) {
                    final data = snap.data?.data() ?? {};
                    return _content(
                      context,
                      name: (data['first_name'] ?? '').toString(),
                      photoUrl: (data['photo_url'] ?? data['profilePath'])
                          ?.toString(),
                      dateLabel: dateLabel,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required String name,
    required String? photoUrl,
    required String dateLabel,
  }) {
    final who = name.trim().isEmpty ? 'there' : name.trim();
    final initial = who.isNotEmpty ? who[0].toUpperCase() : 'U';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingWord(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$who 🌱',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The flagship call-to-action — a bold gradient card spotlighting the mango
/// scanner.
class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.feature, this.onTap});
  final _Feature feature;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brandGreen, AppTheme.brandGreenDeep],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandGreen.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(feature.icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact vertical feature tile for the tools grid.
class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.feature, this.onTap});
  final _Feature feature;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(feature.icon, color: feature.color, size: 26),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                feature.subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                feature.cta,
                style: TextStyle(
                  color: feature.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 14, color: feature.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final String id;
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final Color color;
  final WidgetBuilder destinationBuilder;

  _Feature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.color,
    required this.destinationBuilder,
  });
}
