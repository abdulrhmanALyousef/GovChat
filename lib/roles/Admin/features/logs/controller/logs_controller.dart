import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/activity_log_model.dart';
import '../../../../../models/admin_model.dart';
import '../../../../../models/chat_message.dart';

// ── Deleted message helper ────────────────────────────────────────────────────

class DeletedMessageItem {
  final String messageId;
  final String text;
  final String senderId;
  final String deletedBy;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final String departmentId;
  final String organizationId;

  DeletedMessageItem({
    required this.messageId,
    required this.text,
    required this.senderId,
    required this.deletedBy,
    this.deletedAt,
    this.createdAt,
    required this.departmentId,
    required this.organizationId,
  });

  factory DeletedMessageItem.fromMessage(ChatMessage msg) {
    return DeletedMessageItem(
      messageId: msg.id ?? '',
      text: msg.text,
      senderId: msg.senderId,
      deletedBy: msg.deletedBy ?? '',
      deletedAt: msg.deletedAt,
      createdAt: msg.createdAt,
      departmentId: msg.departmentId,
      organizationId: msg.organizationId,
    );
  }
}

// ── Date filter enum ─────────────────────────────────────────────────────────

enum LogDateFilter { all, today, last7Days }

// ── Controller ───────────────────────────────────────────────────────────────

/// Query strategy for activity logs:
/// ─────────────────────────────────
/// Server-side  → where(organizationId) + [optional: where(timestamp >=)] + orderBy(timestamp DESC)
/// Client-side  → category filter + search filter (no extra index needed)
///
/// Required Firestore composite index (logs collection):
///   organizationId ASC + timestamp DESC
///
/// Required Firestore composite index (messages collectionGroup):
///   organizationId ASC + isDeleted ASC + deletedAt DESC
class LogsController extends ChangeNotifier {
  final _firebase = FirebaseService.instance;

  AdminModel? _admin;

  // ── Activity logs state ─────────────────────────────────────────────────────
  List<ActivityLogModel> _rawLogs = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  // ── Filter state (category + search are client-side; date is server-side) ───
  String? selectedCategory; // null = all
  LogDateFilter dateFilter = LogDateFilter.all;
  String searchQuery = '';

  static const int _pageSize = 50;
  DocumentSnapshot? _lastDoc;

  // ── Deleted messages state ───────────────────────────────────────────────────
  List<DeletedMessageItem> deletedMessages = [];
  bool isLoadingDeleted = true;
  String? deletedError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deletedSub;

  LogsController() {
    _init();
  }

  // ── Derived list ─────────────────────────────────────────────────────────────

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
    if (_admin != null) {
      await _fetch(refresh: true);
      _listenToDeletedMessages(_admin!.organizationId!);
    }
  }

  Future<void> _loadAdmin() async {
    try {
      final user = _firebase.currentUser;
      if (user == null) {
        _setError('User not found');
        isLoadingDeleted = false;
        notifyListeners();
        return;
      }
      final doc = await _firebase.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        _setError('Admin data not found');
        isLoadingDeleted = false;
        notifyListeners();
        return;
      }
      _admin = AdminModel.fromJson(doc.data()!);
    } catch (e) {
      _setError(e.toString());
      isLoadingDeleted = false;
      notifyListeners();
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

  // ── Firestore fetch (activity logs) ─────────────────────────────────────────

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
      Query<Map<String, dynamic>> q = _firebase.firestore
          .collection('logs')
          .where('organizationId', isEqualTo: orgId);

      if (dateFilter != LogDateFilter.all) {
        final now = DateTime.now();
        final start = dateFilter == LogDateFilter.today
            ? DateTime(now.year, now.month, now.day)
            : now.subtract(const Duration(days: 7));
        q = q.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start));
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

  // ── Firestore stream (deleted messages) ──────────────────────────────────────

  void _listenToDeletedMessages(String orgId) {
    _deletedSub?.cancel();
    _deletedSub = _firebase.firestore
        .collectionGroup('messages')
        .where('organizationId', isEqualTo: orgId)
        .where('isDeleted', isEqualTo: true)
        .orderBy('deletedAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snap) {
            deletedMessages = snap.docs
                .map((d) => DeletedMessageItem.fromMessage(
                    ChatMessage.fromJson(d.data(), id: d.id)))
                .toList();
            isLoadingDeleted = false;
            notifyListeners();
          },
          onError: (e) {
            deletedError = e.toString();
            isLoadingDeleted = false;
            notifyListeners();
          },
        );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _setError(String message) {
    errorMessage = message;
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _deletedSub?.cancel();
    super.dispose();
  }
}
