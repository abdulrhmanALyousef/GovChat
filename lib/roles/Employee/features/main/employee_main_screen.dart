import 'dart:async';

import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import '../announce/announce_screen.dart';
import '../chat_list/chat_list_screen.dart';
import '../home/home_screen.dart';
import '../profile/employee_profile_screen.dart';
import '../remind/remind_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _currentIndex = 0;
  bool _checkingAccess = true;
  bool _authorized = false;

  late final List<Widget> _screens;
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(employee: widget.employee),
      AnnounceScreen(employee: widget.employee),
      ChatListScreen(employee: widget.employee),
      RemindScreen(employee: widget.employee),
      EmployeeProfileScreen(employee: widget.employee),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await SessionManager.instance.ensureRole(
        context,
        allowedRoles: const ['employee'],
      );
      if (!mounted) return;
      setState(() {
        _authorized = allowed;
        _checkingAccess = false;
      });

      if (allowed) {
        // Subscribe to notification taps for in-app routing
        _notifSub = PushNotificationService.instance.onNotificationTapped
            .listen(_handleNotificationTap);

        // Route any notification that opened the app from terminated state
        PushNotificationService.instance.checkInitialMessage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }

    if (!_authorized) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context)!;

    return Scaffold(
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.bottomNavBackground,
          elevation: 0,
          selectedItemColor: AppColors.primaryColor,
          unselectedItemColor: AppColors.navUnselected,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          currentIndex: _currentIndex,
          onTap: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            _buildNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: l.navHome,
            ),
            _buildNavItem(
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign,
              label: l.navAnnounce,
            ),
            _buildNavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: l.navChat,
            ),
            _buildNavItem(
              icon: Icons.notifications_outlined,
              activeIcon: Icons.notifications,
              label: l.navRemind,
            ),
            _buildNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: l.navProfile,
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
    );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  /// Routes a notification tap to the appropriate tab.
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'chat':
        setState(() => _currentIndex = 2); // CHAT tab
        break;
      case 'announcement':
        setState(() => _currentIndex = 1); // ANNOUNCE tab
        break;
      case 'reminder':
        setState(() => _currentIndex = 3); // REMIND tab
        break;
      default:
        // Unknown type — go to home
        setState(() => _currentIndex = 0);
    }
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 3,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Icon(activeIcon),
        ],
      ),
      label: label,
    );
  }
}