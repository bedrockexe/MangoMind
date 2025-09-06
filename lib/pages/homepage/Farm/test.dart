import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:insights/pages/homepage/Farm/addfarm.dart';
import 'package:insights/pages/homepage/Farm/farmdetails.dart';
import 'package:insights/pages/homepage/Farm/mangowidget.dart';

class FarmListPage extends StatefulWidget {
  const FarmListPage({super.key});
  @override
  State<FarmListPage> createState() => _FarmListPageState();
}

class _FarmListPageState extends State<FarmListPage> {
  Key _streamKey = UniqueKey();

  void _retryStream() {
    setState(() => _streamKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    final farmsRef = FirebaseFirestore.instance
        .collection('farms')
        .where('ownerUid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Management')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: _streamKey,
        stream: farmsRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          // Retry
          if (snap.connectionState == ConnectionState.waiting) {
            return FutureBuilder(
              future: Future.delayed(const Duration(seconds: 10)),
              builder: (context, timerSnap) {
                if (timerSnap.connectionState == ConnectionState.done) {
                  // Timeout reached → show message + real retry
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Still loading...\nPlease check your internet connection.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed:
                              _retryStream, // 👈 re-subscribes to the stream
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                // First 10 seconds → spinner
                return const Center(child: CircularProgressIndicator());
              },
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Icon(
                              Icons.agriculture,
                              size: 20,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Farm List',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text('No Farms yet. Click Add Farm'),

                        const SizedBox(height: 10),

                        // Add button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddFarmPage(),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Farm'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final green = Colors.green.shade700;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Farms
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.agriculture, size: 20, color: green),
                          const SizedBox(width: 8),
                          Text(
                            'Farm List',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Farm List
                      ...docs.map((d) {
                        final data = d.data();
                        final scheme = Theme.of(context).colorScheme;
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FarmDetailsPage(farmId: d.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                // Title + subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'] ?? 'Unnamed',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        data['address'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 10),

                      // Add Farm Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddFarmPage(),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Farm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              // Market Prices
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/mangga.jpg"),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Card(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 20,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mango Public Market Price',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 27),
                            child: Text(
                              "Based on DA \"Bantay Presyo\"",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),

                        MangoPriceTile(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
