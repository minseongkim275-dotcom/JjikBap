import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/daily_stats.dart';

class GoalSettingsScreen extends StatefulWidget {
  const GoalSettingsScreen({super.key});

  @override
  State<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends State<GoalSettingsScreen> {
  final ApiService _apiService = ApiService();
  int? _userId;

  double _calorieGoal = 2000;
  double _proteinGoal = 60;
  double _carbGoal = 300;
  double _fatGoal = 65;
  String _activityLevel = 'moderate';
  String _dietGoal = 'maintain';

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
      _calorieGoal = prefs.getDouble('calorieGoal') ?? 2000;
      _proteinGoal = prefs.getDouble('proteinGoal') ?? 60;
      _carbGoal = prefs.getDouble('carbGoal') ?? 300;
      _fatGoal = prefs.getDouble('fatGoal') ?? 65;
      _activityLevel = prefs.getString('activityLevel') ?? 'moderate';
      _dietGoal = prefs.getString('dietGoal') ?? 'maintain';
    });

    // 서버에서도 로드 시도
    if (_userId != null) {
      try {
        final settings = await _apiService.getUserSettings(_userId!);
        setState(() {
          _activityLevel = settings['activity_level'] ?? 'moderate';
          _dietGoal = settings['diet_goal'] ?? 'maintain';
        });
      } catch (e) {
        print('[GoalSettings] 서버 설정 로드 실패: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('calorieGoal', _calorieGoal);
    await prefs.setDouble('proteinGoal', _proteinGoal);
    await prefs.setDouble('carbGoal', _carbGoal);
    await prefs.setDouble('fatGoal', _fatGoal);
    await prefs.setString('activityLevel', _activityLevel);
    await prefs.setString('dietGoal', _dietGoal);

    // 서버에 영양 목표 저장
    try {
      final goal = NutritionGoal(
        id: 0,
        date: DateTime.now(),
        calories: _calorieGoal,
        protein: _proteinGoal,
        carbs: _carbGoal,
        fat: _fatGoal,
        fiber: 25, // 기본값
      );
      await _apiService.setGoal(goal);
      print('[GoalSettings] 서버에 영양 목표 저장 완료');
    } catch (e) {
      print('[GoalSettings] 서버 영양 목표 저장 실패: $e');
    }

    // 서버에 활동량/식단 목표 저장
    if (_userId != null) {
      try {
        await _apiService.saveUserSettings(
          userId: _userId!,
          activityLevel: _activityLevel,
          dietGoal: _dietGoal,
        );
        print('[GoalSettings] 서버에 활동량/식단 목표 저장 완료');
      } catch (e) {
        print('[GoalSettings] 서버 활동량/식단 목표 저장 실패: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목표가 저장되었습니다'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _calculateRecommendedCalories() {
    // Basic calculation based on activity level and goal
    double baseCalories = 2000;

    switch (_activityLevel) {
      case 'sedentary':
        baseCalories = 1800;
        break;
      case 'light':
        baseCalories = 2000;
        break;
      case 'moderate':
        baseCalories = 2200;
        break;
      case 'active':
        baseCalories = 2400;
        break;
      case 'very_active':
        baseCalories = 2800;
        break;
    }

    switch (_dietGoal) {
      case 'lose':
        baseCalories -= 500;
        break;
      case 'gain':
        baseCalories += 300;
        break;
    }

    setState(() {
      _calorieGoal = baseCalories;
      // Calculate macros based on calories
      _proteinGoal = (_calorieGoal * 0.2 / 4).roundToDouble(); // 20% of calories
      _carbGoal = (_calorieGoal * 0.5 / 4).roundToDouble(); // 50% of calories
      _fatGoal = (_calorieGoal * 0.3 / 9).roundToDouble(); // 30% of calories
    });
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
          '목표 설정',
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

            // 활동량 섹션
            _buildSectionHeader('활동량'),
            _buildSettingsCard([
              _buildActivitySelector(),
            ]),

            const SizedBox(height: 20),

            // 식단 목표 섹션
            _buildSectionHeader('식단 목표'),
            _buildSettingsCard([
              _buildDietGoalSelector(),
            ]),

            const SizedBox(height: 12),

            // 자동 계산 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _calculateRecommendedCalories,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '추천 목표 자동 계산',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 칼로리 목표
            _buildSectionHeader('일일 칼로리 목표'),
            _buildSettingsCard([
              _buildSliderTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: Colors.orange,
                title: '칼로리',
                value: _calorieGoal,
                min: 1000,
                max: 4000,
                unit: 'kcal',
                onChanged: (value) {
                  setState(() => _calorieGoal = value.roundToDouble());
                },
              ),
            ]),

            const SizedBox(height: 20),

            // 영양소 목표
            _buildSectionHeader('영양소 목표'),
            _buildSettingsCard([
              _buildSliderTile(
                icon: Icons.egg_rounded,
                iconColor: Colors.red,
                title: '단백질',
                value: _proteinGoal,
                min: 20,
                max: 200,
                unit: 'g',
                onChanged: (value) {
                  setState(() => _proteinGoal = value.roundToDouble());
                },
              ),
              _buildDivider(),
              _buildSliderTile(
                icon: Icons.grain_rounded,
                iconColor: Colors.amber,
                title: '탄수화물',
                value: _carbGoal,
                min: 50,
                max: 500,
                unit: 'g',
                onChanged: (value) {
                  setState(() => _carbGoal = value.roundToDouble());
                },
              ),
              _buildDivider(),
              _buildSliderTile(
                icon: Icons.water_drop_rounded,
                iconColor: Colors.blue,
                title: '지방',
                value: _fatGoal,
                min: 20,
                max: 150,
                unit: 'g',
                onChanged: (value) {
                  setState(() => _fatGoal = value.roundToDouble());
                },
              ),
            ]),

            const SizedBox(height: 24),

            // 영양소 비율 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pie_chart_rounded, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '영양소 비율',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMacroBar(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroLegend('단백질', Colors.red, _proteinGoal * 4),
                        _buildMacroLegend('탄수화물', Colors.amber, _carbGoal * 4),
                        _buildMacroLegend('지방', Colors.blue, _fatGoal * 9),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar() {
    final proteinCal = _proteinGoal * 4;
    final carbCal = _carbGoal * 4;
    final fatCal = _fatGoal * 9;
    final total = proteinCal + carbCal + fatCal;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 24,
        child: Row(
          children: [
            Expanded(
              flex: (proteinCal / total * 100).round(),
              child: Container(color: Colors.red),
            ),
            Expanded(
              flex: (carbCal / total * 100).round(),
              child: Container(color: Colors.amber),
            ),
            Expanded(
              flex: (fatCal / total * 100).round(),
              child: Container(color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroLegend(String label, Color color, double calories) {
    final proteinCal = _proteinGoal * 4;
    final carbCal = _carbGoal * 4;
    final fatCal = _fatGoal * 9;
    final total = proteinCal + carbCal + fatCal;
    final percentage = (calories / total * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
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

  Widget _buildActivitySelector() {
    final activities = [
      {'value': 'sedentary', 'label': '좌식', 'desc': '거의 운동 안함'},
      {'value': 'light', 'label': '가벼움', 'desc': '주 1-2회 운동'},
      {'value': 'moderate', 'label': '보통', 'desc': '주 3-5회 운동'},
      {'value': 'active', 'label': '활발', 'desc': '주 6-7회 운동'},
      {'value': 'very_active', 'label': '매우 활발', 'desc': '하루 2회 운동'},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: activities.map((activity) {
          final isSelected = _activityLevel == activity['value'];
          return GestureDetector(
            onTap: () {
              setState(() => _activityLevel = activity['value']!);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    activity['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity['desc']!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDietGoalSelector() {
    final goals = [
      {'value': 'lose', 'label': '체중 감량', 'icon': Icons.trending_down_rounded, 'color': Colors.blue},
      {'value': 'maintain', 'label': '체중 유지', 'icon': Icons.horizontal_rule_rounded, 'color': const Color(0xFF4CAF50)},
      {'value': 'gain', 'label': '체중 증가', 'icon': Icons.trending_up_rounded, 'color': Colors.orange},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: goals.map((goal) {
          final isSelected = _dietGoal == goal['value'];
          final color = goal['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _dietGoal = goal['value'] as String);
              },
              child: Container(
                margin: EdgeInsets.only(
                  right: goal['value'] != 'gain' ? 8 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: color, width: 2)
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      goal['icon'] as IconData,
                      color: isSelected ? color : Colors.grey[400],
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      goal['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toInt()}$unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: iconColor,
              inactiveTrackColor: iconColor.withOpacity(0.2),
              thumbColor: iconColor,
              overlayColor: iconColor.withOpacity(0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
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
