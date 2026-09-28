import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import '../models/food_record.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final ApiService _apiService = ApiService();
  List<FoodRecord> _allRecords = [];
  List<FoodRecord> _filteredRecords = [];
  bool _isLoading = false;
  bool _isGridView = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  int? _userId;

  // 기간 필터 (캘린더)
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _rangeStart;  // 범위 시작
  DateTime? _rangeEnd;    // 범위 끝

  // 캘린더 상태
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isCalendarExpanded = false;
  bool _isSelectingRange = false;  // 범위 선택 중인지

  // 날짜별 음식 기록 맵
  Map<DateTime, List<FoodRecord>> _recordsByDate = {};

  // 통계 데이터
  double _totalScore = 0;
  String _grade = 'F';
  double _avgCalories = 0;
  double _avgProtein = 0;
  double _avgCarbs = 0;
  double _avgFat = 0;

  // 일별 점수 데이터 (그래프용)
  List<MapEntry<DateTime, double>> _dailyScores = [];

  // 그래프 범위 (일 수)
  int _graphDays = 7;

  // 백엔드 API 점수 데이터
  Map<String, dynamic>? _userScoreData;
  bool _isLoadingScore = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
    _searchController.addListener(_filterRecords);
  }

  Future<void> _initializeAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');
    _loadRecords();
    _loadUserScore();
  }

  // 백엔드에서 사용자 식단 점수/등급 로드
  Future<void> _loadUserScore() async {
    setState(() => _isLoadingScore = true);
    try {
      final data = await _apiService.getUserScore(userId: _userId, days: _graphDays);
      if (mounted) {
        setState(() {
          _userScoreData = data;
          // 백엔드 데이터로 점수/등급 업데이트
          _totalScore = (data['score'] as num?)?.toDouble() ?? _totalScore;
          _grade = data['grade'] as String? ?? _grade;
          _isLoadingScore = false;
        });
      }
    } catch (e) {
      print('사용자 점수 로드 실패: $e');
      if (mounted) {
        setState(() => _isLoadingScore = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      // 먼저 기간 필터 적용
      List<FoodRecord> periodFiltered = _applyPeriodFilter(_allRecords);

      // 그 다음 검색 필터 적용
      if (query.isEmpty) {
        _filteredRecords = periodFiltered;
      } else {
        _filteredRecords = periodFiltered
            .where((record) => record.foodName.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  List<FoodRecord> _applyPeriodFilter(List<FoodRecord> records) {
    if (_startDate == null && _endDate == null) return records;

    return records.where((record) {
      if (record.createdAt == null) return false;
      final recordDate = DateTime(
        record.createdAt!.year,
        record.createdAt!.month,
        record.createdAt!.day,
      );

      if (_startDate != null && _endDate != null) {
        return !recordDate.isBefore(_startDate!) && !recordDate.isAfter(_endDate!);
      } else if (_startDate != null) {
        return !recordDate.isBefore(_startDate!);
      } else if (_endDate != null) {
        return !recordDate.isAfter(_endDate!);
      }
      return true;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // 해당 날짜에 먹은 음식 찾기
      final selectedDate = DateTime(picked.year, picked.month, picked.day);
      final mealsOnDate = _allRecords.where((record) {
        if (record.createdAt == null) return false;
        final recordDate = DateTime(
          record.createdAt!.year,
          record.createdAt!.month,
          record.createdAt!.day,
        );
        return recordDate == selectedDate;
      }).toList();

      // 해당 날짜 음식 목록 보여주기
      _showMealsOnDate(picked, mealsOnDate);
    }
  }

  void _showMealsOnDate(DateTime date, List<FoodRecord> meals) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF4CAF50),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy년 MM월 dd일').format(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${meals.length}개의 식사 기록',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey[500]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 음식 목록
            Expanded(
              child: ListView.builder(
                itemCount: meals.length,
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  final time = meal.createdAt != null
                      ? DateFormat('HH:mm').format(meal.createdAt!)
                      : '';
                  final mealType = meal.createdAt != null
                      ? _getMealTime(meal.createdAt!)
                      : '';

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showRecordDetail(meal);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          // 이미지 또는 아이콘 (더 크게)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _getImageUrl(meal.imagePath) != null
                                ? Image.network(
                                    _getImageUrl(meal.imagePath)!,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 70,
                                      height: 70,
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(0.1),
                                      child: const Icon(
                                        Icons.restaurant,
                                        color: Color(0xFF4CAF50),
                                        size: 30,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Color(0xFF4CAF50),
                                      size: 30,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          // 음식 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.foodName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$time $mealType',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientSummary(
      String label, String value, String unit, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _filterRecords();
  }

  String _getComment() {
    if (_allRecords.isEmpty) {
      return '아직 기록이 없어요. 첫 식단을 기록해보세요!';
    }

    if (_totalScore >= 90) {
      return '완벽한 식단 관리! 균형 잡힌 영양소 섭취를 유지하고 있어요.';
    } else if (_totalScore >= 80) {
      return '훌륭해요! 건강한 식습관을 잘 유지하고 있네요.';
    } else if (_totalScore >= 70) {
      return '좋아요! 조금만 더 신경 쓰면 완벽한 식단이 될 거예요.';
    } else if (_totalScore >= 60) {
      return '나쁘지 않아요. 단백질과 채소 섭취를 늘려보세요.';
    } else if (_totalScore >= 50) {
      return '개선이 필요해요. 균형 잡힌 식단을 위해 노력해보세요.';
    } else {
      return '식단 관리가 필요해요. 영양소 균형에 신경 써주세요!';
    }
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      // 백엔드 API에서 사용자별 기록 가져오기
      final records = await _apiService.getFoodRecords(userId: _userId);

      setState(() {
        _allRecords = records;
        _buildRecordsByDate(); // 날짜별 음식 기록 맵 생성
        _calculateStats();
        _isLoading = false;
      });
      _filterRecords();
    } catch (e) {
      print('기록 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  // 날짜별 음식 기록 맵 생성
  void _buildRecordsByDate() {
    _recordsByDate = {};
    for (var record in _allRecords) {
      if (record.createdAt != null) {
        final dateKey = DateTime(
          record.createdAt!.year,
          record.createdAt!.month,
          record.createdAt!.day,
        );
        if (!_recordsByDate.containsKey(dateKey)) {
          _recordsByDate[dateKey] = [];
        }
        _recordsByDate[dateKey]!.add(record);
      }
    }
  }

  // 특정 날짜의 음식 기록 가져오기
  List<FoodRecord> _getRecordsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _recordsByDate[dateKey] ?? [];
  }

  void _calculateStats() {
    if (_allRecords.isEmpty) {
      _avgCalories = 0;
      _avgProtein = 0;
      _avgCarbs = 0;
      _avgFat = 0;
      _dailyScores = [];
      return;
    }

    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;

    // 일별 점수 계산을 위한 맵 (백엔드 API에서 받은 점수 사용)
    Map<String, List<double>> dailyScoreMap = {};

    for (var record in _allRecords) {
      totalCal += record.calories;
      totalPro += record.protein;
      totalCarb += record.carbs;
      totalFat += record.fat;

      // 백엔드에서 받은 점수로 일별 그룹화
      if (record.createdAt != null && record.score != null) {
        String dateKey = DateFormat('yyyy-MM-dd').format(record.createdAt!);
        if (!dailyScoreMap.containsKey(dateKey)) {
          dailyScoreMap[dateKey] = [];
        }
        dailyScoreMap[dateKey]!.add(record.score!);
      }
    }

    int count = _allRecords.length;
    _avgCalories = totalCal / count;
    _avgProtein = totalPro / count;
    _avgCarbs = totalCarb / count;
    _avgFat = totalFat / count;

    // 일별 평균 점수 계산 및 정렬
    _dailyScores = dailyScoreMap.entries.map((entry) {
      DateTime date = DateTime.parse(entry.key);
      double avgScore = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return MapEntry(date, avgScore);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // 최근 14일만 표시
    if (_dailyScores.length > 14) {
      _dailyScores = _dailyScores.sublist(_dailyScores.length - 14);
    }
  }

  double _calculateRecordScore(FoodRecord record) {
    double score = 0;

    // 칼로리 점수 (적정 범위: 400-800 kcal per meal)
    if (record.calories >= 400 && record.calories <= 800) {
      score += 25;
    } else if (record.calories >= 300 && record.calories <= 900) {
      score += 18;
    } else if (record.calories >= 200 && record.calories <= 1000) {
      score += 10;
    }

    // 단백질 점수 (15g 이상 권장)
    if (record.protein >= 25) {
      score += 25;
    } else if (record.protein >= 20) {
      score += 22;
    } else if (record.protein >= 15) {
      score += 18;
    } else if (record.protein >= 10) {
      score += 12;
    } else {
      score += 5;
    }

    // 탄수화물 점수 (적정 범위: 50-100g)
    if (record.carbs >= 50 && record.carbs <= 100) {
      score += 25;
    } else if (record.carbs >= 30 && record.carbs <= 120) {
      score += 18;
    } else if (record.carbs >= 20 && record.carbs <= 150) {
      score += 10;
    }

    // 지방 점수 (적정 범위: 10-25g)
    if (record.fat >= 10 && record.fat <= 25) {
      score += 25;
    } else if (record.fat >= 5 && record.fat <= 35) {
      score += 18;
    } else if (record.fat < 5) {
      score += 10;
    } else {
      score += 5;
    }

    return score;
  }

  String _getGrade(double score) {
    // 백엔드와 동일한 등급 기준 (A~F)
    if (score >= 90) return 'A';
    if (score >= 75) return 'B';
    if (score >= 60) return 'C';
    if (score >= 45) return 'D';
    return 'F';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF4CAF50); // Green
      case 'B':
        return const Color(0xFF2196F3); // Blue
      case 'C':
        return const Color(0xFFFF9800); // Orange
      case 'D':
        return const Color(0xFF9E9E9E); // Grey
      case 'F':
      default:
        return const Color(0xFFE53935); // Red
    }
  }

  Future<void> _deleteRecord(int id) async {
    try {
      await _apiService.deleteFoodRecord(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다'), backgroundColor: Color(0xFF4CAF50)),
      );
      _loadRecords();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 이미지 URL 생성 (백엔드 서버에서 가져오기)
  String? _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;

    // 이미 전체 URL이면 그대로 반환
    if (imagePath.startsWith('http')) return imagePath;

    // 로컬 경로면 null 반환 (서버 이미지만 표시)
    if (imagePath.startsWith('/data/')) return null;

    // 백엔드 서버의 이미지 URL
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    // 슬래시 중복 제거
    final path = imagePath.startsWith('/') ? imagePath : '/$imagePath';
    return '$baseUrl$path';
  }

  String _getMealTime(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 4 && hour < 11) return '아침';
    if (hour >= 11 && hour < 17) return '점심';
    if (hour >= 17 && hour < 22) return '저녁';
    return '야식';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '음식 이름 검색...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              )
            : const Text(
                '음식기록',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
              ),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterRecords();
                }
              });
            },
            icon: Icon(
              _isSearching ? Icons.close : Icons.search_rounded,
              color: Colors.grey[700],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(
              _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
              color: Colors.grey[700],
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadRecords();
                await _loadUserScore();
              },
              color: const Color(0xFF4CAF50),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 토탈 점수 & 등급 섹션
                    _buildScoreSection(),

                    // 코멘트 섹션
                    _buildCommentSection(),

                    // 일별 점수 그래프
                    _buildDailyScoreChart(),

                    const SizedBox(height: 12),
                    // 얇은 검은선 구분
                    Container(
                      height: 0.5,
                      color: Colors.black26,
                    ),

                    // 캘린더 기간 선택기
                    _buildCalendarSelector(),

                    // 얇은 검은선 구분
                    Container(
                      height: 0.5,
                      color: Colors.black26,
                    ),

                    // 필터 상태 표시 (날짜 필터가 있고 기록이 있을 때)
                    if (_rangeStart != null && _filteredRecords.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list_rounded, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              _rangeEnd != null
                                  ? '${DateFormat('MM/dd').format(_rangeStart!)} ~ ${DateFormat('MM/dd').format(_rangeEnd!)} : ${_filteredRecords.length}개'
                                  : '${DateFormat('MM/dd').format(_rangeStart!)} : ${_filteredRecords.length}개',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 기록 리스트
                    _filteredRecords.isEmpty
                        ? _buildEmptyState()
                        : _isGridView
                            ? _buildPhotoGridInline()
                            : _buildListViewInline(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScoreSection() {
    // 로딩 중이면 로딩 표시
    if (_isLoadingScore && _userScoreData == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
      );
    }

    // 백엔드 데이터에서 점수/등급 가져오기
    final score = _userScoreData != null
        ? (_userScoreData!['score'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final grade = _userScoreData != null
        ? (_userScoreData!['grade'] as String?) ?? 'F'
        : 'F';

    final gradeColor = _getGradeColor(grade);

    // 등급별 배경 그라데이션 색상 (A~F)
    List<Color> gradientColors;
    switch (grade) {
      case 'A':
        gradientColors = [const Color(0xFFA5D6A7), const Color(0xFF81C784), const Color(0xFF66BB6A)]; // Green
        break;
      case 'B':
        gradientColors = [const Color(0xFF90CAF9), const Color(0xFF64B5F6), const Color(0xFF42A5F5)]; // Blue
        break;
      case 'C':
        gradientColors = [const Color(0xFFFFCC80), const Color(0xFFFFB74D), const Color(0xFFFFA726)]; // Orange
        break;
      case 'D':
        gradientColors = [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E), const Color(0xFF757575)]; // Grey
        break;
      case 'F':
      default:
        gradientColors = [const Color(0xFFEF9A9A), const Color(0xFFE57373), const Color(0xFFEF5350)]; // Red
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 메인 그라데이션 배경
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 등급 배지 (고급스러운 디자인)
                      _buildPremiumGradeBadge(gradeColor, grade),
                      const SizedBox(width: 20),
                      // 점수 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.restaurant_rounded, size: 12, color: Colors.white.withOpacity(0.9)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '나의 식단 점수',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 점수 표시 (큰 숫자) - 백엔드 API
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  score.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                    letterSpacing: -2,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                                  child: Text(
                                    '/ 100',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 세부 점수 (음식/영양/습관) - 백엔드 API 기반
                  if (_userScoreData != null && _userScoreData!['details'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.restaurant_rounded,
                            '${(_userScoreData!['details']['food_score'] as num?)?.toStringAsFixed(0) ?? '0'}', '음식'),
                          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                          _buildStatItem(Icons.eco_rounded,
                            '${(_userScoreData!['details']['nutrition_score'] as num?)?.toStringAsFixed(0) ?? '0'}', '영양'),
                          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                          _buildStatItem(Icons.schedule_rounded,
                            '${(_userScoreData!['details']['habit_score'] as num?)?.toStringAsFixed(0) ?? '0'}', '습관'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            // 장식용 원형 패턴들 (배경보다 연하게 - 흰색 반투명)
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumGradeBadge(Color gradeColor, String grade) {
    final isTopGrade = grade == 'A';  // A등급이 최고 등급

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: gradeColor.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: gradeColor.withOpacity(0.3),
          width: 3,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 내부 원
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  gradeColor.withOpacity(0.1),
                  gradeColor.withOpacity(0.05),
                ],
              ),
            ),
          ),
          // 등급 텍스트
          Text(
            grade,
            style: TextStyle(
              fontSize: grade.length > 2 ? 22 : 30,
              fontWeight: FontWeight.w900,
              color: gradeColor,
              letterSpacing: -1,
            ),
          ),
          // 상단 하이라이트
          Positioned(
            top: 8,
            child: Container(
              width: 30,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.3)],
                ),
              ),
            ),
          ),
          // 골드 뱃지 표시 (상위 등급)
          if (isTopGrade)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyScoreChart() {
    if (_dailyScores.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              '기록이 추가되면 일별 점수 그래프가 표시됩니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: const Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '일별 점수 변화',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              // 범위 선택 버튼들
              _buildGraphRangeButton(7, '7일'),
              const SizedBox(width: 6),
              _buildGraphRangeButton(14, '14일'),
              const SizedBox(width: 6),
              _buildGraphRangeButton(30, '30일'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _dailyScores.length) {
                          return const SizedBox.shrink();
                        }
                        // 최대 7개 라벨만 표시
                        if (_dailyScores.length > 7 && index % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        DateTime date = _dailyScores[index].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('M/d').format(date),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_dailyScores.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF4CAF50),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        DateTime date = _dailyScores[spot.x.toInt()].key;
                        String grade = _getGrade(spot.y);
                        return LineTooltipItem(
                          '${DateFormat('M/d').format(date)}\n${spot.y.toStringAsFixed(1)}점 ($grade)',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _dailyScores.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.value);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFF4CAF50),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        Color dotColor = _getGradeColor(_getGrade(spot.y));
                        return FlDotCirclePainter(
                          radius: 5,
                          color: dotColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.3),
                          const Color(0xFF4CAF50).withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphRangeButton(int days, String label) {
    final isSelected = _graphDays == days;
    return GestureDetector(
      onTap: () {
        if (_graphDays != days) {
          setState(() {
            _graphDays = days;
          });
          _loadUserScore();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    // 백엔드 API에서 피드백 가져오기
    final feedbackList = _userScoreData?['feedback'] as List<dynamic>? ?? [];
    final feedbackText = feedbackList.isNotEmpty
        ? feedbackList.join('\n')
        : '식단 기록을 추가하면 피드백을 받을 수 있어요!';

    final score = _userScoreData != null
        ? (_userScoreData!['score'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final grade = _userScoreData?['grade'] as String? ?? 'F';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            score >= 70 ? Icons.sentiment_satisfied_alt_rounded :
            score >= 50 ? Icons.sentiment_neutral_rounded :
            Icons.sentiment_dissatisfied_rounded,
            color: _getGradeColor(grade),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feedbackText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSelector() {
    return Column(
      children: [
        // 캘린더 토글 버튼
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isCalendarExpanded = !_isCalendarExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isCalendarExpanded
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCalendarExpanded
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: _isCalendarExpanded
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '식사 기록 캘린더',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // 기록 있는 날짜 수 표시
                  if (_recordsByDate.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_recordsByDate.length}일',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isCalendarExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 캘린더 (확장 시 표시)
        if (_isCalendarExpanded) _buildCalendarWidget(),
      ],
    );
  }

  Widget _buildCalendarWidget() {
    return GestureDetector(
      // 스크롤이 캘린더에서 막히지 않도록 설정
      behavior: HitTestBehavior.translucent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 범례
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildLegendItem('A', const Color(0xFF4CAF50)),
                  const SizedBox(width: 6),
                  _buildLegendItem('B', const Color(0xFF8BC34A)),
                  const SizedBox(width: 6),
                  _buildLegendItem('C', const Color(0xFFFFC107)),
                  const SizedBox(width: 6),
                  _buildLegendItem('D', const Color(0xFFFF9800)),
                  const SizedBox(width: 6),
                  _buildLegendItem('F', const Color(0xFFF44336)),
                ],
              ),
            ),
            TableCalendar<FoodRecord>(
              locale: 'ko_KR',
              firstDay: DateTime(2020),
              lastDay: DateTime.now(),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: _getRecordsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              availableGestures: AvailableGestures.horizontalSwipe,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFFFF9800),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 6,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                weekendTextStyle: TextStyle(color: Colors.red[400]),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey[700]),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey[700]),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  color: Colors.red[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                final normalizedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                // 해당 날짜에 기록이 있으면 음식 목록 표시
                if (_recordsByDate.containsKey(normalizedDay)) {
                  _showMealsOnDate(normalizedDay, _recordsByDate[normalizedDay]!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${DateFormat('MM월 dd일').format(selectedDay)}에 기록된 음식이 없어요',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.grey[700],
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final records = _getRecordsForDay(day);
                  final hasRecords = records.isNotEmpty;
                  final normalizedDay = DateTime(day.year, day.month, day.day);

                  if (hasRecords) {
                    // 해당 날짜의 평균 등급으로 색상 결정
                    double avgScore = 0;
                    int count = 0;
                    for (var r in records) {
                      if (r.score != null) {
                        avgScore += r.score!;
                        count++;
                      }
                    }
                    String grade = 'C';
                    if (count > 0) {
                      avgScore /= count;
                      grade = _getGrade(avgScore);
                    }
                    final color = _getGradeColor(grade);

                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isSearchEmpty = _searchController.text.isNotEmpty && _filteredRecords.isEmpty;
    final isDateFiltered = _rangeStart != null && _filteredRecords.isEmpty;

    String title;
    String subtitle;
    IconData icon;

    if (isSearchEmpty) {
      title = '검색 결과가 없습니다';
      subtitle = '다른 검색어를 시도해보세요';
      icon = Icons.search_off_rounded;
    } else if (isDateFiltered) {
      if (_rangeEnd != null) {
        title = '${DateFormat('MM/dd').format(_rangeStart!)} ~ ${DateFormat('MM/dd').format(_rangeEnd!)}';
        subtitle = '해당 기간에 기록이 없습니다';
      } else {
        title = '${DateFormat('MM월 dd일').format(_rangeStart!)}에 기록이 없습니다';
        subtitle = '다른 날짜를 선택하거나 전체보기를 눌러주세요';
      }
      icon = Icons.calendar_today_outlined;
    } else {
      title = '기록된 음식이 없습니다';
      subtitle = '대시보드에서 음식을 추가해보세요';
      icon = Icons.restaurant_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return RefreshIndicator(
      onRefresh: _loadRecords,
      color: const Color(0xFF4CAF50),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _allRecords.length,
        itemBuilder: (context, index) => _buildPhotoCard(_allRecords[index]),
      ),
    );
  }

  // 인라인 그리드 (스크롤 내부용)
  Widget _buildPhotoGridInline() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) => _buildPhotoCard(_filteredRecords[index]),
    );
  }

  // 인라인 리스트 (스크롤 내부용)
  Widget _buildListViewInline() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) => _buildListItem(_filteredRecords[index]),
    );
  }

  Widget _buildPhotoCard(FoodRecord record) {
    final dateStr = record.createdAt != null
        ? DateFormat('MM/dd').format(record.createdAt!)
        : '';
    final mealTime = record.createdAt != null ? _getMealTime(record.createdAt!) : '';
    // 백엔드 API에서 받은 점수/등급 사용
    final recordScore = record.score ?? 0.0;
    final recordGrade = record.grade ?? 'F';
    final gradeColor = _getGradeColor(recordGrade);

    return GestureDetector(
      onTap: () => _showRecordDetail(record),
      onLongPress: () => _showDeleteDialog(record),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 + 등급 배지
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _getImageUrl(record.imagePath) != null
                        ? Image.network(
                            _getImageUrl(record.imagePath)!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[200],
                              child: Center(child: Icon(Icons.restaurant, size: 40, color: Colors.grey[400])),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Center(child: Icon(Icons.restaurant, size: 40, color: Colors.grey[400])),
                          ),
                  ),
                ],
              ),
            ),
            // 정보
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.foodName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$dateStr $mealTime',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const Spacer(),
                      Text(
                        '${record.calories.toStringAsFixed(0)}kcal',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _loadRecords,
      color: const Color(0xFF4CAF50),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allRecords.length,
        itemBuilder: (context, index) => _buildListItem(_allRecords[index]),
      ),
    );
  }

  Widget _buildListItem(FoodRecord record) {
    final dateStr = record.createdAt != null ? DateFormat('MM/dd HH:mm').format(record.createdAt!) : '';
    // 백엔드 API에서 받은 점수/등급 사용
    final recordScore = record.score ?? 0.0;
    final recordGrade = record.grade ?? 'F';
    final gradeColor = _getGradeColor(recordGrade);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _getImageUrl(record.imagePath) != null
                  ? Image.network(
                      _getImageUrl(record.imagePath)!,
                      width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[200], child: Icon(Icons.restaurant, color: Colors.grey[400])),
                    )
                  : Container(width: 56, height: 56, color: Colors.grey[200], child: Icon(Icons.restaurant, color: Colors.grey[400])),
            ),
          ],
        ),
        title: Text(record.foodName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$dateStr  •  ${record.calories.toStringAsFixed(0)}kcal', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 20),
          onPressed: () => _showDeleteDialog(record),
        ),
        onTap: () => _showRecordDetail(record),
      ),
    );
  }

  void _showDeleteDialog(FoodRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제'),
        content: Text('${record.foodName}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (record.id != null) _deleteRecord(record.id!);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRecordDetail(FoodRecord record) {
    // 백엔드 API에서 받은 점수/등급 사용
    final recordScore = record.score ?? 0.0;
    final recordGrade = record.grade ?? 'F';
    final gradeColor = _getGradeColor(recordGrade);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지
                    if (_getImageUrl(record.imagePath) != null)
                      Image.network(
                        _getImageUrl(record.imagePath)!,
                        width: double.infinity, height: 250, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: double.infinity, height: 180, color: Colors.grey[200], child: Icon(Icons.restaurant, size: 60, color: Colors.grey[400])),
                      )
                    else
                      Container(width: double.infinity, height: 180, color: Colors.grey[200], child: Icon(Icons.restaurant, size: 60, color: Colors.grey[400])),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 이름
                          Text(record.foodName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (record.createdAt != null)
                            Text(DateFormat('yyyy년 MM월 dd일 HH:mm').format(record.createdAt!), style: TextStyle(color: Colors.grey[600])),

                          const SizedBox(height: 16),

                          // 점수
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: gradeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gradeColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('점수: ', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                                Text(
                                  recordScore.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: gradeColor),
                                ),
                                Text(' / 100', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 영양정보
                          _buildDetailNutrition('칼로리', '${record.calories.toStringAsFixed(0)} kcal', Colors.orange),
                          _buildDetailNutrition('단백질', '${record.protein.toStringAsFixed(1)} g', Colors.red),
                          _buildDetailNutrition('탄수화물', '${record.carbs.toStringAsFixed(1)} g', Colors.brown),
                          _buildDetailNutrition('지방', '${record.fat.toStringAsFixed(1)} g', Colors.amber[700]!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailNutrition(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
