import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:insights/theme/transitions.dart';
import 'package:insights/theme/skeletons.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'trainingdetails.dart';

class FarmerTrainingsPage extends StatefulWidget {
  const FarmerTrainingsPage({super.key});

  @override
  State<FarmerTrainingsPage> createState() => _FarmerTrainingsPageState();
}

class _FarmerTrainingsPageState extends State<FarmerTrainingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final Map<String, String> _enrolledMap = {};
  StreamSubscription<QuerySnapshot<Object?>>? _enrollSub;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _listenToMyEnrollments();
  }

  @override
  void dispose() {
    _enrollSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _listenToMyEnrollments() {
    final user = _auth.currentUser;
    if (user == null) return;

    _enrollSub = _firestore
        .collection('enrollments')
        .where('farmerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) {
          final Map<String, String> map = {};
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final trainingId = data['trainingId'] as String?;
            final status = data['status'] as String?;
            if (trainingId != null &&
                (status == 'registered' || status == 'attended')) {
              map[trainingId] = doc.id;
            }
          }
          setState(
            () => _enrolledMap
              ..clear()
              ..addAll(map),
          );
        });
  }

  Future<void> _enroll(String trainingId) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in to enroll')));
      return;
    }

    final docId = '${trainingId}_${user.uid}';
    final docRef = _firestore.collection('enrollments').doc(docId);

    try {
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final status = data?['status'] ?? 'registered';
        if (status == 'registered' || status == 'attended') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already registered')),
          );
          return;
        } else {
          // re-register: update status
          await docRef.update({
            'status': 'registered',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await docRef.set({
          'trainingId': trainingId,
          'farmerId': user.uid,
          'status': 'registered',
          'enrolledAt': FieldValue.serverTimestamp(),
        });
      }
      // optimistic UI updated by the enrollment listener
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registered successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enroll failed: $e')));
    }
  }

  Future<void> _cancelEnrollment(String trainingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docId = '${trainingId}_${user.uid}';
    final docRef = _firestore.collection('enrollments').doc(docId);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not registered')));
        return;
      }
      await docRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enrollment cancelled')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search trainings by title...',
        prefixIcon: Icon(Icons.search, color: scheme.primary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: scheme.error),
                onPressed: () => _searchCtrl.clear(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 15,
        ),
      ),
    );
  }

  Widget _buildTrainingCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final venue = data['venue'] ?? '';
    final ts = data['scheduledAt'] as Timestamp?;
    final scheduledAt = ts?.toDate();
    final formattedDate = scheduledAt != null
        ? DateFormat('EEE, MMM d • hh:mm a').format(scheduledAt)
        : 'TBA';
    final thumbnail = data['thumbnailUrl'] as String?;
    final trainingId = doc.id;
    final isEnrolled = _enrolledMap.containsKey(trainingId);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4,
          vertical: AppTheme.space2,
        ),
        child: AppCard(
          onTap: () {
            Navigator.push(
              context,
              appRoute(TrainingDetailsPage(trainingId: trainingId)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero animation for the thumbnail
                  Hero(
                    tag: 'training-image-$trainingId',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: thumbnail != null
                          ? Image.network(
                              thumbnail,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                              ),
                              child: Icon(
                                Icons.school,
                                size: 40,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppTheme.space2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                        if (venue.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.place,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  venue,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppTheme.space2),
                        AppStatusChip(
                          isEnrolled ? 'Registered' : 'Open',
                          tone: isEnrolled
                              ? StatusTone.success
                              : StatusTone.info,
                          icon: isEnrolled
                              ? Icons.check_circle
                              : Icons.event_available,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              SizedBox(
                width: double.infinity,
                child: isEnrolled
                    ? OutlinedButton.icon(
                        onPressed: () => _cancelEnrollment(trainingId),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: scheme.error),
                          foregroundColor: scheme.error,
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel enrollment'),
                      )
                    : FilledButton.icon(
                        onPressed: () => _enroll(trainingId),
                        icon: const Icon(Icons.how_to_reg, size: 18),
                        label: const Text('Enroll'),
                      ),
              ),
            ],
          ),
        ),
      )
        .animate()
        .fadeIn(
          delay: (index * 70).ms,
          duration: 350.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.12,
          delay: (index * 70).ms,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }

  @override
  Widget build(BuildContext context) {
    final trainingsStream = _firestore
        .collection('trainings')
        .where('published', isEqualTo: true)
        .orderBy('scheduledAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Trainings'), elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSearchBar(),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: trainingsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load trainings',
                      message: '${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const TrainingListSkeleton();
                  }

                  final docs = snapshot.data!.docs.toList();
                  final filtered = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    return title.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.school_outlined,
                      title: _searchQuery.isEmpty
                          ? 'No trainings yet'
                          : 'No trainings found',
                      message: _searchQuery.isEmpty
                          ? 'Upcoming trainings will appear here.'
                          : 'Try a different search term.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        await Future.delayed(const Duration(milliseconds: 500)),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildTrainingCard(filtered[index], index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
