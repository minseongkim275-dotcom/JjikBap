import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/food_record.dart';
import 'api_service.dart';

/// DatabaseService - 서버 API 우선, 로컬 DB는 캐시/오프라인용
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  final ApiService _apiService = ApiService();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  static void initialize() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'nutrition_tracker.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serverId INTEGER,
        userId INTEGER NOT NULL,
        foodName TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL DEFAULT 0.0,
        carbs REAL DEFAULT 0.0,
        fat REAL DEFAULT 0.0,
        fiber REAL DEFAULT 0.0,
        imagePath TEXT,
        description TEXT,
        createdAt TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        rating INTEGER,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE food_records ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE food_records ADD COLUMN longitude REAL');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE food_records ADD COLUMN rating INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE food_records ADD COLUMN serverId INTEGER');
      await db.execute('ALTER TABLE food_records ADD COLUMN synced INTEGER DEFAULT 0');
    }
  }

  // ==================== 회원 관련 (서버 우선) ====================

  /// 회원가입 - 서버에 저장 후 로컬에도 캐시
  Future<int> insertUser(User user) async {
    int? serverId;

    // 1. 서버에 회원가입
    try {
      final result = await _apiService.registerUser(
        username: user.username,
        password: user.password,
        name: user.name,
        weight: user.weight,
        height: user.height,
      );
      serverId = result['id'];
      print('[DB] 서버 회원가입 성공: $serverId');
    } catch (e) {
      print('[DB] 서버 회원가입 실패: $e');
    }

    // 2. 로컬 DB에도 저장 (캐시)
    final db = await database;
    final localUser = User(
      id: serverId,
      username: user.username,
      password: user.password,
      name: user.name,
      weight: user.weight,
      height: user.height,
    );
    final localId = await db.insert('users', localUser.toMap());

    return serverId ?? localId;
  }

  /// 로그인 - 서버 우선, 실패시 로컬
  Future<User?> login(String username, String password) async {
    // 1. 서버 로그인 시도
    try {
      final result = await _apiService.loginUser(
        username: username,
        password: password,
      );
      print('[DB] 서버 로그인 성공: ${result['id']}');

      final user = User(
        id: result['id'],
        username: result['username'],
        password: password,
        name: result['name'],
        weight: (result['weight'] ?? 60.0).toDouble(),
        height: (result['height'] ?? 170.0).toDouble(),
      );

      // 로컬에도 캐시
      await _cacheUserLocally(user);
      return user;
    } catch (e) {
      print('[DB] 서버 로그인 실패, 로컬 시도: $e');
    }

    // 2. 로컬 DB에서 로그인
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// 아이디 중복 확인 - 서버 우선
  Future<bool> isUsernameExists(String username) async {
    // 1. 서버에서 확인
    try {
      final exists = await _apiService.checkUsernameExists(username);
      print('[DB] 서버 아이디 중복확인: $exists');
      return exists;
    } catch (e) {
      print('[DB] 서버 중복확인 실패, 로컬 확인: $e');
    }

    // 2. 로컬에서 확인
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return maps.isNotEmpty;
  }

  /// 사용자 정보 조회 - 서버 우선
  Future<User?> getUserById(int id) async {
    // 1. 서버에서 조회
    try {
      final result = await _apiService.getUser(id);
      if (result != null) {
        print('[DB] 서버 사용자 조회 성공');
        return User(
          id: result['id'],
          username: result['username'],
          password: '',
          name: result['name'],
          weight: (result['weight'] ?? 60.0).toDouble(),
          height: (result['height'] ?? 170.0).toDouble(),
        );
      }
    } catch (e) {
      print('[DB] 서버 사용자 조회 실패: $e');
    }

    // 2. 로컬에서 조회
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// 사용자 정보 수정 - 서버 + 로컬
  Future<int> updateUser(User user) async {
    // 1. 서버 업데이트
    try {
      await _apiService.updateUser(
        user.id!,
        name: user.name,
        weight: user.weight,
        height: user.height,
      );
      print('[DB] 서버 사용자 정보 수정 성공');
    } catch (e) {
      print('[DB] 서버 사용자 정보 수정 실패: $e');
    }

    // 2. 로컬 업데이트
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// 회원 탈퇴 - 서버 + 로컬
  Future<int> deleteUser(int id) async {
    // 1. 서버에서 삭제
    try {
      await _apiService.deleteUser(id);
      print('[DB] 서버 회원 탈퇴 성공');
    } catch (e) {
      print('[DB] 서버 회원 탈퇴 실패: $e');
    }

    // 2. 로컬에서 삭제
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 로컬 캐시에 사용자 저장
  Future<void> _cacheUserLocally(User user) async {
    final db = await database;
    try {
      // 이미 있으면 업데이트, 없으면 삽입
      final existing = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [user.username],
      );

      if (existing.isEmpty) {
        await db.insert('users', user.toMap());
      } else {
        await db.update(
          'users',
          user.toMap(),
          where: 'username = ?',
          whereArgs: [user.username],
        );
      }
    } catch (e) {
      print('[DB] 로컬 캐시 저장 실패: $e');
    }
  }

  // ==================== 식단 기록 관련 (서버 우선) ====================

  /// 음식 기록 저장 - 서버 + 로컬
  Future<int> insertFoodRecord(FoodRecord record) async {
    int? serverId;

    // 1. 서버에 저장
    try {
      final serverRecord = await _apiService.createFoodRecord(record);
      serverId = serverRecord.id;
      print('[DB] 서버 음식 기록 저장 성공: $serverId');
    } catch (e) {
      print('[DB] 서버 음식 기록 저장 실패: $e');
    }

    // 2. 로컬에도 저장
    final db = await database;
    final localMap = record.toMap();
    localMap['serverId'] = serverId;
    localMap['synced'] = serverId != null ? 1 : 0;

    return await db.insert('food_records', localMap);
  }

  /// 사용자의 모든 음식 기록 조회 - 서버 우선
  Future<List<FoodRecord>> getFoodRecordsByUserId(int userId) async {
    // 1. 서버에서 조회
    try {
      final records = await _apiService.getFoodRecords(userId: userId);
      print('[DB] 서버 음식 기록 조회 성공: ${records.length}개');

      // 로컬에 캐시
      await _cacheFoodRecordsLocally(userId, records);
      return records;
    } catch (e) {
      print('[DB] 서버 음식 기록 조회 실패, 로컬 사용: $e');
    }

    // 2. 로컬에서 조회
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'food_records',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => FoodRecord.fromMap(maps[i]));
  }

  /// 날짜별 음식 기록 조회 - 서버 우선
  Future<List<FoodRecord>> getFoodRecordsByDate(int userId, DateTime date) async {
    // 서버에서 전체 조회 후 필터링 (서버 API에 날짜 필터가 없을 경우)
    final allRecords = await getFoodRecordsByUserId(userId);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return allRecords.where((r) {
      if (r.createdAt == null) return false;
      return r.createdAt!.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
             r.createdAt!.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();
  }

  /// 음식 기록 수정 - 서버 + 로컬
  Future<int> updateFoodRecord(FoodRecord record) async {
    // 서버에는 update API가 없으므로 로컬만 업데이트
    // 필요시 서버 API 추가 필요
    final db = await database;
    return await db.update(
      'food_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 음식 기록 삭제 - 서버 + 로컬
  Future<int> deleteFoodRecord(int id) async {
    // 1. 서버에서 삭제
    try {
      await _apiService.deleteFoodRecord(id);
      print('[DB] 서버 음식 기록 삭제 성공');
    } catch (e) {
      print('[DB] 서버 음식 기록 삭제 실패: $e');
    }

    // 2. 로컬에서 삭제
    final db = await database;
    return await db.delete(
      'food_records',
      where: 'id = ? OR serverId = ?',
      whereArgs: [id, id],
    );
  }

  /// 오늘 총 칼로리 조회
  Future<double> getTodayTotalCalories(int userId) async {
    final today = DateTime.now();
    final records = await getFoodRecordsByDate(userId, today);
    return records.fold<double>(0.0, (sum, record) => sum + record.calories);
  }

  /// 음식 기록 조회 (getFoodRecordsByUserId와 동일)
  Future<List<FoodRecord>> getFoodRecords(int userId) async {
    return getFoodRecordsByUserId(userId);
  }

  /// 로컬에 음식 기록 캐시
  Future<void> _cacheFoodRecordsLocally(int userId, List<FoodRecord> records) async {
    final db = await database;

    // 기존 캐시 삭제 (synced 된 것만)
    await db.delete(
      'food_records',
      where: 'userId = ? AND synced = 1',
      whereArgs: [userId],
    );

    // 새로 캐시
    for (var record in records) {
      final map = record.toMap();
      map['serverId'] = record.id;
      map['synced'] = 1;
      map['userId'] = userId;
      await db.insert('food_records', map);
    }
  }

  /// 동기화되지 않은 로컬 기록을 서버에 업로드
  Future<void> syncPendingRecords(int userId) async {
    final db = await database;
    final pending = await db.query(
      'food_records',
      where: 'userId = ? AND synced = 0',
      whereArgs: [userId],
    );

    for (var map in pending) {
      try {
        final record = FoodRecord.fromMap(map);
        final serverRecord = await _apiService.createFoodRecord(record);

        // 동기화 완료 표시
        await db.update(
          'food_records',
          {'serverId': serverRecord.id, 'synced': 1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        print('[DB] 펜딩 기록 동기화 성공: ${serverRecord.id}');
      } catch (e) {
        print('[DB] 펜딩 기록 동기화 실패: $e');
      }
    }
  }

  // 테스트용 샘플 데이터 삽입 (서버에도 저장)
  Future<void> insertSampleData(int userId) async {
    final existing = await getFoodRecordsByUserId(userId);
    if (existing.isNotEmpty) {
      return; // 이미 데이터가 있으면 삽입 안함
    }

    final sampleFoods = [
      {'name': '김치찌개', 'cal': 450.0, 'pro': 22.0, 'carb': 35.0, 'fat': 18.0, 'days': 0},
      {'name': '닭가슴살 샐러드', 'cal': 320.0, 'pro': 35.0, 'carb': 12.0, 'fat': 8.0, 'days': 0},
      {'name': '비빔밥', 'cal': 580.0, 'pro': 18.0, 'carb': 85.0, 'fat': 15.0, 'days': 1},
      {'name': '불고기', 'cal': 520.0, 'pro': 32.0, 'carb': 25.0, 'fat': 22.0, 'days': 2},
    ];

    final now = DateTime.now();

    for (var food in sampleFoods) {
      final daysAgo = food['days'] as int;
      final createdAt = now.subtract(Duration(days: daysAgo));

      final record = FoodRecord(
        id: null,
        userId: userId,
        foodName: food['name'] as String,
        calories: food['cal'] as double,
        protein: food['pro'] as double,
        carbs: food['carb'] as double,
        fat: food['fat'] as double,
        fiber: 2.0,
        imagePath: null,
        description: '샘플 데이터',
        createdAt: createdAt,
        latitude: null,
        longitude: null,
        rating: null,
      );

      await insertFoodRecord(record);
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
