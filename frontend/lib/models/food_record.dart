class FoodRecord {
  final int? id;
  final int? userId;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String? imagePath;
  final String? description;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;
  final int? rating; // 1-5 별점
  final double? score; // 백엔드 계산 점수
  final String? grade; // 백엔드 계산 등급

  FoodRecord({
    this.id,
    this.userId,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.imagePath,
    this.description,
    this.createdAt,
    this.latitude,
    this.longitude,
    this.rating,
    this.score,
    this.grade,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      id: json['id'],
      userId: json['user_id'],
      foodName: json['food_name'],
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      imagePath: json['image_path'],
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      rating: json['rating'],
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      grade: json['grade'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'image_path': imagePath,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'foodName': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'imagePath': imagePath,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
    };
  }

  factory FoodRecord.fromMap(Map<String, dynamic> map) {
    return FoodRecord(
      id: map['id'],
      userId: map['userId'],
      foodName: map['foodName'],
      calories: map['calories'],
      protein: map['protein'],
      carbs: map['carbs'],
      fat: map['fat'],
      fiber: map['fiber'],
      imagePath: map['imagePath'],
      description: map['description'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      latitude: map['latitude'],
      longitude: map['longitude'],
      rating: map['rating'],
    );
  }
}

class NutritionInfo {
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double confidence;  // 인식 신뢰도 (0.0 ~ 1.0)

  NutritionInfo({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.confidence = 1.0,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      foodName: json['food_name'],
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }
}
