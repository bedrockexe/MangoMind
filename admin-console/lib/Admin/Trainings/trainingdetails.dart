// training_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _isAdmin = false;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _loadingRole = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = (data['role'] ?? '').toString().toLowerCase();
        final isAdminField = data['isAdmin'] == true || data['admin'] == true;
        setState(() {
          _isAdmin = role == 'admin' || isAdminField;
          _loadingRole = false;
        });
      } else {
        setState(() {
          _isAdmin = false;
          _loadingRole = false;
        });
      }
    } catch (_) {
      setState(() {
        _isAdmin = false;
        _loadingRole = false;
      });
    }
  }

  Widget _buildAttendeeTile(Map<String, dynamic> enrollData) {
    final farmerId = enrollData['farmerId'] as String?;
    final status = (enrollData['status'] ?? 'registered').toString();

    return FutureBuilder<DocumentSnapshot>(
      future: farmerId != null
          ? _firestore.collection('users').doc(farmerId).get()
          : Future.value(null),
      builder: (context, userSnap) {
        String name = farmerId ?? 'Unknown';
        String subtitle = 'ID: ${farmerId ?? '—'} • $status';
        if (userSnap.hasData &&
            userSnap.data != null &&
            userSnap.data!.exists) {
          final ud = userSnap.data!.data() as Map<String, dynamic>;
          final first = (ud['first_name'] ?? '').toString();
          final last = (ud['last_name'] ?? '').toString();
          final phone = (ud['phone'] ?? '').toString();
          final displayName = (first + ' ' + last).trim();
          name = displayName.isEmpty
              ? (ud['name'] ?? farmerId ?? 'Unknown')
              : displayName;
          subtitle = phone.isNotEmpty ? phone : status;
        }

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(name),
          subtitle: Text(subtitle),
          trailing: Text(
            status,
            style: TextStyle(
              color: status == 'attended'
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
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
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
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
                  // share removed per request
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
                              Container(color: Colors.black.withValues(alpha: 0.28)),
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
                      // Title below the image
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Date & Venue
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

                      // Description
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

                      // Materials
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('materials')
                            .where('trainingId', isEqualTo: widget.trainingId)
                            .snapshots(),
                        builder: (context, matSnap) {
                          if (!matSnap.hasData) return const SizedBox();
                          final mats = matSnap.data!.docs;
                          if (mats.isEmpty) return const SizedBox();
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Materials',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...mats.map((m) {
                                    final md = m.data() as Map<String, dynamic>;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.picture_as_pdf),
                                      title: Text(md['title'] ?? 'Material'),
                                      subtitle: Text(md['type'] ?? ''),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.open_in_new),
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Open material'),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Attendees list (admin-focused) & CTA
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
                          if (eSnap.hasError) return const SizedBox();
                          if (!eSnap.hasData) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: const [CircularProgressIndicator()],
                                ),
                              ),
                            );
                          }

                          final enrollDocs = eSnap.data!.docs;
                          final count = enrollDocs.length;
                          final user = _auth.currentUser;
                          final bool iAmEnrolled = enrollDocs.any((d) {
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Attendees',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '$count registered',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // List
                                  if (enrollDocs.isNotEmpty)
                                    ListView.separated(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount: enrollDocs.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 8),
                                      itemBuilder: (context, idx) {
                                        final enrollData =
                                            enrollDocs[idx].data()
                                                as Map<String, dynamic>;
                                        return _buildAttendeeTile(enrollData);
                                      },
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text('No attendees yet.'),
                                    ),

                                  const SizedBox(height: 12),
                                  if (_loadingRole)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(),
                                      ),
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
