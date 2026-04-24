import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/activity_log_model.dart';
import '../../../../../models/admin_model.dart';

enum LogDateFilter { all, today, last7Days }

/// Query strategy explanation
/// ─────────────────────────
/// Firestore composite indexes are required for every unique combination of
/// where-clauses + orderBy.  Keeping category filtering server-side would
/// need 2 separate composite indexes AND both must be built before any
/// filtered query works.
///
/// Instead we use a single-index approach:
///   Server-side  → where(organizationId) + [optional: where(timestamp >=)] + orderBy(timestamp DESC)
///   Client-side  → category filter   (instant, no extra index, no loading state)
///   Client-side  → search filter     (same)
///
/// Required Firestore composite index (ONE only):
///   logs: organizationId ASC + timestamp DESC
///
/// Deploy with:  firebase deploy --only firestore:indexes
class LogsController extends ChangeNotifier {
  final _firebase = FirebaseService.instance;

  AdminModel? _admin;

  // Raw logs fetched from Firestore (unfiltered by category/search)
  List<ActivityLogModel> _rawLogs = [];

  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  // ── Filter state ─────────────────────────────────────────────────────────────
  // Category + search are pure client-side — changing them never triggers a
  // Firestore fetch, so no loading spinner appears.
  // Date filter is server-side — changing it triggers a fresh Firestore fetch.
  String? selectedCategory; // null = all
  LogDateFilter dateFilter = LogDateFilter.all;
  String searchQuery = '';

  // Increase page size because client-side category filter may reduce visible
  // count significantly — a larger batch keeps "load more" presses rare.
  static const int _pageSize = 50;
  DocumentSnapshot? _lastDoc;

  LogsController() {
    _init();
  }

  // ── Derived (category + search applied here, never in Firestore) ─────────────

  List<ActivityLogModel> get displayedLogs {
    List<ActivityLogModel> result = _rawLogs;

    if (selectedCategory != null) {
      result = result.where((log) => log.category == selectedCategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((log) {
        final name = (log.performedByName ?? '').toLowerCase();
        final userId = log.performedByUserId.toLowerCase();
        final key = log.descriptionKey.toLowerCase();
        return name.contains(q) || userId.contains(q) || key.contains(q);
      }).toList();
    }

    return result;
  }

  // ── Initialization ───────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadAdmin();
    if (_admin != null) await _fetch(refresh: true);
  }

  Future<void> _loadAdmin() async {
    try {
      final user = _firebase.currentUser;
      if (user == null) {
        _setError('User not found');
        return;
      }
      final doc = await _firebase.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        _setError('Admin data not found');
        return;
      }
      _admin = AdminModel.fromJson(doc.data()!);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── Public actions ───────────────────────────────────────────────────────────

  Future<void> refresh() => _fetch(refresh: true);

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    await _fetch(refresh: false);
  }

  /// Category toggle: pure client-side, instant, no Firestore call.
  void setCategory(String? category) {
    selectedCategory = (category == selectedCategory) ? null : category;
    notifyListeners();
  }

  /// Date filter: server-side, triggers a fresh fetch.
  void setDateFilter(LogDateFilter filter) {
    dateFilter = (filter == dateFilter) ? LogDateFilter.all : filter;
    _fetch(refresh: true);
  }

  /// Search: pure client-side, instant, no Firestore call.
  void setSearch(String query) {
    searchQuery = query;
    notifyListeners();
  }

  // ── Firestore fetch ──────────────────────────────────────────────────────────
  // Single composite index required:
  //   (organizationId ASC, timestamp DESC)
  //
  // Query shape:
  //   .where('organizationId', isEqualTo: orgId)         ← equality
  //   [.where('timestamp', isGreaterThanOrEqualTo: t)]   ← optional range on orderBy field
  //   .orderBy('timestamp', descending: true)
  //   .limit(50)
  //
  // Firestore allows the range filter on the same field as orderBy without
  // requiring a third field in the index — the single (organizationId, timestamp)
  // index covers both the equality and the range filter.

  Future<void> _fetch({required bool refresh}) async {
    final orgId = _admin?.organizationId;
    if (orgId == null || orgId.isEmpty) {
      _setError('Organization not found');
      return;
    }

    if (refresh) {
      isLoading = true;
      _lastDoc = null;
      _rawLogs = [];
      hasMore = true;
    } else {
      isLoadingMore = true;
    }
    errorMessage = null;
    notifyListeners();

    try {
      // Base query — only ONE composite index needed.
      Query<Map<String, dynamic>> q = _firebase.firestore
          .collection('logs')
          .where('organizationId', isEqualTo: orgId);

      // Date filter — server-side on same field as orderBy, no extra index.
      if (dateFilter != LogDateFilter.all) {
        final now = DateTime.now();
        final start = dateFilter == LogDateFilter.today
            ? DateTime(now.year, now.month, now.day)
            : now.subtract(const Duration(days: 7));
        q = q.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        );
      }

      q = q.orderBy('timestamp', descending: true).limit(_pageSize);

      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snapshot = await q.get();
      final newLogs = snapshot.docs
          .map((doc) => ActivityLogModel.fromJson(doc.data(), id: doc.id))
          .toList();

      if (refresh) {
        _rawLogs = newLogs;
      } else {
        _rawLogs.addAll(newLogs);
      }

      hasMore = newLogs.length >= _pageSize;
      if (snapshot.docs.isNotEmpty) _lastDoc = snapshot.docs.last;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('[LogsController] Fetch error: $e');
    }

    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _setError(String message) {
    errorMessage = message;
    isLoading = false;
    notifyListeners();
  }
}
