import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PriceSettingsScreen extends StatefulWidget {
  const PriceSettingsScreen({super.key});

  @override
  State<PriceSettingsScreen> createState() => _PriceSettingsScreenState();
}

class _PriceSettingsScreenState extends State<PriceSettingsScreen> {
  final ApiService _apiService = ApiService();
  int? _userId;

  int _minPrice = 5000;
  int _maxPrice = 15000;
  bool _skipPriceDialog = false;

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
      _minPrice = prefs.getInt('recommendMinPrice') ?? 5000;
      _maxPrice = prefs.getInt('recommendMaxPrice') ?? 15000;
      _skipPriceDialog = prefs.getBool('skipPriceDialog') ?? false;
    });

    // 서버에서도 로드 시도
    if (_userId != null) {
      try {
        final settings = await _apiService.getUserSettings(_userId!);
        setState(() {
          _minPrice = settings['recommend_min_price'] ?? 5000;
          _maxPrice = settings['recommend_max_price'] ?? 15000;
          _skipPriceDialog = settings['skip_price_dialog'] ?? false;
        });
      } catch (e) {
        print('[PriceSettings] 서버 설정 로드 실패: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('recommendMinPrice', _minPrice);
    await prefs.setInt('recommendMaxPrice', _maxPrice);
    await prefs.setBool('skipPriceDialog', _skipPriceDialog);

    // 서버에도 저장
    if (_userId != null) {
      try {
        await _apiService.saveUserSettings(
          userId: _userId!,
          recommendMinPrice: _minPrice,
          recommendMaxPrice: _maxPrice,
          skipPriceDialog: _skipPriceDialog,
        );
        print('[PriceSettings] 서버 설정 저장 완료');
      } catch (e) {
        print('[PriceSettings] 서버 설정 저장 실패: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 저장되었습니다'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
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

  String _getPriceRangeText() {
    if (_minPrice == 0 && _maxPrice == 0) {
      return '모든 가격대';
    } else if (_minPrice == 0) {
      return '${_formatPrice(_maxPrice)}원 이하';
    } else if (_maxPrice == 0) {
      return '${_formatPrice(_minPrice)}원 이상';
    } else {
      return '${_formatPrice(_minPrice)}원 ~ ${_formatPrice(_maxPrice)}원';
    }
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
          '추천 가격대 설정',
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

            // 현재 설정된 가격대
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '현재 설정된 가격대',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getPriceRangeText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 가격대 설정 섹션
            _buildSectionHeader('가격대 설정'),
            _buildSettingsCard([
              // 최소 가격
              _buildPriceSelector(
                label: '최소 가격',
                value: _minPrice,
                options: [0, 3000, 5000, 7000, 10000, 15000, 20000],
                onChanged: (value) {
                  setState(() {
                    _minPrice = value;
                    if (_maxPrice != 0 && _maxPrice < _minPrice) {
                      _maxPrice = _minPrice;
                    }
                  });
                },
              ),
              _buildDivider(),
              // 최대 가격
              _buildPriceSelector(
                label: '최대 가격',
                value: _maxPrice,
                options: [0, 5000, 7000, 10000, 15000, 20000, 30000, 50000]
                    .where((price) => price == 0 || price >= _minPrice)
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _maxPrice = value;
                  });
                },
              ),
            ]),

            const SizedBox(height: 24),

            // 다이얼로그 표시 설정
            _buildSectionHeader('추천받기 설정'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.visibility_off_rounded,
                iconColor: Colors.blue,
                title: '가격대 선택 다이얼로그 숨기기',
                subtitle: _skipPriceDialog
                    ? '추천받기 시 바로 추천 화면으로 이동'
                    : '추천받기 시 가격대 선택 다이얼로그 표시',
                value: _skipPriceDialog,
                onChanged: (value) {
                  setState(() {
                    _skipPriceDialog = value;
                  });
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
                      '설정한 가격대에 맞는 음식을 우선적으로 추천해드립니다. 가격 정보가 없는 음식도 함께 추천될 수 있습니다.',
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

  Widget _buildPriceSelector({
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.attach_money_rounded,
              color: Color(0xFF4CAF50),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<int>(
              value: value,
              underline: const SizedBox(),
              items: options
                  .map((price) => DropdownMenuItem(
                        value: price,
                        child: Text(
                          price == 0 ? '제한 없음' : '${_formatPrice(price)}원',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ))
                  .toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
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

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey[100]),
    );
  }
}
