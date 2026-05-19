import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../settings/providers/settings_provider.dart';
import 'home_screen.dart';
import '../../subjects/screens/subjects_screen.dart';
import '../../chat/screens/tutor_chat_screen.dart';
import '../../timer/screens/pomodoro_timer_screen.dart';
import '../../settings/screens/settings_screen.dart';

class MainNavigationContainer extends ConsumerStatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  ConsumerState<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends ConsumerState<MainNavigationContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SubjectsScreen(),
    TutorChatScreen(),
    PomodoroTimerScreen(),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: AppStrings.get('home', lang) ?? 'Home',
                  isActive: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavBarItem(
                  icon: Icons.book_outlined,
                  activeIcon: Icons.book_rounded,
                  label: AppStrings.get('subjects', lang) ?? 'Subjects',
                  isActive: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                // Glowing Chat Bot middle item
                _ChatBotNavBarItem(
                  isActive: _currentIndex == 2,
                  onTap: () => _onTabTapped(2),
                ),
                _NavBarItem(
                  icon: Icons.timer_outlined,
                  activeIcon: Icons.timer_rounded,
                  label: AppStrings.get('timer', lang) ?? 'Timer',
                  isActive: _currentIndex == 3,
                  onTap: () => _onTabTapped(3),
                ),
                _NavBarItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: AppStrings.get('settings', lang) ?? 'Settings',
                  isActive: _currentIndex == 4,
                  onTap: () => _onTabTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.accent : AppColors.inkLight,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? AppColors.accent : AppColors.inkLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBotNavBarItem extends StatelessWidget {
  const _ChatBotNavBarItem({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive 
                  ? [AppColors.accent, AppColors.accentGlow]
                  : [AppColors.accentSoft, AppColors.accentSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: isActive ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: isActive ? Colors.white : AppColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tutor',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? AppColors.accent : AppColors.inkLight,
            ),
          ),
        ],
      ),
    );
  }
}
