import 'package:flutter/material.dart';
import '../../../../core/theme/App_color.dart';
import '../Dashboard/dash_board_screen.dart';
import '../Organizations/organizations_screen.dart';
import '../Audit/Audit_Screen.dart';
import '../Profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const OrganizationsScreen(),
    const AuditScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 3, width: 36, decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Icon(Icons.dashboard),
              ],
            ),
            label: 'DASHBOARD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.corporate_fare_outlined),
            activeIcon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 3, width: 36, decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Icon(Icons.corporate_fare),
              ],
            ),
            label: 'ORGANIZATIONS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 3, width: 36, decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Icon(Icons.security),
              ],
            ),
            label: 'AUDIT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 3, width: 36, decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Icon(Icons.person),
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
}