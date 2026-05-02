import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/activity_log_model.dart';
import '../../../../../models/organization_model.dart';

class AuditController extends ChangeNotifier {
  final _firestore = FirebaseService.instance.firestore;
  bool _isDisposed = false;

  List<ActivityLogModel> logs = [];
  List<OrganizationModel> organizations = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;
  bool hasMore = true;

  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 20;

  // ── Filters ────────────────────────────────────────────────────────
  String? selectedOrgId;
  String? selectedRole;
  String? selectedAction;
  DateTime? dateFrom;
  DateTime? dateTo;
  String searchQuery = '';

  // How many filters are currently active
  int get activeFilterCount {
    int count = 0;
    if (selectedOrgId != null) count++;
    if (selectedRole != null) count++;
    if (selectedAction != null) count++;
    if (dateFrom != null) count++;
    if (dateTo != null) count++;
    if (searchQuery.isNotEmpty) count++;
    return count;
  }

  AuditController() {
    _loadOrganizations();
    loadLogs(reset: true);
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _loadOrganizations() async {
    try {
      final snap = await _firestore.collection('organizations').get();
      organizations = snap.docs
          .map((d) => OrganizationModel.fromJson(d.data(), id: d.id))
          .where((o) => o.status != 'deleted')
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _safeNotify();
    } catch (_) {}
  }

  void applyFilters({
    String? orgId,
    String? role,
    String? action,
    DateTime? from,
    DateTime? to,
    String? query,
  }) {
    selectedOrgId = orgId;
    selectedRole = role;
    selectedAction = action;
    dateFrom = from;
    dateTo = to;
    if (query != null) searchQuery = query;
    loadLogs(reset: true);
  }

  void updateSearch(String query) {
    searchQuery = query;
    loadLogs(reset: true);
  }

  void clearFilters() {
    selectedOrgId = null;
    selectedRole = null;
    selectedAction = null;
    dateFrom = null;
    dateTo = null;
    searchQuery = '';
    loadLogs(reset: true);
  }

  Future<void> loadLogs({bool reset = false}) async {
    if (isLoading || isLoadingMore) return;
    if (reset) {
      _lastDoc = null;
      logs = [];
      hasMore = true;
    }
    if (!hasMore && !reset) return;

    if (reset) {
      isLoading = true;
    } else {
      isLoadingMore = true;
    }
    errorMessage = null;
    _safeNotify();

    try {
      // Build the query — single-field filters that Firestore indexes automatically.
      // Multiple-field combinations may require composite indexes created in the Firebase console.
      Query query = _firestore.collection('logs');

      if (selectedOrgId != null) {
        query = query.where('organizationId', isEqualTo: selectedOrgId);
      } else if (selectedRole != null) {
        // Apply role server-side only when no org filter (avoids needing org+role composite index)
        query = query.where('actorRole', isEqualTo: selectedRole);
      } else if (selectedAction != null) {
        // Apply action server-side only when no other equality filter
        query = query.where('action', isEqualTo: selectedAction);
      }

      // Date range uses inequality on timestamp — Firestore requires orderBy on same field first
      if (dateFrom != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFrom!),
        );
      }
      if (dateTo != null) {
        final end = DateTime(dateTo!.year, dateTo!.month, dateTo!.day, 23, 59, 59);
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        );
      }

      query = query.orderBy('timestamp', descending: true);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.limit(_pageSize).get();

      var newLogs = snap.docs
          .map((d) => ActivityLogModel.fromJson(d.data() as Map<String, dynamic>, id: d.id))
          .toList();

      // Client-side filters for combinations not handled server-side
      if (selectedOrgId != null && selectedRole != null) {
        newLogs = newLogs.where((l) => l.actorRole == selectedRole).toList();
      }
      if (selectedAction != null && (selectedOrgId != null || selectedRole != null)) {
        newLogs = newLogs.where((l) => l.action == selectedAction).toList();
      }

      // Text search always client-side
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        newLogs = newLogs.where((l) {
          return l.actorEmail.toLowerCase().contains(q) ||
              l.actorId.toLowerCase().contains(q) ||
              (l.description?.toLowerCase().contains(q) ?? false) ||
              (l.targetEmail?.toLowerCase().contains(q) ?? false) ||
              (l.organizationName?.toLowerCase().contains(q) ?? false);
        }).toList();
      }

      logs.addAll(newLogs);

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }
      hasMore = snap.docs.length == _pageSize;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        errorMessage = 'A composite index is required for this combination of filters. '
            'Please set up the Firestore composite index shown in the console.';
      } else {
        errorMessage = e.message ?? e.toString();
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    isLoadingMore = false;
    _safeNotify();
  }

  Future<void> loadMore() => loadLogs(reset: false);
  Future<void> refresh() => loadLogs(reset: true);

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
