import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../config/api_config.dart';
import '../services/api_service.dart';

class FoodRecommendationScreen extends StatefulWidget {
  final int? minPrice;
  final int? maxPrice;

  const FoodRecommendationScreen({
    super.key,
    this.minPrice,
    this.maxPrice,
  });

  @override
  State<FoodRecommendationScreen> createState() => _FoodRecommendationScreenState();
}

class _FoodRecommendationScreenState extends State<FoodRecommendationScreen> {
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  bool _showMore = false; // 더보기 상태
  Set<String> _excludedFoods = {}; // 제외된 음식 목록
  final ApiService _apiService = ApiService();
  int? _userId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');
    await _loadExcludedFoods();
    await _loadRecommendations();
  }

  Future<void> _loadExcludedFoods() async {
    if (_userId == null) return;
    try {
      final excluded = await _apiService.getExcludedFoods(_userId!);
      setState(() {
        _excludedFoods = excluded.toSet();
      });
    } catch (e) {
      print('제외 음식 로드 오류: $e');
    }
  }

  Future<void> _addExcludedFood(String foodName) async {
    if (_userId == null) return;
    try {
      await _apiService.addExcludedFood(_userId!, foodName);
      setState(() {
        _excludedFoods.add(foodName);
      });
    } catch (e) {
      print('제외 음식 추가 오류: $e');
    }
  }

  Future<void> _removeExcludedFood(String foodName) async {
    if (_userId == null) return;
    try {
      await _apiService.removeExcludedFood(_userId!, foodName);
      setState(() {
        _excludedFoods.remove(foodName);
      });
    } catch (e) {
      print('제외 음식 삭제 오류: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      String url = '${ApiConfig.baseUrl}/recommendations';
      List<String> queryParams = [];

      if (userId != null) {
        queryParams.add('user_id=$userId');
      }
      if (widget.minPrice != null && widget.minPrice! > 0) {
        queryParams.add('min_price=${widget.minPrice}');
      }
      if (widget.maxPrice != null && widget.maxPrice! > 0) {
        queryParams.add('max_price=${widget.maxPrice}');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        var recommendations = List<Map<String, dynamic>>.from(data['recommendations'] ?? []);

        // 제외된 음식 필터링
        recommendations = recommendations.where((rec) {
          final foodName = rec['food_name'] ?? '';
          return !_excludedFoods.contains(foodName);
        }).toList();

        recommendations.shuffle(Random());
        setState(() {
          _recommendations = recommendations;
        });
      }
    } catch (e) {
      print('추천 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getPriceRangeText() {
    final min = widget.minPrice ?? 0;
    final max = widget.maxPrice ?? 0;

    if (min == 0 && max == 0) {
      return '모든 가격대';
    } else if (min == 0) {
      return '${_formatPrice(max)}원 이하';
    } else if (max == 0) {
      return '${_formatPrice(min)}원 이상';
    } else {
      return '${_formatPrice(min)}원 ~ ${_formatPrice(max)}원';
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

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '고단백':
        return Colors.red;
      case '저칼로리':
        return Colors.green;
      case '저탄수':
        return Colors.orange;
      case '한식':
        return Colors.blue;
      case '균형식':
        return Colors.purple;
      case '찌개':
        return Colors.deepOrange;
      case '구이':
        return Colors.brown;
      case '볶음':
        return Colors.amber;
      case '국':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getImageUrl(Map<String, dynamic> rec) {
    final imageUrl = rec['image_url'] ?? rec['image'] ?? '';
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  // 음식 피드백 다이얼로그 표시
  void _showFeedbackDialog(Map<String, dynamic> rec) {
    final foodName = rec['food_name'] ?? '';
    int tempRating = 3;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 음식명
              Text(
                foodName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // 별점 평가
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '이 음식이 맘에 드시나요?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempRating = starValue;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              tempRating >= starValue
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: tempRating >= starValue
                                  ? Colors.amber
                                  : Colors.grey[400],
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        tempRating == 1
                            ? '별로예요'
                            : tempRating == 2
                                ? '그저 그래요'
                                : tempRating == 3
                                    ? '괜찮아요'
                                    : tempRating == 4
                                        ? '좋아요'
                                        : '최고예요!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 제외하기 버튼
              InkWell(
                onTap: () async {
                  await _addExcludedFood(foodName);
                  setState(() {
                    _recommendations.removeWhere((r) => r['food_name'] == foodName);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$foodName이(가) 추천에서 제외됩니다'),
                      backgroundColor: Colors.orange,
                      action: SnackBarAction(
                        label: '취소',
                        textColor: Colors.white,
                        onPressed: () async {
                          await _removeExcludedFood(foodName);
                          _loadRecommendations();
                        },
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: Colors.red[400], size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '이 음식 추천 받지 않기',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '앞으로 이 음식은 추천에서 제외됩니다',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.red[300]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$foodName에 $tempRating점 평가 완료!'),
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '맞춤 추천',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: Colors.black26,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 헤더 멘트
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '오늘의 추천 메뉴',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '회원님의 식습관에 맞는 음식을 추천해드려요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.minPrice != null || widget.maxPrice != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.payments_rounded,
                                size: 14,
                                color: Color(0xFF4CAF50),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getPriceRangeText(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 추천 리스트
                if (_recommendations.isEmpty)
                  _buildEmptyState()
                else
                  _buildRankedRecommendations(),

                const SizedBox(height: 20),

                // 새로고침 버튼
                if (_recommendations.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loadRecommendations,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('다른 추천 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                          '추천 결과는 기록된 식습관을 기반으로 하며, 참고용으로 활용해주세요.',
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
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '추천할 음식이 없어요',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            '음식을 더 기록하면 맞춤 추천을 받을 수 있어요',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedRecommendations() {
    return Column(
      children: [
        // 1등 - 크게 표시
        if (_recommendations.isNotEmpty)
          GestureDetector(
            onTap: () => _showFeedbackDialog(_recommendations[0]),
            child: _buildFirstPlaceCard(_recommendations[0]),
          ),

        const SizedBox(height: 16),

        // 2등, 3등 - 가로로 작게 표시
        if (_recommendations.length >= 2)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFeedbackDialog(_recommendations[1]),
                  child: _buildSmallCard(_recommendations[1], 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _recommendations.length >= 3
                    ? GestureDetector(
                        onTap: () => _showFeedbackDialog(_recommendations[2]),
                        child: _buildSmallCard(_recommendations[2], 3),
                      )
                    : const SizedBox(),
              ),
            ],
          ),

        // 더보기 버튼 및 4~10등 텍스트 리스트
        if (_recommendations.length > 3) ...[
          const SizedBox(height: 16),
          if (!_showMore)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showMore = true;
                });
              },
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('더보기 (${_recommendations.length > 10 ? 7 : _recommendations.length - 3}개)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            )
          else ...[
            // 4등부터 10등까지 텍스트로 표시
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (int i = 3; i < (_recommendations.length > 10 ? 10 : _recommendations.length); i++)
                    _buildTextRankItem(_recommendations[i], i + 1),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showMore = false;
                });
              },
              icon: const Icon(Icons.expand_less_rounded),
              label: const Text('접기'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTextRankItem(Map<String, dynamic> rec, int rank) {
    final foodName = rec['food_name'] ?? '';
    final category = rec['category'] ?? '';
    final color = _getCategoryColor(category);

    return InkWell(
      onTap: () => _showFeedbackDialog(rec),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 순위
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 음식명
            Expanded(
              child: Text(
                foodName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // 카테고리
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstPlaceCard(Map<String, dynamic> rec) {
    final color = _getCategoryColor(rec['category']);
    final category = rec['category'] ?? '';
    final foodName = rec['food_name'] ?? '';
    final reason = rec['reason'] ?? '';
    final imageUrl = _getImageUrl(rec);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[100],
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                    ),
            ),
          ),
          // 정보 영역
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 1등 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '1위',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  foodName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(Map<String, dynamic> rec, int rank) {
    final color = _getCategoryColor(rec['category']);
    final category = rec['category'] ?? '';
    final foodName = rec['food_name'] ?? '';
    final imageUrl = _getImageUrl(rec);

    final rankColor = rank == 2
        ? const Color(0xFFC0C0C0) // 은색
        : const Color(0xFFCD7F32); // 동색

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Container(
              height: 100,
              width: double.infinity,
              color: Colors.grey[100],
              child: Stack(
                children: [
                  if (imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.restaurant_rounded,
                              size: 36,
                              color: Colors.grey[300],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 36,
                        color: Colors.grey[300],
                      ),
                    ),
                  // 순위 뱃지
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rankColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$rank위',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 정보 영역
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  foodName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
