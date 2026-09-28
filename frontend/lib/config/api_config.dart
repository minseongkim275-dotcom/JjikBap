import 'dart:io';

class ApiConfig {
  // 릴리즈 빌드(APK)일 때는 true, 디버그 모드일 때는 false
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  // 배포 서버 주소 (릴리즈 빌드에서 사용)
  // 저장소에 서버 주소를 남기지 않도록 빌드 시 주입한다:
  //   flutter build apk --dart-define-from-file=dart_defines.json
  // (dart_defines.json 은 .gitignore 대상, dart_defines.example.json 참고)
  static const String serverHost =
      String.fromEnvironment('SERVER_HOST', defaultValue: 'localhost');
  static const int serverPort =
      int.fromEnvironment('SERVER_PORT', defaultValue: 80);

  // 로컬 백엔드 포트 (디버그 모드에서 사용)
  static const int localPort = 8000;

  /// 현재 환경에 맞는 Base URL 반환
  static String get baseUrl {
    String url;

    // 릴리즈 빌드 (APK) - 배포 서버 사용
    if (isProduction) {
      if (Platform.isAndroid || Platform.isIOS) {
        url = 'http://$serverHost:$serverPort/api';
        print('[ApiConfig] 프로덕션 모드 - 배포 서버 사용: $url');
        return url;
      }
    }

    // 디버그 모드: 로컬 백엔드 사용 (Android 에뮬레이터는 10.0.2.2가 PC의 localhost)
    if (Platform.isAndroid) {
      url = 'http://10.0.2.2:$localPort/api';
    } else {
      url = 'http://127.0.0.1:$localPort/api';
    }
    print('[ApiConfig] 디버그 모드 - 로컬 서버 사용: $url');
    return url;
  }

  /// API Base URL (읽기 전용)
  static String get apiUrl => baseUrl;

  /// 현재 설정 정보 출력 (디버깅용)
  static void printConfig() {
    print('=== API Configuration ===');
    print('Mode: ${isProduction ? "Production (Release)" : "Development (Debug)"}');
    print('Platform: ${Platform.operatingSystem}');
    print('Base URL: $baseUrl');
    print('Server: $serverHost:$serverPort');
    print('========================');
  }

  /// 커스텀 호스트로 URL 생성 (테스트용)
  static String getCustomUrl(String customHost) {
    return 'http://$customHost:$serverPort/api';
  }
}
