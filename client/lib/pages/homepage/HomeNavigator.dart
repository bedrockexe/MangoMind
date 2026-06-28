import 'package:flutter/material.dart';
import 'package:insights/pages/homepage/Home/weather_widget.dart';
import 'package:insights/pages/homepage/Home/irrigation_reco.dart';
import 'package:insights/pages/homepage/Home/mango_test.dart';
import 'package:insights/pages/homepage/Home/trainingspage.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeRootState();
}

class _HomeRootState extends State<Home> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _itemanimations;
  int _refreshToken = 0;

  final List<_Feature> features = [
    _Feature(
      id: 'disease',
      title: 'Disease Checker',
      subtitle: 'Detect mango diseases using Image Detector',
      cta: 'Scan Now',
      icon: Icons.bug_report,
      color: const Color(0xFFEF6C6C),
      destinationBuilder: (ctx) => const MangoDetector(),
    ),
    _Feature(
      id: 'irrigation',
      title: 'Smart Irrigation',
      subtitle: 'Get accurate watering recommendations',
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
      title: 'Training Programs',
      subtitle: 'Learn modern farming techniques',
      cta: 'Start Learning',
      icon: Icons.school,
      color: const Color(0xFF8E6DF5),
      destinationBuilder: (ctx) => const FarmerTrainingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _itemanimations = List.generate(features.length, (i) {
      final start = i * 0.12;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    // entrance
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFeature(BuildContext context, _Feature feature) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: feature.destinationBuilder));
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLarge = mq.size.width > 900;
    final bottomInset = mq.viewPadding.bottom + mq.viewInsets.bottom;

    return RefreshIndicator.adaptive(
      onRefresh: _onRefresh,
      child: SafeArea(
        bottom: true,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          children: [
            // Title
            const Text(
              "Home",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            WeatherPanel(key: ValueKey(_refreshToken)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: features.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isLarge ? 2 : 1,
                mainAxisExtent: 150,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
              ),
              itemBuilder: (context, index) {
                return FadeTransition(
                  opacity: _itemanimations[index],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(_itemanimations[index]),
                    child: FeatureCard(
                      feature: features[index],
                      onTap: () => _openFeature(context, features[index]),
                    ),
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

class FeatureCard extends StatefulWidget {
  final _Feature feature;
  final VoidCallback? onTap;

  const FeatureCard({required this.feature, this.onTap, super.key});

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 0.04,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          final scale = 1 - _pressController.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _CircularIcon(color: f.color, icon: f.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      f.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f.subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: widget.onTap,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                f.cta,
                                style: TextStyle(
                                  color: f.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: f.color,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _CircularIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 26)),
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
