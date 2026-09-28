"""
음식 추천 서비스 (v2 - 노트북 알고리즘 통합)
- DB 기반 영양정보 조회
- 코사인 유사도 기반 음식 추천
- 사용자 히스토리 기반 개인화 추천
- 다양성 기반 추천 (threshold 적용)
- 사용자 식단 점수/등급 계산
- 향상된 추천 이유 생성
"""
import numpy as np
from typing import List, Dict, Optional, Tuple
from pathlib import Path
from datetime import datetime, timedelta
from collections import Counter
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.food_nutrition_db import FoodNutritionDB, UserFoodHistory
from app.models.food_record import FoodRecord

# 모델 경로 설정
MODEL_DIR = Path(__file__).parent.parent / "ml_models"
EMB_DB_PATH = MODEL_DIR / "EMB_DB.pkl"
LABELS_PATH = MODEL_DIR / "labels.txt"
YOLO_MODEL_PATH = MODEL_DIR / "best.pt"

# 기본 영양성분 데이터 (초기 DB 시딩용)
DEFAULT_NUTRITION_DATA: List[Dict] = [
    {"food_name": "가자미구이", "calories": 95, "protein": 20.1, "fat": 1.2, "carbs": 0, "sodium": 85, "food_type": "구이"},
    {"food_name": "갈비찜", "calories": 290, "protein": 24.5, "fat": 18.3, "carbs": 8.5, "sodium": 650, "food_type": "찜"},
    {"food_name": "갈비탕", "calories": 350, "protein": 28.0, "fat": 22.0, "carbs": 5.0, "sodium": 890, "food_type": "국"},
    {"food_name": "갈치구이", "calories": 150, "protein": 22.0, "fat": 6.5, "carbs": 0.5, "sodium": 120, "food_type": "구이"},
    {"food_name": "갈치조림", "calories": 180, "protein": 21.0, "fat": 7.0, "carbs": 8.0, "sodium": 680, "food_type": "조림"},
    {"food_name": "감자탕", "calories": 280, "protein": 20.0, "fat": 15.0, "carbs": 18.0, "sodium": 920, "food_type": "국"},
    {"food_name": "감자튀김", "calories": 312, "protein": 3.4, "fat": 15.0, "carbs": 41.0, "sodium": 210, "food_type": "튀김"},
    {"food_name": "고등어구이", "calories": 202, "protein": 23.0, "fat": 12.0, "carbs": 0, "sodium": 95, "food_type": "구이"},
    {"food_name": "고등어조림", "calories": 220, "protein": 22.0, "fat": 11.0, "carbs": 8.0, "sodium": 720, "food_type": "조림"},
    {"food_name": "고추장불고기", "calories": 280, "protein": 25.0, "fat": 14.0, "carbs": 12.0, "sodium": 580, "food_type": "볶음"},
    {"food_name": "곱창전골", "calories": 320, "protein": 22.0, "fat": 20.0, "carbs": 12.0, "sodium": 850, "food_type": "전골"},
    {"food_name": "김밥", "calories": 250, "protein": 7.5, "fat": 5.0, "carbs": 45.0, "sodium": 680, "food_type": "밥류"},
    {"food_name": "김치찌개", "calories": 120, "protein": 8.5, "fat": 6.0, "carbs": 8.0, "sodium": 1200, "food_type": "찌개"},
    {"food_name": "김치볶음밥", "calories": 380, "protein": 10.0, "fat": 12.0, "carbs": 58.0, "sodium": 850, "food_type": "밥류"},
    {"food_name": "깍두기", "calories": 32, "protein": 1.8, "fat": 0.3, "carbs": 6.0, "sodium": 980, "food_type": "김치"},
    {"food_name": "나주곰탕", "calories": 280, "protein": 22.0, "fat": 18.0, "carbs": 5.0, "sodium": 780, "food_type": "국"},
    {"food_name": "냉면", "calories": 450, "protein": 12.0, "fat": 3.0, "carbs": 92.0, "sodium": 1100, "food_type": "면류"},
    {"food_name": "닭갈비", "calories": 250, "protein": 26.0, "fat": 10.0, "carbs": 15.0, "sodium": 720, "food_type": "볶음"},
    {"food_name": "닭가슴살", "calories": 165, "protein": 31.0, "fat": 3.6, "carbs": 0, "sodium": 74, "food_type": "구이"},
    {"food_name": "닭볶음탕", "calories": 220, "protein": 24.0, "fat": 9.0, "carbs": 12.0, "sodium": 680, "food_type": "찜"},
    {"food_name": "대구뽈찜", "calories": 130, "protein": 22.0, "fat": 2.5, "carbs": 5.0, "sodium": 550, "food_type": "찜"},
    {"food_name": "대구탕", "calories": 95, "protein": 18.0, "fat": 1.5, "carbs": 3.0, "sodium": 680, "food_type": "국"},
    {"food_name": "된장찌개", "calories": 85, "protein": 6.5, "fat": 4.0, "carbs": 6.0, "sodium": 980, "food_type": "찌개"},
    {"food_name": "돈까스", "calories": 350, "protein": 22.0, "fat": 18.0, "carbs": 28.0, "sodium": 580, "food_type": "튀김"},
    {"food_name": "돼지갈비", "calories": 320, "protein": 22.0, "fat": 24.0, "carbs": 5.0, "sodium": 450, "food_type": "구이"},
    {"food_name": "돼지불백", "calories": 290, "protein": 24.0, "fat": 18.0, "carbs": 8.0, "sodium": 620, "food_type": "볶음"},
    {"food_name": "두부조림", "calories": 95, "protein": 8.0, "fat": 5.0, "carbs": 5.0, "sodium": 520, "food_type": "조림"},
    {"food_name": "떡볶이", "calories": 280, "protein": 5.0, "fat": 6.0, "carbs": 55.0, "sodium": 850, "food_type": "분식"},
    {"food_name": "라면", "calories": 500, "protein": 10.0, "fat": 16.0, "carbs": 78.0, "sodium": 1800, "food_type": "면류"},
    {"food_name": "막국수", "calories": 420, "protein": 10.0, "fat": 4.0, "carbs": 85.0, "sodium": 920, "food_type": "면류"},
    {"food_name": "만두", "calories": 230, "protein": 10.0, "fat": 10.0, "carbs": 26.0, "sodium": 480, "food_type": "분식"},
    {"food_name": "물회", "calories": 150, "protein": 18.0, "fat": 3.0, "carbs": 12.0, "sodium": 680, "food_type": "회"},
    {"food_name": "미역국", "calories": 45, "protein": 4.0, "fat": 2.0, "carbs": 4.0, "sodium": 720, "food_type": "국"},
    {"food_name": "비빔밥", "calories": 550, "protein": 18.0, "fat": 12.0, "carbs": 88.0, "sodium": 720, "food_type": "밥류"},
    {"food_name": "비빔냉면", "calories": 480, "protein": 12.0, "fat": 5.0, "carbs": 95.0, "sodium": 1050, "food_type": "면류"},
    {"food_name": "삼겹살", "calories": 518, "protein": 17.0, "fat": 50.0, "carbs": 0, "sodium": 75, "food_type": "구이"},
    {"food_name": "삼계탕", "calories": 380, "protein": 32.0, "fat": 22.0, "carbs": 15.0, "sodium": 680, "food_type": "국"},
    {"food_name": "샐러드", "calories": 120, "protein": 3.0, "fat": 8.0, "carbs": 10.0, "sodium": 180, "food_type": "채식"},
    {"food_name": "설렁탕", "calories": 280, "protein": 18.0, "fat": 18.0, "carbs": 8.0, "sodium": 850, "food_type": "국"},
    {"food_name": "소불고기", "calories": 270, "protein": 26.0, "fat": 15.0, "carbs": 8.0, "sodium": 520, "food_type": "볶음"},
    {"food_name": "송편", "calories": 180, "protein": 4.0, "fat": 3.0, "carbs": 35.0, "sodium": 120, "food_type": "디저트"},
    {"food_name": "순대", "calories": 245, "protein": 12.0, "fat": 14.0, "carbs": 18.0, "sodium": 520, "food_type": "분식"},
    {"food_name": "순두부찌개", "calories": 95, "protein": 7.0, "fat": 5.0, "carbs": 5.0, "sodium": 880, "food_type": "찌개"},
    {"food_name": "시금치나물", "calories": 35, "protein": 3.0, "fat": 1.5, "carbs": 3.0, "sodium": 320, "food_type": "채식"},
    {"food_name": "연어구이", "calories": 208, "protein": 25.0, "fat": 12.0, "carbs": 0, "sodium": 65, "food_type": "구이"},
    {"food_name": "연어회", "calories": 180, "protein": 24.0, "fat": 9.0, "carbs": 0, "sodium": 55, "food_type": "회"},
    {"food_name": "오징어볶음", "calories": 180, "protein": 18.0, "fat": 6.0, "carbs": 15.0, "sodium": 720, "food_type": "볶음"},
    {"food_name": "육개장", "calories": 180, "protein": 15.0, "fat": 10.0, "carbs": 8.0, "sodium": 1100, "food_type": "국"},
    {"food_name": "장어구이", "calories": 285, "protein": 22.0, "fat": 22.0, "carbs": 0, "sodium": 85, "food_type": "구이"},
    {"food_name": "잡채", "calories": 220, "protein": 5.0, "fat": 8.0, "carbs": 35.0, "sodium": 580, "food_type": "볶음"},
    {"food_name": "전복죽", "calories": 180, "protein": 8.0, "fat": 2.0, "carbs": 35.0, "sodium": 420, "food_type": "죽"},
    {"food_name": "제육볶음", "calories": 280, "protein": 22.0, "fat": 18.0, "carbs": 10.0, "sodium": 680, "food_type": "볶음"},
    {"food_name": "조개탕", "calories": 85, "protein": 12.0, "fat": 2.0, "carbs": 5.0, "sodium": 620, "food_type": "국"},
    {"food_name": "족발", "calories": 280, "protein": 28.0, "fat": 18.0, "carbs": 2.0, "sodium": 420, "food_type": "보쌈"},
    {"food_name": "짜장면", "calories": 650, "protein": 15.0, "fat": 18.0, "carbs": 105.0, "sodium": 1200, "food_type": "면류"},
    {"food_name": "짬뽕", "calories": 550, "protein": 18.0, "fat": 15.0, "carbs": 82.0, "sodium": 1500, "food_type": "면류"},
    {"food_name": "찜닭", "calories": 250, "protein": 28.0, "fat": 10.0, "carbs": 12.0, "sodium": 720, "food_type": "찜"},
    {"food_name": "청국장", "calories": 95, "protein": 8.0, "fat": 4.5, "carbs": 6.0, "sodium": 880, "food_type": "찌개"},
    {"food_name": "초밥", "calories": 280, "protein": 12.0, "fat": 5.0, "carbs": 48.0, "sodium": 520, "food_type": "밥류"},
    {"food_name": "추어탕", "calories": 180, "protein": 15.0, "fat": 8.0, "carbs": 12.0, "sodium": 920, "food_type": "국"},
    {"food_name": "칼국수", "calories": 420, "protein": 12.0, "fat": 5.0, "carbs": 80.0, "sodium": 980, "food_type": "면류"},
    {"food_name": "콩나물국", "calories": 35, "protein": 4.0, "fat": 1.0, "carbs": 3.0, "sodium": 620, "food_type": "국"},
    {"food_name": "탕수육", "calories": 380, "protein": 18.0, "fat": 18.0, "carbs": 38.0, "sodium": 520, "food_type": "튀김"},
    {"food_name": "파전", "calories": 280, "protein": 8.0, "fat": 15.0, "carbs": 30.0, "sodium": 620, "food_type": "전"},
    {"food_name": "해물파전", "calories": 320, "protein": 12.0, "fat": 16.0, "carbs": 32.0, "sodium": 680, "food_type": "전"},
    {"food_name": "햄버거", "calories": 540, "protein": 25.0, "fat": 28.0, "carbs": 45.0, "sodium": 980, "food_type": "양식"},
    {"food_name": "호박죽", "calories": 150, "protein": 3.0, "fat": 1.0, "carbs": 32.0, "sodium": 180, "food_type": "죽"},
]


def init_nutrition_db(db: Session):
    """DB에 기본 영양 데이터 초기화 (없으면 추가)"""
    existing_count = db.query(FoodNutritionDB).count()
    if existing_count > 0:
        print(f"✓ 영양 DB 이미 초기화됨: {existing_count}개 음식")
        return

    for food_data in DEFAULT_NUTRITION_DATA:
        food = FoodNutritionDB(
            food_name=food_data["food_name"],
            food_type=food_data.get("food_type"),
            calories=food_data.get("calories", 0),
            protein=food_data.get("protein", 0),
            fat=food_data.get("fat", 0),
            carbs=food_data.get("carbs", 0),
            sodium=food_data.get("sodium", 0),
        )
        db.add(food)

    db.commit()
    print(f"✓ 영양 DB 초기화 완료: {len(DEFAULT_NUTRITION_DATA)}개 음식")


def sync_food_records_to_nutrition_db(db: Session):
    """FoodRecord 테이블의 음식을 영양 DB에 동기화"""
    # FoodRecord에서 고유 음식명 가져오기
    food_records = db.query(
        FoodRecord.food_name,
        func.avg(FoodRecord.calories).label('avg_calories'),
        func.avg(FoodRecord.protein).label('avg_protein'),
        func.avg(FoodRecord.fat).label('avg_fat'),
        func.avg(FoodRecord.carbs).label('avg_carbs'),
    ).group_by(FoodRecord.food_name).all()

    added_count = 0
    for record in food_records:
        # 이미 영양 DB에 있는지 확인
        existing = db.query(FoodNutritionDB).filter(
            FoodNutritionDB.food_name == record.food_name
        ).first()

        if not existing:
            new_food = FoodNutritionDB(
                food_name=record.food_name,
                calories=record.avg_calories or 0,
                protein=record.avg_protein or 0,
                fat=record.avg_fat or 0,
                carbs=record.avg_carbs or 0,
                food_type="사용자 기록",
            )
            db.add(new_food)
            added_count += 1

    if added_count > 0:
        db.commit()
        print(f"✓ FoodRecord에서 {added_count}개 음식 동기화됨")


class FoodRecommendationService:
    def __init__(self, db: Session):
        self.db = db
        self.emb_db = None
        self.yolo_model = None
        self.labels = None
        self._load_models()

    def _load_models(self):
        """모델 및 임베딩 DB 로드"""
        if EMB_DB_PATH.exists():
            try:
                import pickle
                with open(EMB_DB_PATH, "rb") as f:
                    self.emb_db = pickle.load(f)
                print(f"EMB_DB loaded: {len(self.emb_db)} foods")
            except Exception as e:
                print(f"EMB_DB 로드 실패: {e}")

        if LABELS_PATH.exists():
            try:
                with open(LABELS_PATH, "r", encoding="utf-8") as f:
                    self.labels = [line.strip() for line in f.readlines()]
                print(f"Labels loaded: {len(self.labels)} classes")
            except Exception as e:
                print(f"Labels 로드 실패: {e}")

        if YOLO_MODEL_PATH.exists():
            try:
                from ultralytics import YOLO
                self.yolo_model = YOLO(str(YOLO_MODEL_PATH))
                print("YOLO model loaded")
            except Exception as e:
                print(f"YOLO 모델 로드 실패: {e}")

    def normalize_food_name(self, name: str) -> str:
        """음식명 정규화"""
        import unicodedata
        name = unicodedata.normalize("NFC", name)
        name = name.strip().replace(" ", "")
        return name

    def get_all_foods(self) -> List[FoodNutritionDB]:
        """DB에서 모든 음식 조회"""
        return self.db.query(FoodNutritionDB).all()

    def get_nutrition(self, food_name: str) -> Optional[Dict]:
        """음식 영양정보 조회 (DB에서)"""
        normalized = self.normalize_food_name(food_name)

        # 정확히 일치하는 경우
        food = self.db.query(FoodNutritionDB).filter(
            FoodNutritionDB.food_name == normalized
        ).first()

        if food:
            return self._food_to_dict(food)

        # 부분 일치 검색
        foods = self.db.query(FoodNutritionDB).filter(
            FoodNutritionDB.food_name.contains(normalized)
        ).all()

        if foods:
            return self._food_to_dict(foods[0])

        # 반대로 검색
        all_foods = self.db.query(FoodNutritionDB).all()
        for f in all_foods:
            if normalized in f.food_name or f.food_name in normalized:
                return self._food_to_dict(f)

        return None

    def _food_to_dict(self, food: FoodNutritionDB) -> Dict:
        """FoodNutritionDB 객체를 딕셔너리로 변환"""
        return {
            "food_name": food.food_name,
            "calories": food.calories or 0,
            "protein": food.protein or 0,
            "fat": food.fat or 0,
            "carbs": food.carbs or 0,
            "sodium": food.sodium or 0,
            "food_type": food.food_type or "",
            "fiber": food.fiber or 0,
            "sugar": food.sugar or 0,
        }

    def cosine_similarity(self, a: np.ndarray, b: np.ndarray) -> float:
        """코사인 유사도 계산"""
        norm_a = np.linalg.norm(a)
        norm_b = np.linalg.norm(b)
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return float(np.dot(a, b) / (norm_a * norm_b))

    def _create_nutrition_vector(self, nutrition: Dict) -> np.ndarray:
        """영양성분을 벡터로 변환"""
        return np.array([
            nutrition.get("calories", 0) / 500,
            nutrition.get("protein", 0) / 30,
            nutrition.get("fat", 0) / 30,
            nutrition.get("carbs", 0) / 100,
            nutrition.get("sodium", 0) / 1000,
        ])

    def recommend_similar_foods(
        self,
        food_name: str,
        top_k: int = 5,
        exclude_self: bool = True
    ) -> List[Dict]:
        """유사한 음식 추천 (코사인 유사도 기반, DB 사용)"""
        normalized = self.normalize_food_name(food_name)
        base_nutrition = self.get_nutrition(normalized)

        all_foods = self.get_all_foods()

        if not base_nutrition:
            # 영양정보가 없으면 랜덤 추천
            import random
            random.shuffle(all_foods)
            return [
                {
                    "food_name": f.food_name,
                    "similarity_score": 0.5,
                    "reason": "다양한 음식을 시도해보세요",
                    "nutrition": self._food_to_dict(f)
                }
                for f in all_foods[:top_k]
            ]

        base_vector = self._create_nutrition_vector(base_nutrition)
        base_type = base_nutrition.get("food_type", "")

        similarities = []
        for food in all_foods:
            if exclude_self and self.normalize_food_name(food.food_name) == normalized:
                continue

            food_dict = self._food_to_dict(food)
            food_vector = self._create_nutrition_vector(food_dict)
            sim = self.cosine_similarity(base_vector, food_vector)

            # 같은 음식 타입이면 가중치 추가
            if food.food_type == base_type and base_type:
                sim += 0.1

            similarities.append((food, sim, food_dict))

        similarities.sort(key=lambda x: x[1], reverse=True)

        recommendations = []
        for food, sim, food_dict in similarities[:top_k]:
            reason = self._generate_reason(normalized, food.food_name, base_nutrition, food_dict)
            recommendations.append({
                "food_name": food.food_name,
                "similarity_score": round(sim, 3),
                "reason": reason,
                "nutrition": food_dict
            })

        return recommendations

    def recommend_diverse_foods(self, food_name: str, top_k: int = 5) -> List[Dict]:
        """다양한 음식 추천 (낮은 유사도)"""
        normalized = self.normalize_food_name(food_name)
        base_nutrition = self.get_nutrition(normalized)

        all_foods = self.get_all_foods()

        if not base_nutrition:
            import random
            random.shuffle(all_foods)
            return [
                {
                    "food_name": f.food_name,
                    "similarity_score": 0.3,
                    "reason": "새로운 음식에 도전해보세요",
                    "nutrition": self._food_to_dict(f)
                }
                for f in all_foods[:top_k]
            ]

        base_vector = self._create_nutrition_vector(base_nutrition)

        similarities = []
        for food in all_foods:
            if self.normalize_food_name(food.food_name) == normalized:
                continue

            food_dict = self._food_to_dict(food)
            food_vector = self._create_nutrition_vector(food_dict)
            sim = self.cosine_similarity(base_vector, food_vector)
            similarities.append((food, sim, food_dict))

        # 유사도 낮은 순 정렬
        similarities.sort(key=lambda x: x[1])

        recommendations = []
        for food, sim, food_dict in similarities[:top_k]:
            recommendations.append({
                "food_name": food.food_name,
                "similarity_score": round(1 - sim, 3),
                "reason": f"'{food_name}'와 다른 스타일의 음식이에요",
                "nutrition": food_dict
            })

        return recommendations

    def _generate_reason(
        self,
        base_name: str,
        rec_name: str,
        base_nutrition: Dict,
        rec_nutrition: Dict
    ) -> str:
        """추천 이유 생성"""
        reasons = []

        if base_nutrition.get("food_type") == rec_nutrition.get("food_type"):
            food_type = base_nutrition.get("food_type", "")
            if food_type:
                reasons.append(f"같은 {food_type} 종류")

        if rec_nutrition.get("protein", 0) > base_nutrition.get("protein", 0) + 5:
            reasons.append("단백질이 더 풍부해요")

        if rec_nutrition.get("calories", 0) < base_nutrition.get("calories", 0) - 50:
            reasons.append("칼로리가 더 낮아요")

        if rec_nutrition.get("sodium", 0) < base_nutrition.get("sodium", 0) - 200:
            reasons.append("나트륨이 적어요")

        if not reasons:
            reasons.append(f"'{base_name}'와 비슷한 영양 구성")

        return ", ".join(reasons)

    def recommend_by_user_history(
        self,
        user_id: Optional[int] = None,
        top_k: int = 5
    ) -> List[Dict]:
        """사용자 식사 기록 기반 추천 (DB에서 조회)"""
        # FoodRecord에서 사용자 기록 가져오기
        query = self.db.query(FoodRecord)
        if user_id is not None:
            query = query.filter(FoodRecord.user_id == user_id)
        food_records = query.order_by(FoodRecord.created_at.desc()).limit(30).all()

        if not food_records:
            # 기록이 없으면 DB에서 랜덤 음식 추천
            all_foods = self.get_all_foods()
            if not all_foods:
                return []

            import random
            random.shuffle(all_foods)
            recommendations = []
            for food in all_foods[:top_k]:
                recommendations.append({
                    "food_name": food.food_name,
                    "similarity_score": 0.8,
                    "reason": "DB에 등록된 음식입니다",
                    "nutrition": self._food_to_dict(food)
                })
            return recommendations

        # 사용자 평균 영양 벡터 계산
        user_vectors = []
        eaten_foods = set()

        for record in food_records:
            eaten_foods.add(self.normalize_food_name(record.food_name))
            nutrition = {
                "calories": record.calories or 0,
                "protein": record.protein or 0,
                "fat": record.fat or 0,
                "carbs": record.carbs or 0,
                "sodium": 0,
            }
            user_vectors.append(self._create_nutrition_vector(nutrition))

        if not user_vectors:
            # DB에서 첫 번째 음식 기준으로 추천
            all_foods = self.get_all_foods()
            if all_foods:
                return self.recommend_similar_foods(all_foods[0].food_name, top_k)
            return []

        user_avg_vector = np.mean(user_vectors, axis=0)

        # 안 먹은 음식 중에서 추천
        all_foods = self.get_all_foods()
        recommendations = []

        for food in all_foods:
            if self.normalize_food_name(food.food_name) in eaten_foods:
                continue

            food_dict = self._food_to_dict(food)
            food_vector = self._create_nutrition_vector(food_dict)
            sim = self.cosine_similarity(user_avg_vector, food_vector)

            recommendations.append({
                "food_name": food.food_name,
                "similarity_score": round(sim, 3),
                "reason": "평소 식습관과 잘 맞는 음식",
                "nutrition": food_dict
            })

        recommendations.sort(key=lambda x: x["similarity_score"], reverse=True)
        return recommendations[:top_k]

    def recommend_balanced(
        self,
        user_id: Optional[int] = None,
        top_k: int = 5
    ) -> List[Dict]:
        """영양 균형을 고려한 추천 (DB 기반)"""
        # 최근 식사 기록 가져오기
        query = self.db.query(FoodRecord)
        if user_id is not None:
            query = query.filter(FoodRecord.user_id == user_id)
        food_records = query.order_by(
            FoodRecord.created_at.desc()
        ).limit(10).all()

        if not food_records:
            return self.recommend_by_user_history(user_id, top_k)

        # 최근 섭취 영양소 합계
        total_calories = sum(r.calories or 0 for r in food_records)
        total_protein = sum(r.protein or 0 for r in food_records)
        total_carbs = sum(r.carbs or 0 for r in food_records)
        total_fat = sum(r.fat or 0 for r in food_records)

        eaten_foods = {self.normalize_food_name(r.food_name) for r in food_records}
        all_foods = self.get_all_foods()

        recommendations = []

        for food in all_foods:
            if self.normalize_food_name(food.food_name) in eaten_foods:
                continue

            food_dict = self._food_to_dict(food)
            score = 0.5
            reasons = []

            # 단백질 부족
            if total_protein < 50:
                if food_dict.get("protein", 0) > 20:
                    score += 0.2
                    reasons.append("단백질 보충")

            # 칼로리 과다
            if total_calories > 1500:
                if food_dict.get("calories", 0) < 200:
                    score += 0.15
                    reasons.append("저칼로리")

            # 탄수화물 과다
            if total_carbs > 200:
                if food_dict.get("carbs", 0) < 20:
                    score += 0.15
                    reasons.append("저탄수화물")

            # 지방 과다
            if total_fat > 60:
                if food_dict.get("fat", 0) < 10:
                    score += 0.1
                    reasons.append("저지방")

            recommendations.append({
                "food_name": food.food_name,
                "similarity_score": round(score, 3),
                "reason": ", ".join(reasons) if reasons else "균형 잡힌 영양",
                "nutrition": food_dict
            })

        recommendations.sort(key=lambda x: x["similarity_score"], reverse=True)
        return recommendations[:top_k]

    # ========================================
    # 노트북 알고리즘 통합 (v2 기능들)
    # ========================================

    def recommend_diverse_v2(
        self,
        food_name: str,
        user_id: Optional[int] = None,
        top_k: int = 5,
        threshold: float = 0.5
    ) -> List[Dict]:
        """
        다양성 기반 추천 (노트북 recommend_diverse 알고리즘)
        - 유사도가 threshold 이상인 음식은 제외
        - 사용자 프로필과 예측 음식을 blend
        """
        normalized = self.normalize_food_name(food_name)
        base_nutrition = self.get_nutrition(normalized)

        if not base_nutrition:
            return self.recommend_diverse_foods(food_name, top_k)

        base_vector = self._create_nutrition_vector(base_nutrition)

        # 사용자 프로필 생성 (있으면)
        user_vector = self._build_user_profile(user_id)

        # 쿼리 벡터: 예측 음식 0.8 + 사용자 0.2 blend
        if user_vector is not None:
            query_vector = 0.8 * base_vector + 0.2 * user_vector
            query_vector = query_vector / (np.linalg.norm(query_vector) + 1e-6)
        else:
            query_vector = base_vector

        all_foods = self.get_all_foods()
        candidates = []

        for food in all_foods:
            if self.normalize_food_name(food.food_name) == normalized:
                continue

            food_dict = self._food_to_dict(food)
            food_vector = self._create_nutrition_vector(food_dict)
            sim = self.cosine_similarity(query_vector, food_vector)

            # 핵심: 유사도가 높은 음식은 제외 (다양성 확보)
            if sim >= threshold:
                continue

            candidates.append((food, sim, food_dict))

        # 유사도 기준 내림차순 (threshold 이하 중 가장 높은 것부터)
        candidates.sort(key=lambda x: x[1], reverse=True)

        recommendations = []
        for food, sim, food_dict in candidates[:top_k]:
            reason = self._generate_reason_advanced(
                normalized, food.food_name, base_nutrition, food_dict, user_id
            )
            recommendations.append({
                "food_name": food.food_name,
                "similarity_score": round(sim, 3),
                "reason": reason,
                "nutrition": food_dict
            })

        return recommendations

    def _build_user_profile(self, user_id: Optional[int] = None) -> Optional[np.ndarray]:
        """
        사용자 식사 기록 기반 프로필 벡터 생성 (요일별 가중치 적용)
        - 노트북의 build_user_embedding 알고리즘 적용
        """
        # 최근 7일 기록 가져오기
        seven_days_ago = datetime.now() - timedelta(days=7)

        query = self.db.query(FoodRecord).filter(
            FoodRecord.created_at >= seven_days_ago
        )
        if user_id is not None:
            query = query.filter(FoodRecord.user_id == user_id)
        query = query.order_by(FoodRecord.created_at.desc())

        records = query.all()

        if not records:
            return None

        # 요일별 가중치 (노트북 기준)
        day_weights = {
            0: 1.0,  # 월요일 (또는 1일차)
            1: 0.3,
            2: 0.4,
            3: 0.5,
            4: 0.6,
            5: 0.7,
            6: 1.0,  # 일요일 (또는 7일차)
        }

        vectors = []
        weights = []

        for record in records:
            nutrition = {
                "calories": record.calories or 0,
                "protein": record.protein or 0,
                "fat": record.fat or 0,
                "carbs": record.carbs or 0,
                "sodium": 0,
            }
            vec = self._create_nutrition_vector(nutrition)

            # 요일 기반 가중치
            day_of_week = record.created_at.weekday() if record.created_at else 0
            w = day_weights.get(day_of_week, 0.5)

            vectors.append(vec)
            weights.append(w)

        if not vectors:
            return None

        vectors = np.array(vectors)
        weights = np.array(weights).reshape(-1, 1)

        # 가중 평균
        user_vector = (vectors * weights).sum(axis=0) / weights.sum()
        user_vector = user_vector / (np.linalg.norm(user_vector) + 1e-6)

        return user_vector

    def _generate_reason_advanced(
        self,
        base_name: str,
        rec_name: str,
        base_nutrition: Dict,
        rec_nutrition: Dict,
        user_id: Optional[int] = None
    ) -> str:
        """
        향상된 추천 이유 생성 (노트북 generate_reason_new 알고리즘)
        """
        reasons = []

        # 1. 유사도 기반 다양성
        base_vec = self._create_nutrition_vector(base_nutrition)
        rec_vec = self._create_nutrition_vector(rec_nutrition)
        sim = self.cosine_similarity(base_vec, rec_vec)

        if sim < 0.55:
            reasons.append("이전 음식과 거리가 있는 메뉴로 식단에 다양성을 더해줍니다")

        # 2. 최근 음식과 겹치지 않음 확인
        if user_id is not None:
            recent_foods = self._get_recent_foods(user_id, days=3)
            rec_normalized = self.normalize_food_name(rec_name)

            if rec_normalized not in recent_foods:
                max_sim = 0
                for recent in recent_foods:
                    recent_nut = self.get_nutrition(recent)
                    if recent_nut:
                        recent_vec = self._create_nutrition_vector(recent_nut)
                        s = self.cosine_similarity(rec_vec, recent_vec)
                        max_sim = max(max_sim, s)

                if max_sim < 0.55:
                    reasons.append("최근 드신 음식과 겹치지 않아 새로운 메뉴로 전환하기 좋습니다")

        # 3. 영양 밸런스 비교
        if rec_nutrition.get("calories", 0) < base_nutrition.get("calories", 0) - 50:
            reasons.append("더 가벼운 구성으로 영양 밸런스를 맞추기 좋은 메뉴입니다")

        if rec_nutrition.get("protein", 0) > base_nutrition.get("protein", 0) + 5:
            reasons.append("단백질이 더 풍부해요")

        if rec_nutrition.get("sodium", 0) < base_nutrition.get("sodium", 0) - 200:
            reasons.append("나트륨이 적어 건강에 좋아요")

        # Fallback
        if not reasons:
            reasons.append("지금과는 다른 느낌의 메뉴로 선택 폭을 넓혀주는 추천입니다")

        return " ".join(reasons)

    def _get_recent_foods(self, user_id: Optional[int], days: int = 3) -> set:
        """최근 N일간 먹은 음식 목록"""
        cutoff = datetime.now() - timedelta(days=days)
        query = self.db.query(FoodRecord).filter(
            FoodRecord.created_at >= cutoff
        )
        if user_id is not None:
            query = query.filter(FoodRecord.user_id == user_id)
        records = query.all()

        return {self.normalize_food_name(r.food_name) for r in records}

    def compute_user_score(self, user_id: Optional[int] = None, days: int = 7) -> Dict:
        """
        사용자 식단 점수/등급 계산 (노트북 compute_user_score 알고리즘)

        Returns:
            {
                "score": float (0-100),
                "grade": str (A/B/C/D/F),
                "details": {
                    "food_score": float,
                    "nutrition_score": float,
                    "habit_score": float,
                },
                "feedback": List[str]
            }
        """
        cutoff = datetime.now() - timedelta(days=days)
        query = self.db.query(FoodRecord).filter(FoodRecord.created_at >= cutoff)
        if user_id is not None:
            query = query.filter(FoodRecord.user_id == user_id)
        records = query.order_by(FoodRecord.created_at).all()

        if not records:
            return {
                "score": 50,
                "grade": "C",
                "details": {"food_score": 0, "nutrition_score": 0, "habit_score": 0},
                "feedback": ["식사 기록이 없습니다. 식단을 기록해보세요!"]
            }

        # 1. 음식 점수 평균
        food_scores = []
        total_calories = 0
        total_protein = 0
        total_fat = 0
        total_carbs = 0
        eaten_foods = []

        for record in records:
            score = self._compute_food_score(record)
            food_scores.append(score)

            total_calories += record.calories or 0
            total_protein += record.protein or 0
            total_fat += record.fat or 0
            total_carbs += record.carbs or 0
            eaten_foods.append(self.normalize_food_name(record.food_name))

        food_mean = np.mean(food_scores) if food_scores else 50

        # 2. 영양 비율 점수
        macro_sum = total_calories + total_fat + total_protein
        if macro_sum == 0:
            nutrition_score = 60
        else:
            carb_r = total_calories / macro_sum if macro_sum > 0 else 0
            prot_r = total_protein / macro_sum if macro_sum > 0 else 0
            fat_r = total_fat / macro_sum if macro_sum > 0 else 0

            # 이상적 비율: 탄수화물 50%, 단백질 20%, 지방 30%
            nutrition_score = (
                (1 - abs(carb_r - 0.50)) +
                (1 - abs(prot_r - 0.20)) +
                (1 - abs(fat_r - 0.30))
            ) / 3 * 100

        # 3. 습관 점수
        habit_score = 100
        feedback = []

        # 결식 감점 (하루 3끼 기준, 7일 = 21끼)
        expected_meals = days * 3
        actual_meals = len(records)
        missing_meals = max(0, expected_meals - actual_meals)

        if missing_meals > 3:
            habit_score -= missing_meals * 1.5
            feedback.append(f"최근 {days}일간 {missing_meals}끼 정도 결식이 있었어요. 규칙적인 식사가 중요해요!")

        # 같은 음식 반복 감점
        food_counter = Counter(eaten_foods)
        for food, count in food_counter.items():
            if count >= 4:
                habit_score -= (count - 3) * 2
                feedback.append(f"'{food}'을(를) 자주 드시네요. 다양한 음식을 시도해보세요!")

        # 야식/늦은 식사 감점 (22시 이후)
        late_meals = sum(1 for r in records if r.created_at and r.created_at.hour >= 22)
        if late_meals > 2:
            habit_score -= late_meals * 2
            feedback.append("늦은 시간 식사가 많아요. 저녁 식사는 일찍 하는 것이 좋아요!")

        habit_score = max(0, min(100, habit_score))

        # 4. 최종 점수 계산 (가중 평균)
        final_score = 0.3 * food_mean + 0.4 * nutrition_score + 0.3 * habit_score
        final_score = max(0, min(100, final_score))

        # 5. 등급 결정
        def get_grade(score):
            if score >= 80:
                return "A"
            elif score >= 65:
                return "B"
            elif score >= 50:
                return "C"
            elif score >= 30:
                return "D"
            return "F"

        grade = get_grade(final_score)

        # 피드백 추가
        if grade == "A":
            feedback.insert(0, "훌륭한 식단 관리를 하고 계세요! 계속 유지해주세요!")
        elif grade == "B":
            feedback.insert(0, "좋은 식습관을 가지고 계세요. 조금만 더 신경 쓰면 완벽해요!")
        elif grade == "C":
            feedback.insert(0, "평균적인 식단이에요. 조금 더 다양한 영양소 섭취를 권장해요.")
        elif grade in ("D", "F"):
            feedback.insert(0, "식단 개선이 필요해요. 균형 잡힌 식사를 시작해보세요!")

        return {
            "score": round(final_score, 1),
            "grade": grade,
            "details": {
                "food_score": round(food_mean, 1),
                "nutrition_score": round(nutrition_score, 1),
                "habit_score": round(habit_score, 1),
            },
            "feedback": feedback,
            "stats": {
                "total_meals": len(records),
                "total_calories": round(total_calories, 1),
                "total_protein": round(total_protein, 1),
                "total_carbs": round(total_carbs, 1),
                "total_fat": round(total_fat, 1),
            }
        }

    def _compute_food_score(self, record: FoodRecord) -> float:
        """
        개별 음식 점수 계산 (노트북 compute_food_score 알고리즘)
        """
        # 영양성분 가중치
        nut_weights = {
            "carbs": +1,      # 탄수화물
            "protein": +2,    # 단백질
            "fat": -1,        # 지방
            "sodium": -2,     # 나트륨 (mg 단위이므로 조정)
        }

        base_score = 0

        # 칼로리 정규화 (100-500 범위 기준)
        cal = record.calories or 0
        if cal > 0:
            cal_norm = min(cal / 500, 1.0)
            base_score += cal_norm * 1

        # 단백질 (높을수록 좋음)
        pro = record.protein or 0
        if pro > 15:
            base_score += 2
        elif pro > 10:
            base_score += 1

        # 지방 (너무 높으면 감점)
        fat = record.fat or 0
        if fat > 20:
            base_score -= 1

        # 탄수화물 (적절하면 가점)
        carbs = record.carbs or 0
        if 20 <= carbs <= 60:
            base_score += 1
        elif carbs > 80:
            base_score -= 1

        # 점수 정규화 (0-100)
        score = 50 + base_score * 5
        return max(0, min(100, score))

    # ========================================
    # EMB_DB 기반 임베딩 추천 (노트북 원본 알고리즘)
    # ========================================

    def recommend_by_embedding(self, food_name: str, top_k: int = 5) -> List[Dict]:
        """
        EMB_DB 임베딩 기반 유사 음식 추천 (노트북 recommend_by_embedding)
        - 1305차원 임베딩 벡터 사용 (이미지+텍스트+영양+타입)
        """
        if self.emb_db is None:
            # EMB_DB 없으면 기존 방식 fallback
            return self.recommend_similar_foods(food_name, top_k)

        normalized = self.normalize_food_name(food_name)

        if normalized not in self.emb_db:
            # EMB_DB에 없으면 기존 방식 fallback
            return self.recommend_similar_foods(food_name, top_k)

        query_emb = self.emb_db[normalized]
        sims = []

        for food, emb in self.emb_db.items():
            if food == normalized:
                continue
            sim = self.cosine_similarity(query_emb, emb)
            sims.append((food, sim))

        sims.sort(key=lambda x: x[1], reverse=True)

        recommendations = []
        for food_name_rec, sim in sims[:top_k]:
            nutrition = self.get_nutrition(food_name_rec)
            recommendations.append({
                "food_name": food_name_rec,
                "similarity_score": round(sim, 3),
                "reason": f"'{food_name}'과 맛/재료 프로필이 유사합니다",
                "nutrition": nutrition or {}
            })

        return recommendations

    def recommend_opposite_by_embedding(self, food_name: str, top_k: int = 5) -> List[Dict]:
        """
        EMB_DB 기반 반대 계열 음식 추천 (노트북 recommend_opposite_by_embedding)
        - 유사도가 낮은 순으로 정렬
        """
        if self.emb_db is None:
            return self.recommend_diverse_foods(food_name, top_k)

        normalized = self.normalize_food_name(food_name)

        if normalized not in self.emb_db:
            return self.recommend_diverse_foods(food_name, top_k)

        query_emb = self.emb_db[normalized]
        sims = []

        for food, emb in self.emb_db.items():
            if food == normalized:
                continue
            sim = self.cosine_similarity(query_emb, emb)
            sims.append((food, sim))

        # 유사도 낮은 순 정렬
        sims.sort(key=lambda x: x[1])

        recommendations = []
        for food_name_rec, sim in sims[:top_k]:
            nutrition = self.get_nutrition(food_name_rec)
            recommendations.append({
                "food_name": food_name_rec,
                "similarity_score": round(sim, 3),
                "reason": "다양한 영양소 섭취를 위한 반대 계열 추천입니다",
                "nutrition": nutrition or {}
            })

        return recommendations

    def recommend_diverse_embedding(
        self,
        food_name: str,
        user_id: Optional[int] = None,
        top_k: int = 5,
        threshold: float = 0.50
    ) -> List[Dict]:
        """
        EMB_DB 기반 다양성 추천 (노트북 recommend_diverse 원본)
        - 유사도가 threshold 이상인 음식은 제외
        - 사용자 프로필과 blend
        """
        if self.emb_db is None:
            return self.recommend_diverse_v2(food_name, user_id, top_k, threshold)

        normalized = self.normalize_food_name(food_name)

        if normalized not in self.emb_db:
            return self.recommend_diverse_v2(food_name, user_id, top_k, threshold)

        pred_emb = self.emb_db[normalized]

        # 사용자 임베딩 생성 (있으면)
        user_emb = self._build_user_embedding_from_emb_db(user_id)

        # 쿼리: pred 0.8 + user 0.2 blend
        if user_emb is not None:
            query = 0.8 * pred_emb + 0.2 * user_emb
            query = query / (np.linalg.norm(query) + 1e-6)
        else:
            query = pred_emb

        candidates = []

        for food, emb in self.emb_db.items():
            if food == normalized:
                continue

            sim = self.cosine_similarity(query, emb)

            # 유사도가 높은 음식은 제외 (다양성 확보)
            if sim >= threshold:
                continue

            candidates.append((food, sim))

        # threshold 이하 중 가장 높은 것부터
        candidates.sort(key=lambda x: x[1], reverse=True)

        recommendations = []
        for food_name_rec, sim in candidates[:top_k]:
            nutrition = self.get_nutrition(food_name_rec)
            reason = self._generate_reason_embedding(
                normalized, food_name_rec, sim, user_id
            )
            recommendations.append({
                "food_name": food_name_rec,
                "similarity_score": round(sim, 3),
                "reason": reason,
                "nutrition": nutrition or {}
            })

        return recommendations

    def _build_user_embedding_from_emb_db(self, user_id: Optional[int] = None) -> Optional[np.ndarray]:
        """
        사용자 식사 기록에서 EMB_DB 임베딩 기반 프로필 생성
        """
        if self.emb_db is None:
            return None

        seven_days_ago = datetime.now() - timedelta(days=7)
        query = self.db.query(FoodRecord).filter(
            FoodRecord.created_at >= seven_days_ago
        )
        if user_id is not None:
            query = query.filter(FoodRecord.user_id == user_id)
        records = query.all()

        if not records:
            return None

        # 요일별 가중치
        day_weights = {0: 1.0, 1: 0.3, 2: 0.4, 3: 0.5, 4: 0.6, 5: 0.7, 6: 1.0}

        embs = []
        weights = []

        for record in records:
            food_normalized = self.normalize_food_name(record.food_name)
            if food_normalized in self.emb_db:
                embs.append(self.emb_db[food_normalized])
                day = record.created_at.weekday() if record.created_at else 0
                weights.append(day_weights.get(day, 0.5))

        if not embs:
            return None

        embs = np.array(embs)
        weights = np.array(weights).reshape(-1, 1)

        user_emb = (embs * weights).sum(axis=0) / weights.sum()
        user_emb = user_emb / (np.linalg.norm(user_emb) + 1e-6)

        return user_emb

    def _generate_reason_embedding(
        self,
        base_name: str,
        rec_name: str,
        sim: float,
        user_id: Optional[int] = None
    ) -> str:
        """EMB_DB 기반 추천 이유 생성"""
        reasons = []

        if sim < 0.55:
            reasons.append("이전 음식과 거리가 있는 메뉴로 식단에 다양성을 더해줍니다")

        # 최근 음식과 겹치지 않음 확인
        recent_foods = self._get_recent_foods(user_id, days=3)
        rec_normalized = self.normalize_food_name(rec_name)

        if rec_normalized not in recent_foods:
            if self.emb_db and rec_normalized in self.emb_db:
                rec_emb = self.emb_db[rec_normalized]
                max_sim = 0
                for recent in recent_foods:
                    if recent in self.emb_db:
                        s = self.cosine_similarity(rec_emb, self.emb_db[recent])
                        max_sim = max(max_sim, s)
                if max_sim < 0.55:
                    reasons.append("최근 드신 음식과 겹치지 않아 새로운 메뉴로 전환하기 좋습니다")

        if not reasons:
            reasons.append("지금과는 다른 느낌의 메뉴로 선택 폭을 넓혀주는 추천입니다")

        return " ".join(reasons)

    def get_emb_db_foods(self) -> List[str]:
        """EMB_DB에 있는 음식 목록 반환"""
        if self.emb_db is None:
            return []
        return list(self.emb_db.keys())


def get_recommendation_service(db: Session) -> FoodRecommendationService:
    """DB 세션을 받아서 서비스 인스턴스 생성"""
    return FoodRecommendationService(db)
