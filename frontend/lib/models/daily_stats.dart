class DailyStats {
  final DateTime date;
  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final double consumedFiber;
  final double goalCalories;
  final double goalProtein;
  final double goalCarbs;
  final double goalFat;
  final double goalFiber;
  final double caloriesPercentage;
  final double proteinPercentage;
  final double carbsPercentage;
  final double fatPercentage;
  final double fiberPercentage;

  DailyStats({
    required this.date,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.consumedFiber,
    required this.goalCalories,
    required this.goalProtein,
    required this.goalCarbs,
    required this.goalFat,
    required this.goalFiber,
    required this.caloriesPercentage,
    required this.proteinPercentage,
    required this.carbsPercentage,
    required this.fatPercentage,
    required this.fiberPercentage,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date']),
      consumedCalories: (json['consumed_calories'] as num).toDouble(),
      consumedProtein: (json['consumed_protein'] as num).toDouble(),
      consumedCarbs: (json['consumed_carbs'] as num).toDouble(),
      consumedFat: (json['consumed_fat'] as num).toDouble(),
      consumedFiber: (json['consumed_fiber'] as num).toDouble(),
      goalCalories: (json['goal_calories'] as num).toDouble(),
      goalProtein: (json['goal_protein'] as num).toDouble(),
      goalCarbs: (json['goal_carbs'] as num).toDouble(),
      goalFat: (json['goal_fat'] as num).toDouble(),
      goalFiber: (json['goal_fiber'] as num).toDouble(),
      caloriesPercentage: (json['calories_percentage'] as num).toDouble(),
      proteinPercentage: (json['protein_percentage'] as num).toDouble(),
      carbsPercentage: (json['carbs_percentage'] as num).toDouble(),
      fatPercentage: (json['fat_percentage'] as num).toDouble(),
      fiberPercentage: (json['fiber_percentage'] as num).toDouble(),
    );
  }
}

class NutritionGoal {
  final int id;
  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final DateTime? targetDate;

  NutritionGoal({
    required this.id,
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.targetDate,
  });

  factory NutritionGoal.fromJson(Map<String, dynamic> json) {
    return NutritionGoal(
      id: json['id'],
      date: DateTime.parse(json['date']),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fiber: (json['fiber'] as num).toDouble(),
      targetDate: json['target_date'] != null ? DateTime.parse(json['target_date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'target_date': targetDate?.toIso8601String().split('T')[0],
    };
  }
}
