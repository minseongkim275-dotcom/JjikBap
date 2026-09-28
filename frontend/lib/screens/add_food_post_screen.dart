import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/food_record.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class AddFoodPostScreen extends StatefulWidget {
  final FoodRecord? record; // 수정할 기록 (null이면 새 게시글)

  const AddFoodPostScreen({super.key, this.record});

  @override
  State<AddFoodPostScreen> createState() => _AddFoodPostScreenState();
}

class _AddFoodPostScreenState extends State<AddFoodPostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();

  String? _imagePath;
  String? _localImagePath; // 로컬 표시용
  int? _rating;
  bool _isSubmitting = false;
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _titleController.text = widget.record!.foodName;
      _contentController.text = widget.record!.description ?? '';
      _imagePath = widget.record!.imagePath; // 서버 경로
      // 서버 경로가 아닌 로컬 경로면 _localImagePath로 설정
      if (_imagePath != null && !_imagePath!.startsWith('/uploads')) {
        _localImagePath = _imagePath;
        _imagePath = null;
      }
      _rating = widget.record!.rating;
      _caloriesController.text = widget.record!.calories.toString();
      _proteinController.text = widget.record!.protein.toString();
      _carbsController.text = widget.record!.carbs.toString();
      _fatController.text = widget.record!.fat.toString();
      _fiberController.text = widget.record!.fiber.toString();
    } else {
      _caloriesController.text = '0';
      _proteinController.text = '0';
      _carbsController.text = '0';
      _fatController.text = '0';
      _fiberController.text = '0';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _localImagePath = pickedFile.path;
        _imagePath = null; // 새 이미지 선택시 서버 경로 초기화
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _localImagePath = pickedFile.path;
        _imagePath = null; // 새 이미지 선택시 서버 경로 초기화
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_localImagePath != null || _imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('이미지 제거', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imagePath = null;
                    _localImagePath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 1;

      // 새 이미지가 있으면 서버에 업로드
      String? finalImagePath = _imagePath; // 기존 서버 경로 유지
      if (_localImagePath != null) {
        try {
          finalImagePath = await _apiService.uploadImage(
            File(_localImagePath!),
            userId: userId,
          );
          print('[AddFoodPost] 이미지 업로드 완료: $finalImagePath');
        } catch (e) {
          print('[AddFoodPost] 이미지 업로드 실패: $e');
          // 업로드 실패해도 계속 진행
        }
      }

      final record = FoodRecord(
        id: widget.record?.id,
        userId: userId,
        foodName: _titleController.text.trim(),
        description: _contentController.text.trim(),
        imagePath: finalImagePath,
        rating: _rating,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        fat: double.tryParse(_fatController.text) ?? 0,
        fiber: double.tryParse(_fiberController.text) ?? 0,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
      );

      if (widget.record == null) {
        // 새 게시글 생성
        await _dbService.insertFoodRecord(record);

        // user_food_history에도 저장
        try {
          await _apiService.addUserHistory(
            userId: userId,
            foodName: record.foodName,
            date: DateTime.now().toIso8601String().split('T')[0],
            calories: record.calories,
            protein: record.protein,
            carbs: record.carbs,
            fat: record.fat,
          );
        } catch (e) {
          print('[AddFoodPost] user_food_history 저장 실패: $e');
        }
      } else {
        // 게시글 수정
        await _dbService.updateFoodRecord(record);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.record == null
                ? '게시글이 작성되었습니다'
                : '게시글이 수정되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? '음식 게시글 작성' : '게시글 수정'),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitPost,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '음식 이름',
                hintText: '예: 김치찌개, 불고기, 샐러드',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // 이미지 섹션
            InkWell(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: (_localImagePath != null && File(_localImagePath!).existsSync())
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_localImagePath!),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.white),
                                onPressed: _showImageSourceDialog,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            '이미지 추가 (선택)',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 별점
            const Text(
              '별점',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < (_rating ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: index < (_rating ?? 0) ? Colors.amber : Colors.grey,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),

            // 내용 입력
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '음식에 대한 설명이나 후기를 작성하세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Icons.description),
                ),
              ),
              maxLines: 6,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // 영양 정보 (선택사항)
            const Text(
              '영양 정보 (선택)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caloriesController,
                    decoration: const InputDecoration(
                      labelText: '칼로리',
                      suffix: Text('kcal'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    decoration: const InputDecoration(
                      labelText: '단백질',
                      suffix: Text('g'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    decoration: const InputDecoration(
                      labelText: '탄수화물',
                      suffix: Text('g'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    decoration: const InputDecoration(
                      labelText: '지방',
                      suffix: Text('g'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fiberController,
                    decoration: const InputDecoration(
                      labelText: '섬유질',
                      suffix: Text('g'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 작성 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.record == null ? '게시글 작성' : '수정 완료',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    super.dispose();
  }
}
