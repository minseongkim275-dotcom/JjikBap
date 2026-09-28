from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class NutritionInfo(BaseModel):
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: float
    confidence: float = 1.0  # 인식 신뢰도 (0.0 ~ 1.0)

class FoodRecordCreate(BaseModel):
    user_id: Optional[int] = None
    food_name: str
    calories: float = 0.0
    protein: float = 0.0
    carbs: float = 0.0
    fat: float = 0.0
    fiber: float = 0.0
    image_path: Optional[str] = None
    description: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    rating: Optional[int] = None

class FoodRecordResponse(BaseModel):
    id: int
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: float
    image_path: Optional[str]
    description: Optional[str]
    created_at: datetime
    latitude: Optional[float]
    longitude: Optional[float]
    rating: Optional[int]
    score: Optional[float] = None  # 개별 음식 점수 (백엔드 계산)
    grade: Optional[str] = None    # 개별 음식 등급 (백엔드 계산)

    class Config:
        from_attributes = True

class AnalyzeRequest(BaseModel):
    text: Optional[str] = None
    image_base64: Optional[str] = None

class FoodSuggestion(BaseModel):
    food_name: str
    match_score: float  # 매칭 점수 (0.0 ~ 1.0)

class SearchFoodResponse(BaseModel):
    query: str
    suggestions: list[FoodSuggestion]  # 여러 음식 제안
