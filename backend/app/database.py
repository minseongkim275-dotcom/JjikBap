from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.food_record import Base
from app.models.nutrition_goal import NutritionGoal  # Import to register table
from app.models.post import Post  # Import to register posts table
from app.models.food_nutrition_db import FoodNutritionDB, FoodEmbedding, UserFoodHistory  # 음식 추천 관련
from app.models.excluded_food import ExcludedFood  # 제외된 음식
from app.models.user import User  # 사용자

DATABASE_URL = "sqlite:///./jjikbap.db"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
