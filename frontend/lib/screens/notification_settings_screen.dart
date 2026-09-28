import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  int? _userId;

  bool _mealReminder = true;
  bool _breakfastReminder = true;
  bool _lunchReminder = true;
  bool _dinnerReminder = true;
  bool _goalAchievement = true;
  bool _weeklyReport = true;

  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 18, minute: 30);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');

    // 먼저 로컬에서 로드
    setState(() {
      _mealReminder = prefs.getBool('mealReminder') ?? true;
      _breakfastReminder = prefs.getBool('breakfastReminder') ?? true;
      _lunchReminder = prefs.getBool('lunchReminder') ?? true;
      _dinnerReminder = prefs.getBool('dinnerReminder') ?? true;
      _goalAchievement = prefs.getBool('goalAchievement') ?? true;
      _weeklyReport = prefs.getBool('weeklyReport') ?? true;

      final breakfastHour = prefs.getInt('breakfastHour') ?? 8;
      final breakfastMinute = prefs.getInt('breakfastMinute') ?? 0;
      _breakfastTime = TimeOfDay(hour: breakfastHour, minute: breakfastMinute);

      final lunchHour = prefs.getInt('lunchHour') ?? 12;
      final lunchMinute = prefs.getInt('lunchMinute') ?? 0;
      _lunchTime = TimeOfDay(hour: lunchHour, minute: lunchMinute);

      final dinnerHour = prefs.getInt('dinnerHour') ?? 18;
      final dinnerMinute = prefs.getInt('dinnerMinute') ?? 30;
      _dinnerTime = TimeOfDay(hour: dinnerHour, minute: dinnerMinute);
    });

    // 서버에서도 로드 시도
    if (_userId != null) {
      try {
        final settings = await _apiService.getUserSettings(_userId!);
        setState(() {
          _mealReminder = settings['meal_reminder'] ?? true;
          _breakfastReminder = settings['breakfast_reminder'] ?? true;
          _lunchReminder = settings['lunch_reminder'] ?? true;
          _dinnerReminder = settings['dinner_reminder'] ?? true;
          _goalAchievement = settings['goal_achievement'] ?? true;
          _weeklyReport = settings['weekly_report'] ?? true;
          _breakfastTime = TimeOfDay(
            hour: settings['breakfast_hour'] ?? 8,
            minute: settings['breakfast_minute'] ?? 0,
          );
          _lunchTime = TimeOfDay(
            hour: settings['lunch_hour'] ?? 12,
            minute: settings['lunch_minute'] ?? 0,
          );
          _dinnerTime = TimeOfDay(
            hour: settings['dinner_hour'] ?? 18,
            minute: settings['dinner_minute'] ?? 30,
          );
        });
      } catch (e) {
        print('[NotificationSettings] 서버 설정 로드 실패: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mealReminder', _mealReminder);
    await prefs.setBool('breakfastReminder', _breakfastReminder);
    await prefs.setBool('lunchReminder', _lunchReminder);
    await prefs.setBool('dinnerReminder', _dinnerReminder);
    await prefs.setBool('goalAchievement', _goalAchievement);
    await prefs.setBool('weeklyReport', _weeklyReport);

    await prefs.setInt('breakfastHour', _breakfastTime.hour);
    await prefs.setInt('breakfastMinute', _breakfastTime.minute);
    await prefs.setInt('lunchHour', _lunchTime.hour);
    await prefs.setInt('lunchMinute', _lunchTime.minute);
    await prefs.setInt('dinnerHour', _dinnerTime.hour);
    await prefs.setInt('dinnerMinute', _dinnerTime.minute);

    // 서버에도 저장
    if (_userId != null) {
      try {
        await _apiService.saveUserSettings(
          userId: _userId!,
          mealReminder: _mealReminder,
          breakfastReminder: _breakfastReminder,
          lunchReminder: _lunchReminder,
          dinnerReminder: _dinnerReminder,
          goalAchievement: _goalAchievement,
          weeklyReport: _weeklyReport,
          breakfastHour: _breakfastTime.hour,
          breakfastMinute: _breakfastTime.minute,
          lunchHour: _lunchTime.hour,
          lunchMinute: _lunchTime.minute,
          dinnerHour: _dinnerTime.hour,
          dinnerMinute: _dinnerTime.minute,
        );
        print('[NotificationSettings] 서버 설정 저장 완료');
      } catch (e) {
        print('[NotificationSettings] 서버 설정 저장 실패: $e');
      }
    }

    // 알림 스케줄링 업데이트
    await _notificationService.scheduleFromSettings();
    print('[NotificationSettings] 알림 스케줄 업데이트 완료');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 저장되었습니다'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  Future<void> _selectTime(String meal) async {
    TimeOfDay initialTime;
    switch (meal) {
      case 'breakfast':
        initialTime = _breakfastTime;
        break;
      case 'lunch':
        initialTime = _lunchTime;
        break;
      case 'dinner':
        initialTime = _dinnerTime;
        break;
      default:
        return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        switch (meal) {
          case 'breakfast':
            _breakfastTime = picked;
            break;
          case 'lunch':
            _lunchTime = picked;
            break;
          case 'dinner':
            _dinnerTime = picked;
            break;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림 설정',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: Colors.black26,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 식사 알림 섹션
            _buildSectionHeader('식사 알림'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.restaurant_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: '식사 알림',
                subtitle: '식사 시간에 알림을 받습니다',
                value: _mealReminder,
                onChanged: (value) {
                  setState(() => _mealReminder = value);
                },
              ),
            ]),

            if (_mealReminder) ...[
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildTimeTile(
                  icon: Icons.wb_sunny_rounded,
                  iconColor: Colors.orange,
                  title: '아침 식사',
                  time: _breakfastTime,
                  enabled: _breakfastReminder,
                  onEnabledChanged: (value) {
                    setState(() => _breakfastReminder = value);
                  },
                  onTimeTap: () => _selectTime('breakfast'),
                ),
                _buildDivider(),
                _buildTimeTile(
                  icon: Icons.wb_sunny_outlined,
                  iconColor: Colors.amber,
                  title: '점심 식사',
                  time: _lunchTime,
                  enabled: _lunchReminder,
                  onEnabledChanged: (value) {
                    setState(() => _lunchReminder = value);
                  },
                  onTimeTap: () => _selectTime('lunch'),
                ),
                _buildDivider(),
                _buildTimeTile(
                  icon: Icons.nights_stay_rounded,
                  iconColor: Colors.indigo,
                  title: '저녁 식사',
                  time: _dinnerTime,
                  enabled: _dinnerReminder,
                  onEnabledChanged: (value) {
                    setState(() => _dinnerReminder = value);
                  },
                  onTimeTap: () => _selectTime('dinner'),
                ),
              ]),
            ],

            const SizedBox(height: 24),

            // 기타 알림 섹션
            _buildSectionHeader('기타 알림'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.emoji_events_rounded,
                iconColor: Colors.amber,
                title: '목표 달성 알림',
                subtitle: '일일 목표 달성 시 축하 알림',
                value: _goalAchievement,
                onChanged: (value) {
                  setState(() => _goalAchievement = value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.assessment_rounded,
                iconColor: Colors.blue,
                title: '주간 리포트',
                subtitle: '매주 월요일 식습관 분석 리포트',
                value: _weeklyReport,
                onChanged: (value) {
                  setState(() => _weeklyReport = value);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // 안내 문구
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '알림을 받으려면 기기의 알림 설정에서 찍밥 앱의 알림을 허용해주세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required TimeOfDay time,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required VoidCallback onTimeTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.black87 : Colors.grey[400],
              ),
            ),
          ),
          GestureDetector(
            onTap: enabled ? onTimeTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTime(time),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? const Color(0xFF4CAF50) : Colors.grey[400],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: onEnabledChanged,
            activeColor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey[100]),
    );
  }
}
