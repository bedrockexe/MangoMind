// lib/features/irrigation/irrigation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/transitions.dart';
import 'package:intl/intl.dart';
import 'package:insights/pages/services/open_meteo_service.dart';
import 'package:insights/pages/services/irrigation_advisor.dart';
import 'package:insights/pages/homepage/Home/irrigation_check.dart';
import 'package:insights/pages/homepage/Farm/farmlist/farmlist.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IrrigationPage extends StatefulWidget {
  final double lat;
  final double lon;
  final String farmsRouteName;

  const IrrigationPage({
    super.key,
    required this.lat,
    required this.lon,
    this.farmsRouteName = '/farm',
  });

  @override
  State<IrrigationPage> createState() => _IrrigationPageState();
}

class _IrrigationPageState extends State<IrrigationPage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _scheduled = false;
  DateTime? _lastChecked;
  IrrigationAdvice? _advice;
  String? _error;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _runCheck(notify: false),
    );
    checkScheduled();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> checkScheduled() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final data = snapshot.data();
      final scheduled = data?['irrigationScheduled'] ?? false;
      setState(() {
        _scheduled = scheduled;
      });
    }
  }

  Future<void> _runCheck({bool notify = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final m = await OpenMeteoService.fetch(lat: widget.lat, lon: widget.lon);
      final advice = IrrigationAdvisor.evaluate(m);
      setState(() {
        _advice = advice;
        _lastChecked = DateTime.now();
      });

      if (notify) {
        await IrrigationCheck.runOnceAndNotifyForLocation(
          widget.lat,
          widget.lon,
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Irrigation check failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> saveSchedule(bool value) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await docRef.set({'irrigationScheduled': value}, SetOptions(merge: true));
  }

  Future<void> _toggleSchedule(bool value) async {
    setState(() {
      _scheduled = value;
    });

    if (value) {
      await IrrigationCheck.scheduleDailyForLocation(widget.lat, widget.lon);
      await saveSchedule(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily irrigation check scheduled at 6:00 AM'),
          ),
        );
      }
    } else {
      await saveSchedule(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily irrigation check unchecked.')),
        );
      }
    }
  }

  void _goToFarms() {
    Navigator.of(
      context,
    ).push(appRoute(FarmListPage()));
  }

  Widget _buildStatusCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recommend = _advice?.recommend ?? false;
    final accent = recommend ? scheme.tertiary : scheme.primary;
    final bg = recommend ? scheme.tertiaryContainer : scheme.primaryContainer;
    final onBg = recommend
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(color: bg, borderRadius: AppTheme.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.05).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: accent,
                  child: Icon(
                    recommend ? Icons.water_drop : Icons.check_rounded,
                    size: 30,
                    color: recommend ? scheme.onTertiary : scheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommend
                          ? 'Irrigation recommended'
                          : 'Irrigation not recommended',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onBg,
                      ),
                    ),
                    if (_advice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _advice!.reason,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onBg.withValues(alpha: 0.85),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_advice == null && !_loading) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Press "Check now" to evaluate irrigation for this location.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onBg.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_advice != null && (recommend || _lastChecked != null)) ...[
            const SizedBox(height: AppTheme.space3),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (recommend)
                  AppStatusChip(
                    'Deficit ${_advice!.waterDeficitMm.toStringAsFixed(1)} mm',
                    tone: StatusTone.warning,
                    icon: Icons.water_drop,
                  ),
                if (_lastChecked != null)
                  Text(
                    'Last checked ${DateFormat.yMd().add_jm().format(_lastChecked!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onBg.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _loading ? null : () => _runCheck(notify: true),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(_loading ? 'Checking...' : 'Check now'),
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        OutlinedButton.icon(
          onPressed: _goToFarms,
          icon: const Icon(Icons.agriculture),
          label: const Text('Farms'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Irrigation Checker'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _runCheck(notify: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          // Header card with quick summary
          _buildStatusCard().animate().fadeIn(duration: 350.ms),
          const SizedBox(height: AppTheme.space4),

          // Error message
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space3),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: AppTheme.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space3),
          ],

          // Controls
          _buildControls(),
          const SizedBox(height: AppTheme.space5),

          // Scheduling switch
          const SectionHeader('Automation'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space3,
              vertical: AppTheme.space1,
            ),
            child: SwitchListTile(
              value: _scheduled,
              onChanged: (v) => _toggleSchedule(v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily automatic check'),
              subtitle: const Text('Runs every day at 6:00 AM'),
            ),
          ),
          const SizedBox(height: AppTheme.space5),

          // Detailed info / explanation
          const SectionHeader('What this means'),
          AppCard(
            child: Text(
              'This tool fetches recent weather & soil moisture estimates, then '
              'applies the irrigation advisor rules to decide if irrigation is '
              'recommended. If it is, it also calculates an estimated water '
              'deficit (mm).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
