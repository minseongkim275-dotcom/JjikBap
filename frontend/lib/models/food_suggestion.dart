class FoodSuggestion {
  final String foodName;
  final double matchScore;

  FoodSuggestion({
    required this.foodName,
    required this.matchScore,
  });

  factory FoodSuggestion.fromJson(Map<String, dynamic> json) {
    return FoodSuggestion(
      foodName: json['food_name'],
      matchScore: (json['match_score'] as num).toDouble(),
    );
  }
}

class SearchFoodResponse {
  final String query;
  final List<FoodSuggestion> suggestions;

  SearchFoodResponse({
    required this.query,
    required this.suggestions,
  });

  factory SearchFoodResponse.fromJson(Map<String, dynamic> json) {
    return SearchFoodResponse(
      query: json['query'],
      suggestions: (json['suggestions'] as List)
          .map((s) => FoodSuggestion.fromJson(s))
          .toList(),
    );
  }
}
