import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import 'database_service.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final DatabaseService _dbService = DatabaseService();

  /// 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      // 구글 로그인 팝업 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인 취소
        return null;
      }

      // 구글 계정 정보 가져오기
      final String email = googleUser.email;
      final String name = googleUser.displayName ?? 'Unknown';
      final String? photoUrl = googleUser.photoUrl;

      print('구글 로그인 성공: $email');

      // 기존 사용자 확인
      final isExistingUser = await _dbService.isUsernameExists(email);

      if (isExistingUser) {
        // 기존 사용자: 로그인
        final user = await _dbService.login(email, 'google_oauth');
        return user;
      } else {
        // 신규 사용자: 회원가입
        final newUser = User(
          username: email,
          password: 'google_oauth',
          name: name,
          weight: 60.0,
          height: 170.0,
          createdAt: DateTime.now(),
        );

        final userId = await _dbService.insertUser(newUser);
        return User(
          id: userId,
          username: email,
          password: 'google_oauth',
          name: name,
          weight: 60.0,
          height: 170.0,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('구글 로그인 실패: $e');
      return null;
    }
  }

  /// 구글 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      print('구글 로그아웃 성공');
    } catch (e) {
      print('구글 로그아웃 실패: $e');
    }
  }

  /// 현재 로그인된 구글 계정 확인
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return await _googleSignIn.signInSilently();
  }

  /// 로그인 상태 확인
  bool get isSignedIn => _googleSignIn.currentUser != null;
}
