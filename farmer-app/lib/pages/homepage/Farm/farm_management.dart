// Flutter packages
import 'package:flutter/material.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/interactions.dart';
import 'package:insights/theme/transitions.dart';

// Pages
import 'package:insights/pages/homepage/Farm/mangoprice/mangowidget.dart';
import 'package:insights/pages/homepage/Farm/farmlist/farmlist.dart';
import 'package:insights/pages/homepage/Farm/assessment_button.dart';

class FarmList extends StatefulWidget {
  const FarmList({super.key});
  @override
  State<FarmList> createState() => _FarmListState();
}

class _FarmListState extends State<FarmList> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Management')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          // Flagship assessment CTA.
          const AssessmentButton(),
          const SizedBox(height: AppTheme.space5),

          // Farm list entry — photo-backed hero with a legible bottom gradient.
          const SectionHeader('Your farm'),
          _myFarmsCard(context),
          const SizedBox(height: AppTheme.space5),

          // Live market prices on a clean surface card.
          const SectionHeader('Market'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_offer, size: 20, color: scheme.primary),
                    const SizedBox(width: AppTheme.space2),
                    Expanded(
                      child: Text(
                        'Mango Public Market Price',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on DA “Bantay Presyo”',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                const MangoPriceTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tappable photo card opening the farm list. Uses a top-to-bottom dark
  /// gradient over the photo so the white label stays legible in any theme.
  Widget _myFarmsCard(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.push(context, appRoute(const FarmListPage())),
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/mangofarm.png', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.agriculture, color: Colors.white, size: 26),
                        SizedBox(width: AppTheme.space2),
                        Text(
                          'My Farms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View and manage your farm list',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
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
