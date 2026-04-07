import 'package:flutter/material.dart';

import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../Audit/audit_screen.dart';
import '../Dashboard/dash_board_screen.dart';
import '../Organizations/organizations_screen.dart';
import '../Profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _checkingAccess = true;
  bool _authorized = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    OrganizationsScreen(),
    AuditScreen(),
    ProfileScreen(),
  ];

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
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
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
                  const Icon(Icons.dashboard),
                ],
              ),
              label: 'DASHBOARD',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.corporate_fare_outlined),
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
                  const Icon(Icons.corporate_fare),
                ],
              ),
              label: 'ORGANIZATIONS',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.security_outlined),
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
                  const Icon(Icons.security),
                ],
              ),
              label: 'AUDIT',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
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
                  const Icon(Icons.person),
                ],
              ),
              label: 'PROFILE',
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await SessionManager.instance.ensureRole(
        context,
        allowedRoles: const ['primary_admin'],
      );
      if (!mounted) return;
      setState(() {
        _authorized = allowed;
        _checkingAccess = false;
      });
    });
  }
}
