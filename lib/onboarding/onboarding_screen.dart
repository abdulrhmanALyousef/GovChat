import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:projects/auth/login_screen.dart';
import 'package:projects/core/datasource/local_data/preferences_manager.dart';
import 'package:projects/core/theme/app_color.dart';
import 'package:projects/l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _iconAnim;
  int _currentPage = 0;

  static const int _pageCount = 4;

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconAnim.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _iconAnim.forward(from: 0);
  }

  void _next() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    PreferencesManager().setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final isLast = _currentPage == _pageCount - 1;

    final pages = [
      _PageData(
        icon: Icons.shield_rounded,
        iconBgColor: const Color(0xFF0D2B1E),
        title: l.onboarding1Title,
        subtitle: l.onboarding1Subtitle,
      ),
      _PageData(
        icon: Icons.groups_rounded,
        iconBgColor: const Color(0xFF0D1F2B),
        title: l.onboarding2Title,
        subtitle: l.onboarding2Subtitle,
      ),
      _PageData(
        icon: Icons.campaign_rounded,
        iconBgColor: const Color(0xFF1F1A0D),
        title: l.onboarding3Title,
        subtitle: l.onboarding3Subtitle,
      ),
      _PageData(
        icon: Icons.verified_user_rounded,
        iconBgColor: const Color(0xFF1A0D2B),
        title: l.onboarding4Title,
        subtitle: l.onboarding4Subtitle,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: skip button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Align(
                alignment:
                    isRtl ? Alignment.centerLeft : Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: isLast ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast ? null : _complete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 8.h),
                    ),
                    child: Text(
                      l.onboardingSkip,
                      style: GoogleFonts.manrope(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pageCount,
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: pages[index], anim: _iconAnim),
              ),
            ),

            // Bottom nav
            _BottomNav(
              currentPage: _currentPage,
              pageCount: _pageCount,
              isLast: isLast,
              nextLabel: l.onboardingNext,
              getStartedLabel: l.onboardingGetStarted,
              onNext: _next,
            ),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  const _PageData({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.anim});

  final _PageData data;
  final AnimationController anim;

  @override
  Widget build(BuildContext context) {
    final scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
    );
    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: anim, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: anim,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Opacity(
                opacity: fadeAnim.value,
                child: Transform.scale(
                  scale: scaleAnim.value,
                  child: Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      color: data.iconBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.12),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      data.icon,
                      size: 60.r,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 44.h),

              // Title
              Opacity(
                opacity: fadeAnim.value,
                child: SlideTransition(
                  position: slideAnim,
                  child: Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Subtitle
              Opacity(
                opacity: fadeAnim.value,
                child: SlideTransition(
                  position: slideAnim,
                  child: Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentPage,
    required this.pageCount,
    required this.isLast,
    required this.nextLabel,
    required this.getStartedLabel,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final bool isLast;
  final String nextLabel;
  final String getStartedLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: i == currentPage ? 24.w : 8.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? AppColors.primaryColor
                      : AppColors.navUnselected,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),

          SizedBox(height: 28.h),

          // Next / Get Started button
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonBackground,
                foregroundColor: AppColors.buttonText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Text(
                isLast ? getStartedLabel : nextLabel,
                style: GoogleFonts.manrope(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.buttonText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
