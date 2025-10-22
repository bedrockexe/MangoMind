// training_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

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
            return Center(child: Text('Error: ${snap.error}'));
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
                  backgroundColor: Colors.green.shade700,
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
                        : Container(color: Colors.green.shade700),
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
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Date & Venue card (venue displayed as simple label)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                color: Colors.green.shade800,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (venue.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.place,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Venue: $venue',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'About this training',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(desc, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

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

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Attendees',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text('$count people registered'),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      ElevatedButton(
                                        onPressed: _isProcessing
                                            ? null
                                            : () {
                                                if (!iAmEnrolled) {
                                                  _enroll(widget.trainingId);
                                                } else {
                                                  _cancelEnrollment(
                                                    widget.trainingId,
                                                  );
                                                }
                                              },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Text(
                                            _isProcessing
                                                ? 'Processing...'
                                                : (!iAmEnrolled
                                                      ? 'Enroll'
                                                      : 'Cancel'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                        onPressed: scheduledAt == null
                                            ? null
                                            : () => _addToCalendar(
                                                start: scheduledAt,
                                                title: title,
                                                description: desc,
                                                location: venue,
                                              ),
                                        child: const Text('Add to calendar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
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
