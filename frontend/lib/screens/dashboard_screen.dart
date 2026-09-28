import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';
import '../models/food_record.dart';
import '../models/food_suggestion.dart';
import '../services/api_service.dart';
import '../services/exif_service.dart';
import '../services/database_service.dart';
import 'food_recommendation_screen.dart';
import 'login_screen.dart';
import '../widgets/ux_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _textController = TextEditingController();
  int? _userId;
  final ImagePicker _picker = ImagePicker();

  // 음식 추가 관련
  File? _selectedImage;
  NutritionInfo? _analyzedNutrition;
  bool _isAnalyzing = false;
  bool _isSaving = false;

  // 전체 식단 등급 관련 (백엔드 API)
  Map<String, dynamic>? _userScoreData;
  bool _isLoadingScore = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserId();
    await _loadUserScore();
  }

  // 백엔드에서 사용자 식단 점수/등급 로드
  Future<void> _loadUserScore() async {
    if (_userId == null) {
      print('[Dashboard] userId가 없어서 점수 로드 스킵');
      return;
    }
    setState(() => _isLoadingScore = true);
    try {
      final data = await _apiService.getUserScore(userId: _userId, days: 7);
      if (mounted) {
        setState(() {
          _userScoreData = data;
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

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (mounted) {
      setState(() {
        _userId = userId;
      });
    }
    print('[Dashboard] userId 로드 완료: $_userId');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  // 영양 등급 계산 (A-F)
  String _calculateNutritionGrade(NutritionInfo nutrition) {
    // 기준: 1끼 기준 권장량 (하루 권장량의 1/3)
    const targetCalories = 700.0;
    const targetProtein = 20.0;
    const targetCarbs = 90.0;
    const targetFat = 20.0;

    double score = 0;

    // 칼로리 점수 (적정 범위: 500-900)
    if (nutrition.calories >= 400 && nutrition.calories <= 900) {
      score += 25;
    } else if (nutrition.calories >= 300 && nutrition.calories <= 1000) {
      score += 15;
    }

    // 단백질 점수 (높을수록 좋음, 15g 이상)
    if (nutrition.protein >= 20) {
      score += 25;
    } else if (nutrition.protein >= 15) {
      score += 20;
    } else if (nutrition.protein >= 10) {
      score += 10;
    }

    // 탄수화물 점수 (적정 범위)
    if (nutrition.carbs >= 50 && nutrition.carbs <= 120) {
      score += 25;
    } else if (nutrition.carbs >= 30 && nutrition.carbs <= 150) {
      score += 15;
    }

    // 지방 점수 (적정 범위: 10-30g)
    if (nutrition.fat >= 10 && nutrition.fat <= 25) {
      score += 25;
    } else if (nutrition.fat >= 5 && nutrition.fat <= 35) {
      score += 15;
    } else if (nutrition.fat > 40) {
      score += 0; // 고지방
    }

    // 등급 산정
    if (score >= 90) return 'A';
    if (score >= 75) return 'B';
    if (score >= 55) return 'C';
    if (score >= 35) return 'D';
    return 'F';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getGradeDescription(String grade) {
    switch (grade) {
      case 'A':
        return '훌륭해요! 균형 잡힌 식사입니다';
      case 'B':
        return '좋아요! 건강한 식사입니다';
      case 'C':
        return '괜찮아요, 조금만 개선해보세요';
      case 'D':
        return '영양 균형이 부족해요';
      case 'F':
        return '영양 균형 개선이 필요해요';
      default:
        return '';
    }
  }

  // 음식 추가 메서드들
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        await _analyzeImage();
      }
    } catch (e) {
      _showError('이미지 선택 실패: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        await _analyzeImage();
      }
    } catch (e) {
      _showError('사진 촬영 실패: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final nutrition = await _apiService.analyzeImage(base64Image);

      setState(() {
        _analyzedNutrition = nutrition;
        _textController.text = nutrition.foodName;
        _isAnalyzing = false;
      });

      _showSuccess('이미지 분석 완료!');
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('이미지 분석 실패: $e');
    }
  }

  Future<void> _analyzeText() async {
    if (_textController.text.trim().isEmpty) {
      _showError('음식명을 입력해주세요');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final searchResult = await _apiService.searchFood(_textController.text);

      setState(() => _isAnalyzing = false);

      if (searchResult.suggestions.isEmpty) {
        _showError('일치하는 음식을 찾을 수 없습니다');
        return;
      }

      if (!mounted) return;
      await _showFoodSelectionDialog(searchResult.suggestions);

    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('검색 실패: $e');
    }
  }

  Future<void> _showFoodSelectionDialog(List<FoodSuggestion> suggestions) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음식을 선택하세요'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final matchPercent = (suggestion.matchScore * 100).toInt();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text('$matchPercent%', style: const TextStyle(fontSize: 12, color: Colors.white)),
                ),
                title: Text(
                  suggestion.foodName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(context, suggestion.foodName),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _analyzeFoodByName(selected);
    }
  }

  Future<void> _analyzeFoodByName(String foodName) async {
    setState(() => _isAnalyzing = true);

    try {
      final nutrition = await _apiService.analyzeText(foodName);

      setState(() {
        _analyzedNutrition = nutrition;
        _isAnalyzing = false;
      });

      _showSuccess('분석 완료!');
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('분석 실패: $e');
    }
  }

  Future<void> _saveRecord() async {
    if (_analyzedNutrition == null) {
      _showError('먼저 음식을 분석해주세요');
      return;
    }

    final rating = await _showRatingDialog();
    if (rating == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? savedImagePath;
      double? latitude;
      double? longitude;

      if (_selectedImage != null) {
        // GPS 정보 추출
        final gpsData = await ExifService.extractGpsCoordinates(_selectedImage!.path);
        if (gpsData != null) {
          latitude = gpsData['latitude'];
          longitude = gpsData['longitude'];
        }

        // 서버에 이미지 업로드
        try {
          savedImagePath = await _apiService.uploadImage(_selectedImage!, userId: _userId);
          print('[Dashboard] 이미지 업로드 완료: $savedImagePath');
        } catch (e) {
          print('[Dashboard] 이미지 업로드 실패: $e');
          // 업로드 실패해도 기록은 저장 진행
        }
      }

      final record = FoodRecord(
        userId: _userId,
        foodName: _analyzedNutrition!.foodName,
        calories: _analyzedNutrition!.calories,
        protein: _analyzedNutrition!.protein,
        carbs: _analyzedNutrition!.carbs,
        fat: _analyzedNutrition!.fat,
        fiber: _analyzedNutrition!.fiber,
        description: _textController.text,
        imagePath: savedImagePath,
        latitude: latitude,
        longitude: longitude,
        rating: rating,
        createdAt: DateTime.now(),
      );

      await _dbService.insertFoodRecord(record);

      // user_food_history에도 저장
      try {
        await _apiService.addUserHistory(
          userId: _userId ?? 1,
          foodName: record.foodName,
          date: DateTime.now().toIso8601String().split('T')[0],
          calories: record.calories,
          protein: record.protein,
          carbs: record.carbs,
          fat: record.fat,
        );
      } catch (e) {
        print('[Dashboard] user_food_history 저장 실패: $e');
      }

      setState(() {
        _isSaving = false;
        _analyzedNutrition = null;
        _selectedImage = null;
        _textController.clear();
      });

      // 저장 후 식단 점수 새로고침
      _loadUserScore();

      _showSuccess('기록이 저장되었습니다!');
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('저장 실패: $e');
    }
  }

  Future<int?> _showRatingDialog() async {
    int selectedRating = 3;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('음식 평가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('이 음식은 어떠셨나요?'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    iconSize: 40,
                    onPressed: () {
                      setState(() {
                        selectedRating = starValue;
                      });
                    },
                    icon: Icon(
                      starValue <= selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: starValue <= selectedRating
                          ? Colors.amber
                          : Colors.grey[400],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _getRatingText(selectedRating),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedRating),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '별로예요';
      case 2:
        return '그저 그래요';
      case 3:
        return '보통이에요';
      case 4:
        return '맛있어요';
      case 5:
        return '최고예요!';
      default:
        return '';
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      showSuccessDialog(context, message);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              '찍밥',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: _showLogoutDialog,
                icon: Icon(Icons.logout_rounded, color: Colors.grey[600]),
                tooltip: '로그아웃',
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 0.5,
                color: Colors.black26,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildRecommendationSection(),
                const SizedBox(height: 20),
                _buildAddFoodSection(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecommendationTap() async {
    final prefs = await SharedPreferences.getInstance();
    final skipPriceDialog = prefs.getBool('skipPriceDialog') ?? false;
    final savedMinPrice = prefs.getInt('recommendMinPrice') ?? 5000;
    final savedMaxPrice = prefs.getInt('recommendMaxPrice') ?? 15000;

    if (skipPriceDialog) {
      // 다이얼로그 스킵, 바로 추천 화면으로 이동
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodRecommendationScreen(
              minPrice: savedMinPrice,
              maxPrice: savedMaxPrice,
            ),
          ),
        );
      }
    } else {
      // 가격대 설정 다이얼로그 표시
      await _showPriceRangeDialog();
    }
  }

  Future<void> _showPriceRangeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    int minPrice = prefs.getInt('recommendMinPrice') ?? 5000;
    int maxPrice = prefs.getInt('recommendMaxPrice') ?? 15000;
    bool dontShowAgain = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '추천 가격대 설정',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '원하시는 가격대를 선택해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              // 최소 가격
              Text(
                '최소 가격',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: minPrice,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [0, 3000, 5000, 7000, 10000, 15000, 20000]
                      .map((price) => DropdownMenuItem(
                            value: price,
                            child: Text(
                              price == 0 ? '제한 없음' : '${_formatPrice(price)}원',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      minPrice = value!;
                      if (maxPrice < minPrice && maxPrice != 0) {
                        maxPrice = minPrice;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 최대 가격
              Text(
                '최대 가격',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: maxPrice,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [0, 5000, 7000, 10000, 15000, 20000, 30000, 50000]
                      .where((price) => price == 0 || price >= minPrice)
                      .map((price) => DropdownMenuItem(
                            value: price,
                            child: Text(
                              price == 0 ? '제한 없음' : '${_formatPrice(price)}원',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      maxPrice = value!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              // 선택된 가격대 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      minPrice == 0 && maxPrice == 0
                          ? '모든 가격대'
                          : minPrice == 0
                              ? '${_formatPrice(maxPrice)}원 이하'
                              : maxPrice == 0
                                  ? '${_formatPrice(minPrice)}원 이상'
                                  : '${_formatPrice(minPrice)}원 ~ ${_formatPrice(maxPrice)}원',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 다시는 보지않기 체크박스
              GestureDetector(
                onTap: () {
                  setState(() {
                    dontShowAgain = !dontShowAgain;
                  });
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: dontShowAgain,
                        onChanged: (value) {
                          setState(() {
                            dontShowAgain = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '다시는 보지 않기',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (dontShowAgain) ...[
                const SizedBox(height: 8),
                Text(
                  '마이페이지 > 추천 가격대 설정에서 변경할 수 있어요',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'minPrice': minPrice,
                  'maxPrice': maxPrice,
                  'dontShowAgain': dontShowAgain,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('추천받기'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // 설정 저장
      await prefs.setInt('recommendMinPrice', result['minPrice']);
      await prefs.setInt('recommendMaxPrice', result['maxPrice']);
      if (result['dontShowAgain']) {
        await prefs.setBool('skipPriceDialog', true);
      }

      // 추천 화면으로 이동
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodRecommendationScreen(
              minPrice: result['minPrice'],
              maxPrice: result['maxPrice'],
            ),
          ),
        );
      }
    }
  }

  String _formatPrice(int price) {
    if (price >= 10000) {
      final man = price ~/ 10000;
      final rest = price % 10000;
      if (rest == 0) {
        return '$man만';
      }
      return '$man만${rest ~/ 1000}천';
    }
    return '${price ~/ 1000}천';
  }

  // 전체 식단 등급 섹션 (백엔드 API 기반)
  Widget _buildUserScoreSection() {
    if (_isLoadingScore) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userScoreData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text('식단 점수를 불러올 수 없습니다'),
        ),
      );
    }

    final score = (_userScoreData!['score'] as num?)?.toDouble() ?? 50.0;
    final grade = _userScoreData!['grade'] as String? ?? 'C';
    final details = _userScoreData!['details'] as Map<String, dynamic>? ?? {};
    final feedback = (_userScoreData!['feedback'] as List<dynamic>?)?.cast<String>() ?? [];
    final stats = _userScoreData!['stats'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _getGradeColor(grade).withOpacity(0.1),
            _getGradeColor(grade).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _getGradeColor(grade).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: _getGradeColor(grade),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                '나의 식단 등급',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // 새로고침 버튼
              IconButton(
                onPressed: _loadUserScore,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.grey[600],
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 등급과 점수
          Row(
            children: [
              // 등급 배지
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _getGradeColor(grade),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getGradeColor(grade).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    grade,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // 점수와 세부 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${score.toStringAsFixed(1)}점',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(grade),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '최근 7일 기준',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 세부 점수
          if (details.isNotEmpty) ...[
            Row(
              children: [
                _buildScoreChip('음식', details['food_score']?.toDouble() ?? 0),
                const SizedBox(width: 8),
                _buildScoreChip('영양', details['nutrition_score']?.toDouble() ?? 0),
                const SizedBox(width: 8),
                _buildScoreChip('습관', details['habit_score']?.toDouble() ?? 0),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 피드백
          if (feedback.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feedback.first,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 총 식사 횟수
          if (stats['total_meals'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '총 ${stats['total_meals']}끼 기록',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreChip(String label, double score) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              score.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection() {
    return GestureDetector(
      onTap: _handleRecommendationTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 배경 장식
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // 컨텐츠
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF43A047),
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AI 추천',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '나에게 맞는\n음식 추천받기',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '식습관을 분석하고 맞춤 메뉴를 추천해요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildMiniChip('🍽️ 균형잡힌 식단'),
                      const SizedBox(width: 8),
                      _buildMiniChip('📊 영양 분석'),
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

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showFoodInputOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '음식 입력 방법 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF4CAF50),
              title: '사진 촬영',
              subtitle: '음식을 촬영해서 분석해요',
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF2196F3),
              title: '갤러리에서 선택',
              subtitle: '저장된 음식 사진을 선택해요',
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.edit_rounded,
              color: const Color(0xFFFF9800),
              title: '텍스트로 입력',
              subtitle: '음식 이름을 직접 입력해요',
              onTap: () {
                Navigator.pop(context);
                _showTextInputDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showTextInputDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '음식 이름 입력',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '오늘 먹은 음식을 자유롭게 적어주세요',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: 4,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '예: 아침에 김치찌개랑 밥 먹었고\n점심은 비빔밥 먹었어요',
                  hintStyle: TextStyle(color: Colors.grey[400], height: 1.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _analyzeText();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '분석하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddFoodSection() {
    // 분석 결과가 있으면 결과 카드 표시
    if (_analyzedNutrition != null || _isAnalyzing || _selectedImage != null) {
      return _buildAnalysisCard();
    }

    // 기본: 멘트 + 버튼들 분리
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 멘트
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘 뭐 드셨나요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '식사를 기록하고 영양 점수를 받아보세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 사진으로 기록하기 버튼
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '사진으로 기록하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 텍스트로 기록하기 버튼
        GestureDetector(
          onTap: _showTextInputDialog,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '텍스트로 기록하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 유의사항
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AI 분석 결과는 참고용이며, 실제 영양 정보와 다를 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '사진 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF4CAF50),
              title: '사진 촬영',
              subtitle: '음식을 촬영해서 분석해요',
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF2196F3),
              title: '갤러리에서 선택',
              subtitle: '저장된 음식 사진을 선택해요',
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              const Text(
                '음식 분석',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImage = null;
                    _analyzedNutrition = null;
                    _textController.clear();
                  });
                },
                child: Icon(Icons.close_rounded, color: Colors.grey[400]),
              ),
            ],
          ),

          // 선택된 이미지 표시
          if (_selectedImage != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          // 분석 중 표시
          if (_isAnalyzing) ...[
            const SizedBox(height: 20),
            const AnalyzingShimmer(),
          ],

          // 분석 결과 표시
          if (_analyzedNutrition != null) ...[
            const SizedBox(height: 16),
            _buildAnalysisResult(),
            const SizedBox(height: 16),
            PrimaryCTAButton(
              label: '기록 저장',
              icon: Icons.check_circle_rounded,
              onPressed: _isSaving ? null : _saveRecord,
              isLoading: _isSaving,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    final grade = _calculateNutritionGrade(_analyzedNutrition!);
    final gradeColor = _getGradeColor(grade);
    final gradeDesc = _getGradeDescription(grade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 음식명과 등급
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _analyzedNutrition!.foodName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gradeDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // 등급 배지
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: gradeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradeColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    grade,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // 영양 정보
          _buildNutrientChip(
            '${_analyzedNutrition!.calories.toStringAsFixed(0)} kcal',
            Icons.local_fire_department_rounded,
            Colors.orange,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNutrientChip(
                  '단백질 ${_analyzedNutrition!.protein.toStringAsFixed(1)}g',
                  Icons.fitness_center_rounded,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNutrientChip(
                  '탄수화물 ${_analyzedNutrition!.carbs.toStringAsFixed(1)}g',
                  Icons.rice_bowl_rounded,
                  Colors.brown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNutrientChip(
                  '지방 ${_analyzedNutrition!.fat.toStringAsFixed(1)}g',
                  Icons.opacity_rounded,
                  Colors.yellow.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNutrientChip(
                  '식이섬유 ${_analyzedNutrition!.fiber.toStringAsFixed(1)}g',
                  Icons.grass_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
