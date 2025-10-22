// lib/features/irrigation/irrigation_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:insights/pages/services/open_meteo_service.dart';
import 'package:insights/pages/services/irrigation_advisor.dart';
import 'package:insights/pages/homepage/Home/irrigation_check.dart';
import 'package:insights/pages/homepage/Farm/farmlist/farmlist.dart';

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

  // small animation controller for the header accent
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  Future<void> _toggleSchedule(bool value) async {
    setState(() {
      _scheduled = value;
    });

    if (value) {
      await IrrigationCheck.scheduleDailyForLocation(widget.lat, widget.lon);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily irrigation check scheduled at 6:00 AM'),
          ),
        );
      }
    }
  }

  void _goToFarms() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => FarmListPage()));
  }

  Widget _buildStatusCard() {
    final theme = Theme.of(context);
    final recommend = _advice?.recommend ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: recommend
            ? LinearGradient(
                colors: [Colors.orange.shade200, Colors.orange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.blueGrey.shade50, Colors.green.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: recommend ? Colors.orange : Colors.green,
              child: Icon(
                recommend ? Icons.water_drop : Icons.check_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                  ),
                ),
                const SizedBox(height: 6),
                if (_advice != null)
                  Text(
                    _advice!.reason,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_advice != null) const SizedBox(height: 8),
                if (_advice != null)
                  Row(
                    children: [
                      if (recommend)
                        Chip(
                          label: Text(
                            'Deficit ${_advice!.waterDeficitMm.toStringAsFixed(1)} mm',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.9),
                        ),
                      const SizedBox(width: 8),
                      if (_lastChecked != null)
                        Text(
                          'Last: ${DateFormat.yMd().add_jm().format(_lastChecked!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                if (_advice == null && !_loading)
                  Text(
                    'Press "Check now" to evaluate irrigation for this location.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
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
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _goToFarms,
          icon: const Icon(Icons.agriculture),
          label: const Text('Farms'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Optionally run a quick check on open (comment out if undesired)
    // WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck(notify: false));
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          children: [
            // Header card with quick summary
            _buildStatusCard(),
            const SizedBox(height: 18),

            // Error message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Controls
            _buildControls(),

            const SizedBox(height: 16),

            // Scheduling switch and short explanation
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Daily automatic check at 6:00 AM',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Switch(
                      value: _scheduled,
                      onChanged: (v) => _toggleSchedule(v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Detailed info / explanation area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What this means',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This tool fetches recent weather & soil moisture estimates, then applies the irrigation advisor rules to decide if irrigation is recommended. '
                      'If irrigation is recommended, it also calculates an estimated water deficit (mm).',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // quick tip: run a manual immediate notification call path
                          _runCheck(notify: true);
                        },
                        child: const Text('Run check & send notification'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
