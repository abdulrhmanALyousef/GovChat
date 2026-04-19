import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../requests/requests_screen.dart';
import '../emplyees/employees_screen.dart';
import '../logs/logs_screen.dart';
import '../profile/admin_profile_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  bool _checkingAccess = true;
  bool _authorized = false;

  final List<Widget> _screens = [
    const RequestsScreen(),
    const EmployeesScreen(),
    const LogsScreen(),
    const AdminProfileScreen(),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox_outlined),
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
                  Icon(Icons.inbox),
                ],
              ),
              label: l.navRequests,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
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
                  Icon(Icons.people),
                ],
              ),
              label: l.navEmployees,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
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
                  Icon(Icons.history),
                ],
              ),
              label: l.navLogs,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
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
                  Icon(Icons.person),
                ],
              ),
              label: l.navProfile,
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
        allowedRoles: const ['admin'],
      );
      if (!mounted) return;
      setState(() {
        _authorized = allowed;
        _checkingAccess = false;
      });
    });
  }
}
