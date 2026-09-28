import 'package:flutter_test/flutter_test.dart';

import 'package:jjikbap/models/food_record.dart';

void main() {
  group('FoodRecord.fromJson', () {
    test('백엔드 /api/records 응답을 파싱한다', () {
      final record = FoodRecord.fromJson({
        'id': 56,
        'user_id': 1,
        'food_name': '김치찌개',
        'calories': 120,
        'protein': 8.5,
        'carbs': 8.0,
        'fat': 6.0,
        'fiber': 0.0,
        'image_path': null,
        'description': '김치찌개',
        'created_at': '2026-09-28T16:53:10.723530',
        'latitude': null,
        'longitude': null,
        'rating': 3,
        'score': 79.0,
        'grade': 'B',
      });

      expect(record.id, 56);
      expect(record.foodName, '김치찌개');
      expect(record.calories, 120.0); // int로 와도 double로 변환
      expect(record.createdAt, DateTime.parse('2026-09-28T16:53:10.723530'));
      expect(record.imagePath, isNull);
      expect(record.grade, 'B');
    });

    test('영양 수치가 없으면 0으로 채운다', () {
      final record = FoodRecord.fromJson({'food_name': '물'});

      expect(record.calories, 0.0);
      expect(record.protein, 0.0);
      expect(record.createdAt, isNull);
    });
  });

  test('NutritionInfo.fromJson은 confidence 기본값 1.0을 쓴다', () {
    final info = NutritionInfo.fromJson({
      'food_name': '김밥',
      'calories': 250,
      'protein': 7.5,
      'carbs': 45,
      'fat': 5,
    });

    expect(info.foodName, '김밥');
    expect(info.carbs, 45.0);
    expect(info.confidence, 1.0);
  });
}
