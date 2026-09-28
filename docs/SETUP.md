# 실행 가이드

## 요구 사항

| 구분 | 버전 |
|---|---|
| Python | 3.10 이상 (3.13에서 확인) |
| Flutter | 3.35 (Dart 3.9) |
| Windows 앱 빌드 시 | Visual Studio 2022 + "C++를 사용한 데스크톱 개발" |

> ⚠️ **Windows에서 Flutter 빌드 시 프로젝트 경로에 한글이 있으면 실패합니다.**
> (셰이더 컴파일러가 경로를 깨뜨려 `ShaderCompilerException` 발생)
> `C:\dev\jjikbap` 처럼 영문 경로에 두세요. 심볼릭 링크/정션은 실제 경로로 풀려서 소용없습니다.

---

## 1. 모델 파일 받기

`food_classifier.pt`(약 110MB)는 GitHub 파일 크기 제한 때문에 저장소에 없습니다.

1. 저장소의 **Releases** 페이지에서 `food_classifier.pt` 다운로드
2. `backend/app/ml_models/food_classifier.pt` 위치에 복사

모델이 없어도 서버는 뜨지만, 사진 분석은 14종 Detection 모델(`best.pt`)로만 동작합니다.

## 2. 백엔드 실행

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # macOS/Linux: source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API 문서(Swagger): http://localhost:8000/docs
- 상태 확인: http://localhost:8000/health → `{"status":"healthy"}`
- 첫 실행 시 `jjikbap.db`(SQLite)가 자동 생성되고 영양 DB가 초기화됩니다.
- 첫 텍스트 분석 요청 때 KoELECTRA 모델을 Hugging Face에서 내려받습니다(인터넷 필요).

`start_server.bat` / `start_server.sh` 로도 실행할 수 있습니다.

### 샘플 데이터 넣기 (선택)

```bash
cd backend
python scripts/seed_sample_data.py
```

`backend/sample_data/`의 음식 사진으로 최근 14일치 기록을 만듭니다.

## 3. 앱 실행

```bash
cd frontend
flutter pub get
flutter run -d windows      # Windows 데스크톱
flutter run                 # 연결된 Android 기기/에뮬레이터
```

### 서버 주소

`lib/config/api_config.dart`가 빌드 모드에 따라 자동으로 고릅니다.

| 빌드 | 플랫폼 | 주소 |
|---|---|---|
| 디버그 (`flutter run`) | Windows / iOS 시뮬레이터 | `http://127.0.0.1:8000/api` |
| 디버그 | Android 에뮬레이터 | `http://10.0.2.2:8000/api` |
| 릴리즈 (APK) | Android / iOS | `http://{SERVER_HOST}:{SERVER_PORT}/api` |

릴리즈 서버 주소는 저장소에 넣지 않고 빌드할 때 주입합니다.

```bash
cp dart_defines.example.json dart_defines.json   # 서버 주소 입력 (git에는 올라가지 않음)
flutter build apk --release --dart-define-from-file=dart_defines.json
```

주소를 넘기지 않으면 `localhost`로 빌드됩니다.

실제 기기에서 PC의 로컬 서버에 붙일 때는 PC와 폰을 같은 Wi-Fi에 두고, Windows 방화벽에서 8000 포트 인바운드를 허용하세요.

## 4. 테스트

```bash
cd frontend
flutter test
```

---

## 백엔드 유지보수 스크립트 (`backend/scripts/`)

모두 `backend/` 폴더에서 `python scripts/<파일명>` 으로 실행합니다.

| 스크립트 | 용도 |
|---|---|
| `seed_sample_data.py` | 샘플 음식 기록 14일치 생성 |
| `migrate_add_gps_rating.py` | `food_records`에 위도/경도/별점 컬럼 추가 (구버전 DB 마이그레이션) |
| `inspect_db.py` | DB 테이블 스키마와 최근 기록 출력 |
| `check_db_integrity.py` | SQLite + JSON 데이터 무결성 점검 |
| `validate_ml_data.py` | 모델 라벨·영양·가격·임베딩 JSON 간 정합성 검증 |
| `fill_default_nutrition.py` | 분류 모델 음식 중 영양 정보가 없는 항목에 기본값 채움 |
| `generate_food_prices.py` | 음식 카테고리별 가격 데이터 생성 |
| `add_missing_prices.py` / `add_remaining_prices.py` | 누락된 음식 가격 보충 |
| `find_missing_prices.py` / `check_food_prices.py` | 가격 누락 여부 확인 |
| `search_prices_by_range.py` | 가격대별 음식 검색 동작 확인 |
| `rebuild_embedding_db.py <원본.json>` | 원본 임베딩 파일에서 `food_embedding_db.json` 재생성 |
