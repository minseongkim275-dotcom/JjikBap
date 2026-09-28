import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/food_record.dart';
import '../models/food_suggestion.dart';
import '../services/api_service.dart';
import '../services/exif_service.dart';

class AddFoodScreen extends StatefulWidget {
  final VoidCallback? onFoodSaved;

  const AddFoodScreen({super.key, this.onFoodSaved});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int? _userId;
  File? _selectedImage;
  NutritionInfo? _analyzedNutrition;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;
  bool _hasGpsData = false;
  int _rating = 3; // 기본 3점

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('userId');
    });
  }

  Future<void> _pickImage() async {
    try {
      // 먼저 원본 이미지를 선택하여 GPS 정보 추출
      final XFile? originalImage = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (originalImage != null) {
        // 원본 이미지에서 GPS 좌표 추출 (리사이즈 전)
        await _extractGpsCoordinates(originalImage.path);

        // 표시 및 분석용 이미지 설정
        setState(() {
          _selectedImage = File(originalImage.path);
        });

        // 이미지 분석
        await _analyzeImage();
      }
    } catch (e) {
      _showError('이미지 선택 실패: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      // 원본 사진 촬영 (GPS 정보 보존)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
      );

      if (photo != null) {
        // 원본 사진에서 GPS 좌표 추출 (리사이즈 전)
        await _extractGpsCoordinates(photo.path);

        // 표시 및 분석용 이미지 설정
        setState(() {
          _selectedImage = File(photo.path);
        });

        // 이미지 분석
        await _analyzeImage();
      }
    } catch (e) {
      _showError('사진 촬영 실패: $e');
    }
  }

  Future<void> _extractGpsCoordinates(String imagePath) async {
    try {
      final coords = await ExifService.extractGpsCoordinates(imagePath);

      setState(() {
        if (coords != null) {
          _latitude = coords['latitude'];
          _longitude = coords['longitude'];
          _hasGpsData = true;
          print('GPS 좌표 추출 성공: $_latitude, $_longitude');
        } else {
          _latitude = null;
          _longitude = null;
          _hasGpsData = false;
          print('GPS 정보가 없습니다');
        }
      });

      if (_hasGpsData) {
        _showSuccess('GPS 위치 정보가 감지되었습니다!');
      }
    } catch (e) {
      print('GPS 추출 오류: $e');
      setState(() {
        _latitude = null;
        _longitude = null;
        _hasGpsData = false;
        _rating = 3;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // 이미지를 Base64로 변환
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // API 호출
      final nutrition = await _apiService.analyzeImage(base64Image);

      setState(() => _isAnalyzing = false);

      // 신뢰도가 20% 미만이면 다시 찍기 요청
      if (nutrition.confidence < 0.2) {
        await _showLowConfidenceDialog(nutrition.confidence);
        return;
      }

      setState(() {
        _analyzedNutrition = nutrition;
        _textController.text = nutrition.foodName;
      });

      _showSuccess('이미지 분석 완료! (신뢰도: ${(nutrition.confidence * 100).toInt()}%)');
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('이미지 분석 실패: $e');
    }
  }

  Future<void> _showLowConfidenceDialog(double confidence) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            const Text('인식률이 낮습니다'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 인식 신뢰도: ${(confidence * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '음식을 정확하게 인식하지 못했습니다.\n다음 방법을 시도해 보세요:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildTipRow(Icons.wb_sunny_rounded, '밝은 곳에서 촬영'),
            _buildTipRow(Icons.center_focus_strong, '음식을 가까이에서 촬영'),
            _buildTipRow(Icons.blur_off, '흔들림 없이 선명하게 촬영'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('다시 촬영'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      // 다시 촬영
      setState(() {
        _selectedImage = null;
        _analyzedNutrition = null;
      });
      await _takePhoto();
    }
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Future<void> _analyzeText() async {
    if (_textController.text.trim().isEmpty) {
      _showError('음식명을 입력해주세요');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // 여러 음식 검색
      final searchResult = await _apiService.searchFood(_textController.text);

      setState(() => _isAnalyzing = false);

      if (searchResult.suggestions.isEmpty) {
        _showError('일치하는 음식을 찾을 수 없습니다');
        return;
      }

      // 여러 선택지 보여주기
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
                  backgroundColor: Colors.green,
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
      // 선택된 음식 분석
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

    setState(() => _isSaving = true);

    try {
      String? uploadedImageUrl;

      // 이미지가 있으면 먼저 서버에 업로드
      if (_selectedImage != null) {
        try {
          uploadedImageUrl = await _apiService.uploadImage(_selectedImage!, userId: _userId);
          print('[AddFood] 이미지 업로드 완료: $uploadedImageUrl');
        } catch (e) {
          print('[AddFood] 이미지 업로드 실패: $e');
          // 이미지 업로드 실패해도 기록은 저장 진행
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
        imagePath: uploadedImageUrl, // 업로드된 이미지 URL 저장
        latitude: _latitude,
        longitude: _longitude,
        rating: _rating,
      );

      await _apiService.createFoodRecord(record);

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
        print('[AddFood] user_food_history 저장 실패: $e');
      }

      setState(() {
        _isSaving = false;
        _analyzedNutrition = null;
        _selectedImage = null;
        _textController.clear();
        _latitude = null;
        _longitude = null;
        _hasGpsData = false;
        _rating = 3;
      });

      _showSuccess('기록이 저장되었습니다!');

      // 콜백 호출하여 홈 화면으로 이동하고 새로고침
      widget.onFoodSaved?.call();
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('저장 실패: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('음식 추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이미지 선택 버튼
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_rounded, size: 24),
                      label: const Text('갤러리'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 24),
                      label: const Text('사진 촬영'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 선택된 이미지 표시
            if (_selectedImage != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImage!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // GPS 정보 표시
              if (_hasGpsData) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '위치 정보 감지됨 - 맛집 지도에 표시됩니다',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // 텍스트 입력
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: '음식명',
                hintText: '예: 밥, 김치, 계란',
                prefixIcon: const Icon(Icons.restaurant_rounded),
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeText,
              icon: const Icon(Icons.search_rounded),
              label: const Text('텍스트로 분석'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            // 분석 중 표시
            if (_isAnalyzing) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '분석 중...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 분석 결과 표시
            if (_analyzedNutrition != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _analyzedNutrition!.foodName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildNutrientRow(
                        '칼로리',
                        '${_analyzedNutrition!.calories.toStringAsFixed(1)} kcal',
                        Icons.local_fire_department_rounded,
                        Colors.orange,
                      ),
                      _buildNutrientRow(
                        '단백질',
                        '${_analyzedNutrition!.protein.toStringAsFixed(1)} g',
                        Icons.fitness_center_rounded,
                        Colors.red,
                      ),
                      _buildNutrientRow(
                        '탄수화물',
                        '${_analyzedNutrition!.carbs.toStringAsFixed(1)} g',
                        Icons.rice_bowl_rounded,
                        Colors.brown,
                      ),
                      _buildNutrientRow(
                        '지방',
                        '${_analyzedNutrition!.fat.toStringAsFixed(1)} g',
                        Icons.opacity_rounded,
                        Colors.yellow.shade700,
                      ),
                      _buildNutrientRow(
                        '식이섬유',
                        '${_analyzedNutrition!.fiber.toStringAsFixed(1)} g',
                        Icons.grass_rounded,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              // 별점 평가
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '맛 평가',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rating = starValue;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  _rating >= starValue
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: _rating >= starValue
                                      ? Colors.amber
                                      : Colors.grey[400],
                                  size: 44,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _rating == 1
                              ? '별로예요'
                              : _rating == 2
                                  ? '그저 그래요'
                                  : _rating == 3
                                      ? '괜찮아요'
                                      : _rating == 4
                                          ? '맛있어요'
                                          : '최고예요!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveRecord,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 26),
                    label: Text(
                      _isSaving ? '저장 중...' : '기록 저장',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
