import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/food_record.dart';
import '../models/daily_stats.dart';
import '../models/food_suggestion.dart';
import '../config/api_config.dart';

class ApiService {
  // API Base URL (환경에 따라 자동으로 설정)
  // 디버그 모드: localhost 또는 에뮬레이터 주소 사용
  // 릴리즈 모드(APK): 로컬 네트워크 IP 사용
  static String get baseUrl => ApiConfig.baseUrl;

  // HTTP 클라이언트 설정 (타임아웃 추가)
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 15);

  // 음식 검색 (여러 제안 반환)
  Future<SearchFoodResponse> searchFood(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search-food?query=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        return SearchFoodResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('음식 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('검색 중 오류 발생: $e');
    }
  }

  // 텍스트로 음식 분석
  Future<NutritionInfo> analyzeText(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return NutritionInfo.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('음식 분석 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('분석 중 오류 발생: $e');
    }
  }

  // 이미지로 음식 분석
  Future<NutritionInfo> analyzeImage(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      );

      if (response.statusCode == 200) {
        return NutritionInfo.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('이미지 분석 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('분석 중 오류 발생: $e');
    }
  }

  // 음식 기록 생성
  Future<FoodRecord> createFoodRecord(FoodRecord record) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/records'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(record.toJson()),
      );

      if (response.statusCode == 200) {
        return FoodRecord.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('기록 생성 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('기록 생성 중 오류 발생: $e');
    }
  }

  // 음식 기록 목록 조회 (사용자별 필터링)
  Future<List<FoodRecord>> getFoodRecords({int? userId}) async {
    try {
      String url = '$baseUrl/records';
      if (userId != null) {
        url += '?user_id=$userId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => FoodRecord.fromJson(json)).toList();
      } else {
        throw Exception('기록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('기록 조회 중 오류 발생: $e');
    }
  }

  // 음식 기록 삭제
  Future<void> deleteFoodRecord(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/records/$id'),
      );

      if (response.statusCode != 200) {
        throw Exception('기록 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('기록 삭제 중 오류 발생: $e');
    }
  }

  // 영양 통계 조회
  Future<Map<String, dynamic>> getNutritionSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/records/stats/summary'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('통계 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('통계 조회 중 오류 발생: $e');
    }
  }

  // 하루별 영양 통계 조회
  Future<DailyStats> getDailyStats({String? targetDate}) async {
    try {
      String url = '$baseUrl/stats/daily';
      if (targetDate != null) {
        url += '?target_date=$targetDate';
      }

      print('[API] 통계 요청 시작: $url');
      final response = await _client.get(Uri.parse(url)).timeout(_timeout);
      print('[API] 통계 응답 수신: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('[API] 통계 데이터 파싱 완료');
        return DailyStats.fromJson(data);
      } else {
        print('[API] 통계 조회 실패: ${response.statusCode} - ${response.body}');
        throw Exception('통계 조회 실패 (${response.statusCode})');
      }
    } on SocketException catch (e) {
      print('[API] 네트워크 연결 오류: $e');
      throw Exception('네트워크 연결 실패. 인터넷 연결을 확인해주세요.');
    } on HttpException catch (e) {
      print('[API] HTTP 오류: $e');
      throw Exception('서버 연결 오류: $e');
    } on FormatException catch (e) {
      print('[API] 데이터 형식 오류: $e');
      throw Exception('데이터 형식 오류: $e');
    } catch (e) {
      print('[API] 통계 조회 중 예기치 않은 오류: $e');
      throw Exception('통계 조회 실패: $e');
    }
  }

  // 오늘의 영양 목표 조회
  Future<NutritionGoal> getTodayGoal() async {
    try {
      final url = '$baseUrl/goals/today';
      print('[API] 목표 요청 시작: $url');
      final response = await _client.get(Uri.parse(url)).timeout(_timeout);
      print('[API] 목표 응답 수신: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('[API] 목표 데이터 파싱 완료');
        return NutritionGoal.fromJson(data);
      } else {
        print('[API] 목표 조회 실패: ${response.statusCode} - ${response.body}');
        throw Exception('목표 조회 실패 (${response.statusCode})');
      }
    } on SocketException catch (e) {
      print('[API] 네트워크 연결 오류: $e');
      throw Exception('네트워크 연결 실패. 인터넷 연결을 확인해주세요.');
    } on HttpException catch (e) {
      print('[API] HTTP 오류: $e');
      throw Exception('서버 연결 오류: $e');
    } on FormatException catch (e) {
      print('[API] 데이터 형식 오류: $e');
      throw Exception('데이터 형식 오류: $e');
    } catch (e) {
      print('[API] 목표 조회 중 예기치 않은 오류: $e');
      throw Exception('목표 조회 실패: $e');
    }
  }

  // 영양 목표 설정/업데이트
  Future<NutritionGoal> setGoal(NutritionGoal goal) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/goals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(goal.toJson()),
      );

      if (response.statusCode == 200) {
        return NutritionGoal.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('목표 설정 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('목표 설정 중 오류 발생: $e');
    }
  }

  // ============ 음식 추천 API (코사인 유사도 기반) ============

  // 음식 영양정보 조회
  Future<Map<String, dynamic>> getFoodNutrition(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nutrition-db/${Uri.encodeComponent(foodName)}'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('영양정보 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('영양정보 조회 중 오류: $e');
    }
  }

  // 전체 영양정보 목록
  Future<Map<String, dynamic>> getAllNutritionDB() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nutrition-db'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('영양정보 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('영양정보 목록 조회 중 오류: $e');
    }
  }

  // 유사한 음식 추천 (코사인 유사도 기반)
  Future<Map<String, dynamic>> getSimilarFoods(String foodName, {int topK = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommend/similar/${Uri.encodeComponent(foodName)}?top_k=$topK'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('유사 음식 추천 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('유사 음식 추천 중 오류: $e');
    }
  }

  // 다양한 음식 추천
  Future<Map<String, dynamic>> getDiverseFoods(String foodName, {int topK = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommend/diverse/${Uri.encodeComponent(foodName)}?top_k=$topK'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('다양한 음식 추천 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('다양한 음식 추천 중 오류: $e');
    }
  }

  // 개인화 추천
  Future<Map<String, dynamic>> getPersonalizedRecommendations({
    int? userId,
    String? currentFood,
    int topK = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recommend/personalized'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'current_food': currentFood,
          'top_k': topK,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('개인화 추천 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('개인화 추천 중 오류: $e');
    }
  }

  // 영양 균형 추천
  Future<Map<String, dynamic>> getBalancedRecommendations({
    int? userId,
    int topK = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recommend/balanced'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'top_k': topK,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('균형 추천 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('균형 추천 중 오류: $e');
    }
  }

  // 사용자 식사 기록 추가
  Future<Map<String, dynamic>> addUserHistory({
    required int userId,
    required String foodName,
    String? mealType,
    required String date,
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user-history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'food_name': foodName,
          'meal_type': mealType,
          'date': date,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('식사 기록 추가 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('식사 기록 추가 중 오류: $e');
    }
  }

  // 사용자 식사 기록 조회
  Future<Map<String, dynamic>> getUserHistory(int userId, {int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user-history/$userId?days=$days'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('식사 기록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('식사 기록 조회 중 오류: $e');
    }
  }

  // ============ 사용자 식단 점수/등급 API ============

  // 사용자 식단 점수/등급 조회 (노트북 알고리즘 기반)
  Future<Map<String, dynamic>> getUserScore({int? userId, int days = 7}) async {
    try {
      String url = '$baseUrl/user-score?days=$days';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      print('[API] 사용자 점수 요청: $url');
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      print('[API] 사용자 점수 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('사용자 점수 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 사용자 점수 조회 오류: $e');
      throw Exception('사용자 점수 조회 중 오류: $e');
    }
  }

  // EMB_DB 기반 임베딩 추천
  Future<Map<String, dynamic>> getEmbeddingRecommendations(String foodName, {int topK = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommend/embedding/${Uri.encodeComponent(foodName)}?top_k=$topK'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('임베딩 추천 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('임베딩 추천 중 오류: $e');
    }
  }

  // EMB_DB 기반 다양성 추천
  Future<Map<String, dynamic>> getEmbeddingDiverseRecommendations(
    String foodName, {
    int topK = 5,
    double threshold = 0.5,
    int? userId,
  }) async {
    try {
      String url = '$baseUrl/recommend/embedding-diverse/${Uri.encodeComponent(foodName)}?top_k=$topK&threshold=$threshold';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('다양성 추천 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('다양성 추천 중 오류: $e');
    }
  }

  // ============ 제외된 음식 API (사용자별) ============

  // 제외된 음식 목록 조회
  Future<List<String>> getExcludedFoods(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/excluded-foods?user_id=$userId'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => item['food_name'] as String).toList();
      } else {
        throw Exception('제외 음식 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('제외 음식 조회 중 오류: $e');
    }
  }

  // 제외할 음식 추가
  Future<void> addExcludedFood(int userId, String foodName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/excluded-foods'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'food_name': foodName,
        }),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('제외 음식 추가 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('제외 음식 추가 중 오류: $e');
    }
  }

  // 제외된 음식 삭제
  Future<void> removeExcludedFood(int userId, String foodName) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/excluded-foods?user_id=$userId&food_name=${Uri.encodeComponent(foodName)}'),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('제외 음식 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('제외 음식 삭제 중 오류: $e');
    }
  }

  // 모든 제외된 음식 삭제
  Future<void> clearExcludedFoods(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/excluded-foods/all?user_id=$userId'),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('제외 음식 초기화 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('제외 음식 초기화 중 오류: $e');
    }
  }

  // ============ 음식 가격 API (서울 기준) ============

  // 음식 가격 조회
  Future<FoodPrice?> getFoodPrice(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food-price/${Uri.encodeComponent(foodName)}'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['found'] == true) {
          return FoodPrice.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('[API] 가격 조회 오류: $e');
      return null;
    }
  }

  // 예산 범위 내 음식 검색
  Future<List<FoodPrice>> getFoodsByBudget(int minBudget, int maxBudget, {int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food-price-range?min_budget=$minBudget&max_budget=$maxBudget&limit=$limit'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> foods = data['foods'] ?? [];
        return foods.map((f) => FoodPrice.fromJson(f)).toList();
      }
      return [];
    } catch (e) {
      print('[API] 예산 검색 오류: $e');
      return [];
    }
  }

  // 카테고리별 음식 가격 목록
  Future<List<FoodPrice>> getFoodPricesByCategory(String category, {int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/food-prices?category=${Uri.encodeComponent(category)}&limit=$limit'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> foods = data['foods'] ?? [];
        return foods.map((f) => FoodPrice.fromJson(f)).toList();
      }
      return [];
    } catch (e) {
      print('[API] 카테고리 가격 조회 오류: $e');
      return [];
    }
  }

  // ============ 회원 관리 API ============

  // 회원가입
  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String password,
    required String name,
    required double weight,
    required double height,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'name': name,
          'weight': weight,
          'height': height,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 400) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '회원가입 실패');
      } else {
        throw Exception('회원가입 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('회원가입 중 오류: $e');
    }
  }

  // 로그인
  Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        throw Exception('아이디 또는 비밀번호가 올바르지 않습니다');
      } else {
        throw Exception('로그인 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('로그인 중 오류: $e');
    }
  }

  // 아이디 중복 확인
  Future<bool> checkUsernameExists(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/check/${Uri.encodeComponent(username)}'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print('[API] 아이디 중복확인 오류: $e');
      return false;
    }
  }

  // 사용자 정보 조회
  Future<Map<String, dynamic>?> getUser(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('[API] 사용자 조회 오류: $e');
      return null;
    }
  }

  // 사용자 정보 수정
  Future<Map<String, dynamic>> updateUser(int userId, {
    String? name,
    double? weight,
    double? height,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (weight != null) body['weight'] = weight;
      if (height != null) body['height'] = height;
      if (password != null) body['password'] = password;

      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('사용자 정보 수정 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('사용자 정보 수정 중 오류: $e');
    }
  }

  // 회원 탈퇴
  Future<void> deleteUser(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('회원 탈퇴 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('회원 탈퇴 중 오류: $e');
    }
  }

  // ============ 이미지 업로드 API ============

  // 이미지 파일 업로드
  Future<String> uploadImage(File imageFile, {int? userId}) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-image'),
      );

      if (userId != null) {
        request.fields['user_id'] = userId.toString();
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('[API] 이미지 업로드 성공: ${data['image_url']}');
        return data['image_url'];
      } else {
        throw Exception('이미지 업로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('이미지 업로드 중 오류: $e');
    }
  }

  // Base64 이미지 업로드
  Future<String> uploadImageBase64(String base64Image, {int? userId, String fileExt = '.jpg'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/upload-image-base64'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'image_base64': base64Image,
          if (userId != null) 'user_id': userId.toString(),
          'file_ext': fileExt,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('[API] Base64 이미지 업로드 성공: ${data['image_url']}');
        return data['image_url'];
      } else {
        throw Exception('Base64 이미지 업로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Base64 이미지 업로드 중 오류: $e');
    }
  }

  // 이미지 삭제
  Future<void> deleteImage(String filename) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/delete-image/$filename'),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('이미지 삭제 실패: ${response.statusCode}');
      }
      print('[API] 이미지 삭제 성공: $filename');
    } catch (e) {
      throw Exception('이미지 삭제 중 오류: $e');
    }
  }

  // 이미지 URL 가져오기 (서버 주소 포함)
  String getFullImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    // baseUrl에서 /api 제거하고 이미지 경로 추가
    final serverUrl = baseUrl.replaceAll('/api', '');
    return '$serverUrl$imagePath';
  }

  // ============ 사용자 설정 API ============

  // 사용자 설정 조회
  Future<Map<String, dynamic>> getUserSettings(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user-settings/$userId'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('설정 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 사용자 설정 조회 실패: $e');
      throw Exception('설정 조회 중 오류: $e');
    }
  }

  // 사용자 설정 저장
  Future<Map<String, dynamic>> saveUserSettings({
    required int userId,
    bool? mealReminder,
    bool? breakfastReminder,
    bool? lunchReminder,
    bool? dinnerReminder,
    bool? goalAchievement,
    bool? weeklyReport,
    int? breakfastHour,
    int? breakfastMinute,
    int? lunchHour,
    int? lunchMinute,
    int? dinnerHour,
    int? dinnerMinute,
    int? recommendMinPrice,
    int? recommendMaxPrice,
    bool? skipPriceDialog,
    String? activityLevel,
    String? dietGoal,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user-settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'meal_reminder': mealReminder ?? true,
          'breakfast_reminder': breakfastReminder ?? true,
          'lunch_reminder': lunchReminder ?? true,
          'dinner_reminder': dinnerReminder ?? true,
          'goal_achievement': goalAchievement ?? true,
          'weekly_report': weeklyReport ?? true,
          'breakfast_hour': breakfastHour ?? 8,
          'breakfast_minute': breakfastMinute ?? 0,
          'lunch_hour': lunchHour ?? 12,
          'lunch_minute': lunchMinute ?? 0,
          'dinner_hour': dinnerHour ?? 18,
          'dinner_minute': dinnerMinute ?? 0,
          'recommend_min_price': recommendMinPrice ?? 5000,
          'recommend_max_price': recommendMaxPrice ?? 15000,
          'skip_price_dialog': skipPriceDialog ?? false,
          'activity_level': activityLevel ?? 'moderate',
          'diet_goal': dietGoal ?? 'maintain',
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        print('[API] 사용자 설정 저장 완료');
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('설정 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] 사용자 설정 저장 실패: $e');
      throw Exception('설정 저장 중 오류: $e');
    }
  }
}

// 음식 가격 모델
class FoodPrice {
  final String foodName;
  final int basePrice;
  final int minPrice;
  final int maxPrice;
  final String currency;
  final String unit;
  final String region;

  FoodPrice({
    required this.foodName,
    required this.basePrice,
    required this.minPrice,
    required this.maxPrice,
    this.currency = 'KRW',
    this.unit = '1인분',
    this.region = '서울',
  });

  factory FoodPrice.fromJson(Map<String, dynamic> json) {
    return FoodPrice(
      foodName: json['food_name'] ?? '',
      basePrice: json['base_price'] ?? 0,
      minPrice: json['min_price'] ?? 0,
      maxPrice: json['max_price'] ?? 0,
      currency: json['currency'] ?? 'KRW',
      unit: json['unit'] ?? '1인분',
      region: json['region'] ?? '서울',
    );
  }

  String get priceRange => '${_formatPrice(minPrice)} ~ ${_formatPrice(maxPrice)}';
  String get basePriceFormatted => _formatPrice(basePrice);

  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
  }
}
