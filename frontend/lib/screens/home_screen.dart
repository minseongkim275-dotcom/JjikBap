import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'records_screen.dart';
import 'mypage_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Key _dashboardKey = UniqueKey();
  Key _recordsKey = UniqueKey();
  Key _mypageKey = UniqueKey();

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(key: _dashboardKey),
      RecordsScreen(key: _recordsKey),
      MyPageScreen(key: _mypageKey),
    ];
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          // 탭 진입 시 화면을 새로 만들어 최신 기록을 다시 불러옴
          if (index == 1) _recordsKey = UniqueKey();
          if (index == 2) _mypageKey = UniqueKey();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[400],
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, '대시보드'),
                _buildNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, '기록'),
                _buildNavItem(2, Icons.person_rounded, Icons.person_outlined, '마이페이지'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
