// Flutter Material
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages
import 'Userfarmdetails/records.dart';
import 'overview.dart';

// Opening Class
class FarmDetailsPage extends StatefulWidget {
  final String farmId;
  final int initialTab;
  final String userId;
  const FarmDetailsPage({
    super.key,
    this.initialTab = 0,
    required this.farmId,
    required this.userId,
  });

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
      length: 2,
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
            Tab(text: 'Records'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          OverviewPage(
            farmRef: farmRef,
            farmId: widget.farmId,
            tabController: _tab,
            userId: widget.userId,
          ),
          RecordsPage(farmRef: farmRef),
        ],
      ),
    );
  }
}
