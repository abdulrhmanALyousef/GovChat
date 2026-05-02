import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';

class DailyActivity {
  final DateTime date;
  final int count;
  const DailyActivity(this.date, this.count);
}

class DashboardStats {
  final int totalOrganizations;
  final int totalAdmins;
  final int totalEmployees;
  final int activeUsers;
  final int recentActivity;
  final List<DailyActivity> weeklyActivity;

  const DashboardStats({
    required this.totalOrganizations,
    required this.totalAdmins,
    required this.totalEmployees,
    required this.activeUsers,
    required this.recentActivity,
    required this.weeklyActivity,
  });
}

class DashboardController extends ChangeNotifier {
  final _firestore = FirebaseService.instance.firestore;
  bool _isDisposed = false;

  DashboardStats? stats;
  bool isLoading = true;
  String? errorMessage;

  DashboardController() {
    loadStats();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> loadStats() async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();

    try {
      // Run all independent queries concurrently
      final results = await Future.wait([
        _countActiveOrgs(),
        _countAdmins(),
        _countActiveEmployees(),
        _loadRecentLogs(),
      ]);

      final totalOrgs = results[0] as int;
      final totalAdmins = results[1] as int;
      final totalEmployees = results[2] as int;
      final recentLogs = results[3] as List<Map<String, dynamic>>;

      // Derive active users from unique actor IDs in recent logs
      final activeUsers = recentLogs
          .map((d) => d['actorId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;

      // Total recent-activity count
      final recentActivity = recentLogs.length;

      // Group by day for the last 7 days
      final weeklyActivity = _buildWeeklyActivity(recentLogs);

      stats = DashboardStats(
        totalOrganizations: totalOrgs,
        totalAdmins: totalAdmins,
        totalEmployees: totalEmployees,
        activeUsers: activeUsers,
        recentActivity: recentActivity,
        weeklyActivity: weeklyActivity,
      );
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    _safeNotify();
  }

  Future<int> _countActiveOrgs() async {
    final snap = await _firestore.collection('organizations').get();
    return snap.docs
        .where((d) => (d.data()['status'] ?? '') != 'deleted')
        .length;
  }

  Future<int> _countAdmins() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    return snap.docs
        .where((d) => (d.data()['status'] ?? '') != 'deleted')
        .length;
  }

  Future<int> _countActiveEmployees() async {
    final snap = await _firestore
        .collection('employees')
        .where('status', isEqualTo: 'active')
        .get();
    return snap.size;
  }

  Future<List<Map<String, dynamic>>> _loadRecentLogs() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final snap = await _firestore
        .collection('logs')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  List<DailyActivity> _buildWeeklyActivity(List<Map<String, dynamic>> logs) {
    final today = DateTime.now();
    final Map<String, int> counts = {};

    for (final data in logs) {
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        final date = ts.toDate();
        final key = '${date.year}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      final key = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      return DailyActivity(date, counts[key] ?? 0);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
