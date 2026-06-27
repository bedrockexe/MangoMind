// admin_recordings_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminRecordingsPage extends StatefulWidget {
  const AdminRecordingsPage({Key? key}) : super(key: key);

  @override
  State<AdminRecordingsPage> createState() => _AdminRecordingsPageState();
}

class _AdminRecordingsPageState extends State<AdminRecordingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Local UI state
  String _selectedStatus = 'All';
  String _sortBy = 'latest';
  List<String> _statusOptions = ['All', 'Healthy', 'Monitor', 'Issue Found'];
  Timer? _debounce;

  // Pagination / streaming
  static const int pageSize = 20;
  List<DocumentSnapshot> _docs = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _initLoad();
    // infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMore();
      }
    });

    _searchController.addListener(() {
      // debounce search input
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _refresh();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Build Firestore query. We'll use server-side constraints where possible,
  // but do client-side filtering for text search (name / notes).
  Query _baseQuery() {
    Query q = FirebaseFirestore.instance
        .collection('recordings')
        .orderBy('createdAt', descending: true);
    // Sort by other fields if requested
    if (_sortBy == 'highest_yield') {
      q = FirebaseFirestore.instance
          .collection('recordings')
          .orderBy('yield', descending: true);
    } else if (_sortBy == 'oldest') {
      q = FirebaseFirestore.instance
          .collection('recordings')
          .orderBy('createdAt', descending: false);
    }
    // Filter by status if not 'All' (store status as string in doc)
    if (_selectedStatus != 'All') {
      q = q.where('status', isEqualTo: _selectedStatus);
    }
    return q;
  }

  Future<void> _initLoad() async {
    setState(() {
      _isInitialLoading = true;
      _docs = [];
      _lastDoc = null;
      _hasMore = true;
    });
    await _loadMore();
    setState(() => _isInitialLoading = false);
  }

  Future<void> _refresh() async {
    await _initLoad();
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);
    Query q = _baseQuery().limit(pageSize);
    if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

    final snap = await q.get();
    final docs = snap.docs;

    if (docs.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
      return;
    }

    setState(() {
      _docs.addAll(docs);
      _lastDoc = docs.last;
      _isLoadingMore = false;
      if (docs.length < pageSize) _hasMore = false;
    });
  }

  // Client-side filtering for search (simple contains on farmerName and notes)
  List<DocumentSnapshot> _applySearchFilter(List<DocumentSnapshot> docs) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return docs;
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final farmer = (data['farmerName'] ?? '').toString().toLowerCase();
      final notes = (data['notes'] ?? '').toString().toLowerCase();
      return farmer.contains(query) || notes.contains(query);
    }).toList();
  }

  Color _chipColorForStatus(String status) {
    switch (status) {
      case 'Healthy':
        return Colors.green.shade400;
      case 'Monitor':
        return Colors.amber.shade700;
      case 'Issue Found':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  void _onExportPressed() {
    // Placeholder: implement CSV/PDF export using packages like csv & path_provider
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export stub — implement CSV/PDF export')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = _applySearchFilter(_docs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings — Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV/PDF',
            onPressed: _onExportPressed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search farmer or notes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _refresh();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (s) {
                    setState(() {
                      _sortBy = s;
                      _refresh();
                    });
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'latest',
                      child: Text('Sort: Latest'),
                    ),
                    const PopupMenuItem(
                      value: 'oldest',
                      child: Text('Sort: Oldest'),
                    ),
                    const PopupMenuItem(
                      value: 'highest_yield',
                      child: Text('Sort: Highest yield'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips row
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final status = _statusOptions[i];
                final isSelected = _selectedStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (sel) {
                    setState(() {
                      _selectedStatus = status;
                      _refresh();
                    });
                  },
                  selectedColor: _chipColorForStatus(status),
                );
              },
            ),
          ),

          if (_isInitialLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (filteredDocs.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No recordings found.\nTry clearing filters or search.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemCount: filteredDocs.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, idx) {
                    if (idx >= filteredDocs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final doc = filteredDocs[idx];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final farmerName = data['farmerName'] ?? 'Unknown Farmer';
                    final notes = data['notes'] ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final status = data['status'] ?? 'Unknown';
                    final yieldVal = data['yield']?.toString() ?? '-';
                    final attachments = List<String>.from(
                      data['attachments'] ?? [],
                    );
                    final location = data['location'] ?? null;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _chipColorForStatus(status),
                              child: Text(
                                farmerName.toString().isNotEmpty
                                    ? farmerName.toString()[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmerName.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$yieldVal kg • ${_formatTimestamp(createdAt)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(status),
                              backgroundColor: _chipColorForStatus(
                                status,
                              ).withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: _chipColorForStatus(status),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(notes.toString())),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (attachments.isNotEmpty)
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (c, i) {
                                  final url = attachments[i];
                                  return GestureDetector(
                                    onTap: () {
                                      // open image viewer or show full screen
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        width: 92,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          width: 92,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemCount: attachments.length,
                              ),
                            ),
                          if (location != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(location.toString()),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  // navigate to farmer profile
                                },
                                icon: const Icon(Icons.person),
                                label: const Text('Farmer Profile'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  // add follow-up task or comment
                                },
                                icon: const Icon(Icons.add_task),
                                label: const Text('Add Follow-up'),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  // edit / moderate recording
                                },
                                child: const Text('Edit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Recording'),
        onPressed: () {
          // open recording creation page
        },
      ),
    );
  }
}
