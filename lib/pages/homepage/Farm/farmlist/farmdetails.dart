// Flutter Material
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages
import 'package:insights/pages/homepage/Farm/farmlist/records/records.dart';
import 'package:insights/pages/homepage/Farm/farmlist/overview/overview.dart';
import 'package:insights/pages/homepage/Farm/farmlist/tasks/tasks.dart';

// Opening Class
class FarmDetailsPage extends StatefulWidget {
  final String farmId;
  final int initialTab;
  const FarmDetailsPage({super.key, this.initialTab = 0, required this.farmId});

  @override
  State<FarmDetailsPage> createState() => _FarmDetailsPageState();
}

// Child Class
class _FarmDetailsPageState extends State<FarmDetailsPage>
    with SingleTickerProviderStateMixin {
  late final DocumentReference<Map<String, dynamic>> farmRef;
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    farmRef = FirebaseFirestore.instance.collection('farms').doc(widget.farmId);
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  // disposer
  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }
  // ===== Widgets ======

  // Main Section
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: farmRef.snapshots(),
          builder: (context, snap) {
            final name =
                (snap.data?.data() ?? const {})['name'] ?? 'Farm Details';
            return Text(name);
          },
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Records'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          OverviewPage(farmRef: farmRef, tabController: _tab),
          TasksPage(farmRef: farmRef),
          RecordsPage(farmRef: farmRef),
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.caption,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg.withOpacity(0.96), bg.withOpacity(0.86)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: onBg.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon pill
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: onBg.withOpacity(0.75),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onBg,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onBg.withOpacity(0.6),
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
