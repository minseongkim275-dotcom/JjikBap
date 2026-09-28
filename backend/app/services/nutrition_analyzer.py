import base64
import os
import json
import io
from pathlib import Path
from typing import Dict, Optional
import torch
from PIL import Image
from app.schemas.food_schema import NutritionInfo
from app.services.ner_food_recognizer import get_recognizer

class NutritionAnalyzer:
    def __init__(self):
        # 모델 파일 경로 설정
        self.base_dir = Path(__file__).parent.parent / "ml_models"

        # 새 분류 모델 (700개 클래스, top5 정확도 98.8%)
        self.classifier_model_path = self.base_dir / "food_classifier.pt"
        self.classifier_labels_path = self.base_dir / "classifier_labels.txt"

        # 기존 YOLO 모델 (Detection/fallback)
        self.detection_model_path = self.base_dir / "best.pt"
        self.detection_labels_path = self.base_dir / "labels.txt"

        self.nutrition_path = self.base_dir / "food_nutrition_lookup.json"

        # 클래스 ID -> 음식 이름 매핑 로드
        self.class_id_to_food = self._load_class_id_mapping()

        # 라벨 로드 (분류 모델용)
        self.classifier_labels = self._load_labels(self.classifier_labels_path)
        # 라벨 로드 (Detection 모델용)
        self.detection_labels = self._load_labels(self.detection_labels_path)

        # 영양 정보 데이터베이스 로드
        self.nutrition_db = self._load_nutrition_db()

        # YOLO 모델 로드 (분류 모델 우선)
        self.classifier_model = None
        self.detection_model = None

        try:
            from ultralytics import YOLO

            # 새 분류 모델 로드 (우선)
            if self.classifier_model_path.exists():
                self.classifier_model = YOLO(str(self.classifier_model_path))
                print(f"✓ 분류 모델 로드 완료: {self.classifier_model_path}")
                print(f"  클래스 수: {len(self.classifier_labels)}개")

            # 기존 Detection 모델 로드 (fallback)
            if self.detection_model_path.exists():
                self.detection_model = YOLO(str(self.detection_model_path))
                print(f"✓ Detection 모델 로드 완료: {self.detection_model_path}")

        except Exception as e:
            print(f"✗ 모델 로드 실패: {e}")
            print("  이미지 분석 기능이 제한됩니다.")

    def _load_class_id_mapping(self) -> Dict:
        """class_id_to_food.json에서 클래스 ID -> 음식 이름 매핑 로드"""
        mapping_path = self.base_dir / "class_id_to_food.json"
        try:
            with open(mapping_path, 'r', encoding='utf-8') as f:
                mapping = json.load(f)
            print(f"✓ 클래스 ID 매핑 로드 완료: {len(mapping)}개")
            return mapping
        except Exception as e:
            print(f"✗ 클래스 ID 매핑 로드 실패: {e}")
            return {}

    def _load_labels(self, labels_path: Path) -> list:
        """labels.txt 파일에서 클래스 레이블 로드"""
        try:
            with open(labels_path, 'r', encoding='utf-8') as f:
                labels = [line.strip() for line in f if line.strip()]
            print(f"✓ 라벨 로드 완료 ({labels_path.name}): {len(labels)}개 음식")
            return labels
        except Exception as e:
            print(f"✗ 라벨 로드 실패 ({labels_path}): {e}")
            return []

    def _load_nutrition_db(self) -> Dict:
        """food_nutrition_lookup.json 파일에서 영양 정보 로드"""
        try:
            with open(self.nutrition_path, 'r', encoding='utf-8') as f:
                nutrition_db = json.load(f)
            print(f"✓ 영양 정보 로드 완료: {len(nutrition_db)}개 음식")
            return nutrition_db
        except Exception as e:
            print(f"✗ 영양 정보 로드 실패: {e}")
            return {}

    def analyze_text(self, text: str) -> Optional[NutritionInfo]:
        """텍스트에서 음식명을 찾아 영양 정보를 반환 (800개 음식 사전 기반)"""
        if not text:
            return None

        text_clean = text.strip()
        print(f"🔍 텍스트 분석 중: '{text_clean}'")

        # 입력한 이름이 SQLite 영양 DB에 정확히 있으면 사전 매칭보다 우선 사용
        exact_info = self._get_nutrition_from_sqlite(text_clean, 1.0)
        if exact_info is not None:
            return exact_info

        # 음식 사전에서 음식 찾기 (800개 음식)
        try:
            ner_recognizer = get_recognizer()
            analysis_result = ner_recognizer.analyze_text(text_clean)

            if analysis_result["success"] and analysis_result["matched_food"]:
                food_name = analysis_result["matched_food"]
                print(f"✓ 음식 매칭: {food_name}")
                print(f"  추출된 단어: {analysis_result['extracted_entities']}")

                # 영양 정보 조회 시도
                nutrition_info = self._get_nutrition_info(food_name)

                # 영양 정보가 없으면 기본값 반환
                if nutrition_info is None:
                    print(f"⚠ '{food_name}' 영양 정보 없음 - 기본값 반환")
                    return NutritionInfo(
                        food_name=food_name,
                        calories=300.0,  # 기본 칼로리
                        protein=15.0,    # 기본 단백질
                        carbs=40.0,      # 기본 탄수화물
                        fat=10.0,        # 기본 지방
                        fiber=3.0        # 기본 섬유질
                    )

                return nutrition_info
            else:
                print(f"✗ 음식 매칭 실패. 추출된 단어: {analysis_result.get('extracted_entities', [])}")
        except Exception as e:
            print(f"⚠ 텍스트 분석 중 오류: {e}")
            import traceback
            traceback.print_exc()

        # 음식을 찾지 못하면 None 반환
        print(f"✗ 매칭되는 음식 없음")
        return None

    def analyze_image(self, image_base64: str) -> Optional[NutritionInfo]:
        """
        이미지를 분석하여 음식을 인식하고 영양 정보를 반환
        분류 모델(700개 클래스)을 우선 사용하고, 실패 시 Detection 모델 사용
        """
        if not self.classifier_model and not self.detection_model:
            print("✗ 모델이 로드되지 않았습니다")
            return None

        try:
            # Base64를 이미지로 디코딩
            image_data = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_data))

            # 1. 분류 모델 우선 사용 (700개 클래스)
            if self.classifier_model:
                result = self._analyze_with_classifier(image)
                if result:
                    return result

            # 2. Detection 모델 fallback
            if self.detection_model:
                result = self._analyze_with_detection(image)
                if result:
                    return result

            print("✗ 이미지에서 음식을 감지하지 못했습니다")
            return None

        except Exception as e:
            print(f"✗ 이미지 분석 중 오류 발생: {e}")
            import traceback
            traceback.print_exc()
            return None

    def _analyze_with_classifier(self, image: Image.Image) -> Optional[NutritionInfo]:
        """분류 모델로 이미지 분석 (700개 클래스)"""
        try:
            results = self.classifier_model.predict(image, verbose=False)

            if len(results) > 0:
                result = results[0]

                # Classification 모델 결과 처리
                if hasattr(result, 'probs') and result.probs is not None:
                    probs = result.probs
                    class_id = int(probs.top1)
                    confidence = float(probs.top1conf)

                    # Top-5 결과도 출력
                    top5_ids = probs.top5
                    top5_confs = probs.top5conf

                    print(f"📊 분류 모델 Top-5 결과:")
                    for i, (idx, conf) in enumerate(zip(top5_ids, top5_confs)):
                        if idx < len(self.classifier_labels):
                            food = self.classifier_labels[idx]
                            print(f"  {i+1}. {food} ({float(conf):.2%})")

                    if class_id < len(self.classifier_labels):
                        food_name = self.classifier_labels[class_id]
                        print(f"✓ 음식 감지 (분류 모델): {food_name} (신뢰도: {confidence:.2%})")
                        return self._get_nutrition_info(food_name, confidence)

        except Exception as e:
            print(f"⚠ 분류 모델 분석 실패: {e}")

        return None

    def _analyze_with_detection(self, image: Image.Image) -> Optional[NutritionInfo]:
        """Detection 모델로 이미지 분석 (fallback)"""
        try:
            results = self.detection_model.predict(image, verbose=False)

            if len(results) > 0:
                result = results[0]

                # Detection 모델 처리 (boxes 속성)
                if hasattr(result, 'boxes') and result.boxes is not None and len(result.boxes) > 0:
                    boxes = result.boxes
                    best_idx = boxes.conf.argmax()
                    class_id = int(boxes.cls[best_idx])
                    confidence = float(boxes.conf[best_idx])

                    if class_id < len(self.detection_labels):
                        food_name = self.detection_labels[class_id]
                        print(f"✓ 음식 감지 (Detection): {food_name} (신뢰도: {confidence:.2%})")
                        return self._get_nutrition_info(food_name, confidence)

                # Classification 결과가 있을 수도 있음
                elif hasattr(result, 'probs') and result.probs is not None:
                    probs = result.probs
                    class_id = int(probs.top1)
                    confidence = float(probs.top1conf)

                    if class_id < len(self.detection_labels):
                        food_name = self.detection_labels[class_id]
                        print(f"✓ 음식 감지 (Detection-Classification): {food_name} (신뢰도: {confidence:.2%})")
                        return self._get_nutrition_info(food_name, confidence)

        except Exception as e:
            print(f"⚠ Detection 모델 분석 실패: {e}")

        return None

    def _get_nutrition_from_sqlite(self, food_name: str, confidence: float) -> Optional[NutritionInfo]:
        """SQLite food_nutrition_db 테이블에서 실측 영양 정보 조회 (기본값으로 채워진 행은 제외)"""
        try:
            from app.database import SessionLocal
            from app.models.food_nutrition_db import FoodNutritionDB

            db = SessionLocal()
            try:
                row = db.query(FoodNutritionDB).filter(FoodNutritionDB.food_name == food_name).first()
            finally:
                db.close()
        except Exception as e:
            print(f"⚠ SQLite 영양 정보 조회 실패: {e}")
            return None

        if row is None:
            return None

        # update_nutrition_db.py가 넣은 기본값(300/15/40/10)은 실측값이 아니므로 건너뜀
        if (row.calories, row.protein, row.carbs, row.fat) == (300.0, 15.0, 40.0, 10.0):
            return None

        print(f"✓ SQLite 영양 정보 사용: {food_name}")
        return NutritionInfo(
            food_name=food_name,
            calories=row.calories or 0.0,
            protein=row.protein or 0.0,
            carbs=row.carbs or 0.0,
            fat=row.fat or 0.0,
            fiber=row.fiber or 0.0,
            confidence=confidence
        )

    def _get_nutrition_info(self, food_name: str, confidence: float = 1.0) -> Optional[NutritionInfo]:
        """음식 이름으로 영양 정보 가져오기 (SQLite 실측값 우선, 없으면 JSON)"""
        sqlite_info = self._get_nutrition_from_sqlite(food_name, confidence)
        if sqlite_info is not None:
            return sqlite_info

        if food_name not in self.nutrition_db:
            print(f"✗ 영양 정보 없음: {food_name}")
            return None

        nutrition = self.nutrition_db[food_name]

        # JSON 데이터의 키 매핑
        # e: 에너지(칼로리), cal: 탄수화물, fat: 지방, pro: 단백질, na: 나트륨
        return NutritionInfo(
            food_name=food_name,
            calories=nutrition.get("e", 0.0),
            protein=nutrition.get("pro", 0.0),
            carbs=nutrition.get("cal", 0.0),
            fat=nutrition.get("fat", 0.0),
            fiber=0.0,  # 파이버 정보가 없으므로 0으로 설정
            confidence=confidence  # 인식 신뢰도 추가
        )

    def save_image(self, image_base64: str, filename: str) -> str:
        """Base64 이미지를 파일로 저장"""
        upload_dir = "uploads"
        os.makedirs(upload_dir, exist_ok=True)

        filepath = os.path.join(upload_dir, filename)

        # Base64 디코딩 후 저장
        image_data = base64.b64decode(image_base64)
        with open(filepath, "wb") as f:
            f.write(image_data)

        return filepath

# 전역 인스턴스
nutrition_analyzer = NutritionAnalyzer()
