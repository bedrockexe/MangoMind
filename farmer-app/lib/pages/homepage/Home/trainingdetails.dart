// training_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';

class TrainingDetailsPage extends StatefulWidget {
  final String trainingId;
  const TrainingDetailsPage({super.key, required this.trainingId});

  @override
  State<TrainingDetailsPage> createState() => _TrainingDetailsPageState();
}

class _TrainingDetailsPageState extends State<TrainingDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _enroll(String trainingId) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to enroll.')),
      );
      return;
    }
    setState(() => _isProcessing = true);
    final docId = '${trainingId}_${user.uid}';
    final docRef = _firestore.collection('enrollments').doc(docId);
    try {
      final snap = await docRef.get();
      if (snap.exists) {
        await docRef.update({
          'status': 'registered',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set({
          'trainingId': trainingId,
          'farmerId': user.uid,
          'status': 'registered',
          'enrolledAt': FieldValue.serverTimestamp(),
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enrolled')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelEnrollment(String trainingId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isProcessing = true);
    final docId = '${trainingId}_${user.uid}';
    final docRef = _firestore.collection('enrollments').doc(docId);
    try {
      final snap = await docRef.get();
      if (!snap.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not enrolled')));
      } else {
        await docRef.update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cancelled')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _addToCalendar({
    required DateTime start,
    required String title,
    String? description,
    String? location,
  }) async {
    // Request calendar permission
    var status = await Permission.calendarFullAccess.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar permission is required.')),
      );
      return; // Exit if permission is not granted
    }

    final Event event = Event(
      title: title,
      description: description ?? '',
      location: location ?? '',
      startDate: start,
      endDate: start.add(const Duration(hours: 2)),
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    try {
      await Add2Calendar.addEvent2Cal(event);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to calendar')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add to calendar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainingDoc = _firestore
        .collection('trainings')
        .doc(widget.trainingId);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: trainingDoc.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load training',
              message: '${snap.error}',
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'No title';
          final desc = data['description'] ?? '';
          final venue = data['venue'] ?? '';
          final thumbnail = data['thumbnailUrl'] as String?;
          final ts = data['scheduledAt'] as Timestamp?;
          final scheduledAt = ts?.toDate();
          final formattedDate = scheduledAt != null
              ? DateFormat('EEEE, MMM dd • hh:mm a').format(scheduledAt)
              : 'TBA';

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: const SizedBox.shrink(),
                    background: thumbnail != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(thumbnail, fit: BoxFit.cover),
                              // subtle overlay so content below is readable
                              Container(
                                color: Colors.black.withValues(alpha: 0.28),
                              ),
                            ],
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppTheme.space4),

                      // Date & Venue card (venue displayed as simple label)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppTheme.space3),
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            if (venue.isNotEmpty) ...[
                              const SizedBox(height: AppTheme.space3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppTheme.space3),
                                  Expanded(
                                    child: Text(
                                      venue,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),

                      // Description section
                      const SectionHeader('About this training'),
                      AppCard(
                        child: Text(
                          desc,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(height: 1.5),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),

                      // Attendees count & CTA
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('enrollments')
                            .where('trainingId', isEqualTo: widget.trainingId)
                            .where(
                              'status',
                              whereIn: ['registered', 'attended'],
                            )
                            .snapshots(),
                        builder: (context, eSnap) {
                          final count = eSnap.hasData
                              ? eSnap.data!.docs.length
                              : 0;
                          final user = _auth.currentUser;

                          final bool iAmEnrolled =
                              eSnap.hasData &&
                              eSnap.data!.docs.any((d) {
                                final md = d.data() as Map<String, dynamic>;
                                return md['farmerId'] == user?.uid &&
                                    (md['status'] == 'registered' ||
                                        md['status'] == 'attended');
                              });

                          return Column(
                            children: [
                              AppCard(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.groups_outlined,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: AppTheme.space3),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$count registered',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          Text(
                                            'farmers attending',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (iAmEnrolled)
                                      const AppStatusChip(
                                        'Enrolled',
                                        tone: StatusTone.success,
                                        icon: Icons.check_circle,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.space4),
                              SizedBox(
                                width: double.infinity,
                                child: iAmEnrolled
                                    ? OutlinedButton.icon(
                                        onPressed: _isProcessing
                                            ? null
                                            : () => _cancelEnrollment(
                                                widget.trainingId,
                                              ),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: Text(
                                          _isProcessing
                                              ? 'Processing...'
                                              : 'Cancel enrollment',
                                        ),
                                      )
                                    : FilledButton.icon(
                                        onPressed: _isProcessing
                                            ? null
                                            : () => _enroll(widget.trainingId),
                                        icon: const Icon(Icons.how_to_reg),
                                        label: Text(
                                          _isProcessing
                                              ? 'Processing...'
                                              : 'Enroll',
                                        ),
                                      ),
                              ),
                              const SizedBox(height: AppTheme.space3),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: scheduledAt == null
                                      ? null
                                      : () => _addToCalendar(
                                          start: scheduledAt,
                                          title: title,
                                          description: desc,
                                          location: venue,
                                        ),
                                  icon: const Icon(Icons.event_available),
                                  label: const Text('Add to calendar'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: AppTheme.space5),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
