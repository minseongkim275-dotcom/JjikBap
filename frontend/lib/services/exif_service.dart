import 'dart:io';
import 'package:exif/exif.dart';

class ExifService {
  /// 이미지 파일에서 GPS 좌표를 추출합니다.
  /// 반환값: {latitude: double, longitude: double} 또는 null
  static Future<Map<String, double>?> extractGpsCoordinates(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('[ExifService] 파일이 존재하지 않습니다: $imagePath');
        return null;
      }

      print('[ExifService] 파일 읽기 시작: $imagePath');
      final bytes = await file.readAsBytes();
      print('[ExifService] 파일 크기: ${bytes.length} bytes');

      final data = await readExifFromBytes(bytes);

      if (data.isEmpty) {
        print('[ExifService] EXIF 데이터가 없습니다');
        return null;
      }

      // 모든 EXIF 키 출력 (디버깅용)
      print('[ExifService] EXIF 키 목록: ${data.keys.toList()}');

      // GPS 정보 추출
      final gpsLatitude = data['GPS GPSLatitude'];
      final gpsLatitudeRef = data['GPS GPSLatitudeRef'];
      final gpsLongitude = data['GPS GPSLongitude'];
      final gpsLongitudeRef = data['GPS GPSLongitudeRef'];

      print('[ExifService] GPSLatitude: $gpsLatitude');
      print('[ExifService] GPSLatitudeRef: $gpsLatitudeRef');
      print('[ExifService] GPSLongitude: $gpsLongitude');
      print('[ExifService] GPSLongitudeRef: $gpsLongitudeRef');

      if (gpsLatitude == null || gpsLongitude == null) {
        print('[ExifService] GPS 정보가 없습니다');
        return null;
      }

      // GPS 좌표 변환 - 다양한 형식 지원
      double? lat;
      double? lng;

      try {
        // IfdRatios 형식 처리
        final latValues = gpsLatitude.values;
        final lngValues = gpsLongitude.values;

        print('[ExifService] latValues type: ${latValues.runtimeType}');
        print('[ExifService] lngValues type: ${lngValues.runtimeType}');

        if (latValues is IfdRatios && lngValues is IfdRatios) {
          lat = _convertIfdRatiosToDecimal(
            latValues,
            gpsLatitudeRef?.printable ?? 'N'
          );
          lng = _convertIfdRatiosToDecimal(
            lngValues,
            gpsLongitudeRef?.printable ?? 'E'
          );
        } else {
          // 기존 방식 시도
          lat = _convertToDecimal(
            gpsLatitude.values.toList().cast<Ratio>(),
            gpsLatitudeRef?.printable ?? 'N'
          );
          lng = _convertToDecimal(
            gpsLongitude.values.toList().cast<Ratio>(),
            gpsLongitudeRef?.printable ?? 'E'
          );
        }
      } catch (e) {
        print('[ExifService] 첫 번째 변환 방식 실패: $e');
        // 대체 방식 시도
        try {
          lat = _parseGpsString(gpsLatitude.toString(), gpsLatitudeRef?.printable ?? 'N');
          lng = _parseGpsString(gpsLongitude.toString(), gpsLongitudeRef?.printable ?? 'E');
        } catch (e2) {
          print('[ExifService] 대체 변환 방식도 실패: $e2');
        }
      }

      if (lat == null || lng == null) {
        print('[ExifService] GPS 좌표 변환 실패');
        return null;
      }

      print('[ExifService] GPS 좌표 추출 성공: lat=$lat, lng=$lng');
      return {
        'latitude': lat,
        'longitude': lng,
      };
    } catch (e, stackTrace) {
      print('[ExifService] GPS 추출 중 오류 발생: $e');
      print('[ExifService] 스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// IfdRatios를 10진수로 변환
  static double? _convertIfdRatiosToDecimal(IfdRatios ratios, String ref) {
    try {
      final ratioList = ratios.toList();
      if (ratioList.length < 3) {
        print('[ExifService] ratioList 길이 부족: ${ratioList.length}');
        return null;
      }

      final degrees = ratioList[0].numerator / ratioList[0].denominator;
      final minutes = ratioList[1].numerator / ratioList[1].denominator;
      final seconds = ratioList[2].numerator / ratioList[2].denominator;

      print('[ExifService] degrees=$degrees, minutes=$minutes, seconds=$seconds');

      var decimal = degrees + (minutes / 60) + (seconds / 3600);

      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return decimal;
    } catch (e) {
      print('[ExifService] IfdRatios 변환 중 오류: $e');
      return null;
    }
  }

  /// GPS 좌표를 10진수로 변환 (기존 방식)
  static double? _convertToDecimal(List<Ratio> ratios, String ref) {
    try {
      if (ratios.length < 3) return null;

      final degrees = ratios[0].numerator / ratios[0].denominator;
      final minutes = ratios[1].numerator / ratios[1].denominator;
      final seconds = ratios[2].numerator / ratios[2].denominator;

      var decimal = degrees + (minutes / 60) + (seconds / 3600);

      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return decimal;
    } catch (e) {
      print('[ExifService] 좌표 변환 중 오류: $e');
      return null;
    }
  }

  /// GPS 문자열 파싱 (대체 방식)
  static double? _parseGpsString(String gpsString, String ref) {
    try {
      // "[37/1, 30/1, 45/1]" 형식 파싱
      final regex = RegExp(r'\[(\d+)/(\d+),\s*(\d+)/(\d+),\s*(\d+)/(\d+)\]');
      final match = regex.firstMatch(gpsString);

      if (match != null) {
        final degrees = int.parse(match.group(1)!) / int.parse(match.group(2)!);
        final minutes = int.parse(match.group(3)!) / int.parse(match.group(4)!);
        final seconds = int.parse(match.group(5)!) / int.parse(match.group(6)!);

        var decimal = degrees + (minutes / 60) + (seconds / 3600);

        if (ref == 'S' || ref == 'W') {
          decimal = -decimal;
        }

        return decimal;
      }
      return null;
    } catch (e) {
      print('[ExifService] GPS 문자열 파싱 오류: $e');
      return null;
    }
  }

  /// 이미지에 GPS 정보가 있는지 확인
  static Future<bool> hasGpsData(String imagePath) async {
    final coords = await extractGpsCoordinates(imagePath);
    return coords != null;
  }

  /// 디버깅용: 모든 EXIF 정보 출력
  static Future<void> printAllExifData(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final data = await readExifFromBytes(bytes);

      print('[ExifService] === 전체 EXIF 데이터 ===');
      for (var entry in data.entries) {
        print('[ExifService] ${entry.key}: ${entry.value}');
      }
      print('[ExifService] === EXIF 데이터 끝 ===');
    } catch (e) {
      print('[ExifService] EXIF 출력 오류: $e');
    }
  }
}
