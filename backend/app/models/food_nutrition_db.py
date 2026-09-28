from sqlalchemy import Column, Integer, String, Float
from app.models.food_record import Base


class FoodNutritionDB(Base):
    """음식별 영양성분 데이터베이스 (노트북의 영양성분 룩업 테이블)"""
    __tablename__ = "food_nutrition_db"

    id = Column(Integer, primary_key=True, index=True)
    food_name = Column(String, unique=True, index=True, nullable=False)
    food_type = Column(String, nullable=True)  # 찜/볶음/회/국/구이/채식 등

    # 기본 영양성분 (100g 기준)
    calories = Column(Float, default=0.0)  # 칼로리 (kcal)
    energy = Column(Float, default=0.0)  # 에너지 (kJ)
    protein = Column(Float, default=0.0)  # 단백질 (g)
    fat = Column(Float, default=0.0)  # 지질 (g)
    carbs = Column(Float, default=0.0)  # 탄수화물 (g)
    sugar = Column(Float, default=0.0)  # 당류 (g)
    fiber = Column(Float, default=0.0)  # 식이섬유 (g)

    # 추가 영양성분
    sodium = Column(Float, default=0.0)  # 나트륨 (mg)
    cholesterol = Column(Float, default=0.0)  # 콜레스테롤 (mg)
    saturated_fat = Column(Float, default=0.0)  # 포화지방 (g)
    trans_fat = Column(Float, default=0.0)  # 트랜스지방 (g)

    # 메타 정보
    serving_size = Column(Float, default=100.0)  # 1회 제공량 (g)
    category = Column(String, nullable=True)  # 음식 카테고리


class FoodEmbedding(Base):
    """음식 임베딩 벡터 저장 (추천 시스템용)"""
    __tablename__ = "food_embeddings"

    id = Column(Integer, primary_key=True, index=True)
    food_name = Column(String, unique=True, index=True, nullable=False)
    embedding_vector = Column(String, nullable=True)  # JSON 직렬화된 벡터
    image_embedding = Column(String, nullable=True)  # 이미지 특징 벡터
    text_embedding = Column(String, nullable=True)  # 텍스트 임베딩 벡터


class UserFoodHistory(Base):
    """사용자 식사 기록 (추천용)"""
    __tablename__ = "user_food_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    food_name = Column(String, nullable=False)
    meal_type = Column(String, nullable=True)  # 아침/점심/저녁/야식
    date = Column(String, nullable=False)  # YYYY-MM-DD
    calories = Column(Float, default=0.0)
    protein = Column(Float, default=0.0)
    carbs = Column(Float, default=0.0)
    fat = Column(Float, default=0.0)
