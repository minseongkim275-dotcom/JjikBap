from pydantic import BaseModel
from typing import List, Optional, Dict


class FoodNutritionCreate(BaseModel):
    food_name: str
    food_type: Optional[str] = None
    calories: float = 0.0
    energy: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    carbs: float = 0.0
    sugar: float = 0.0
    fiber: float = 0.0
    sodium: float = 0.0
    cholesterol: float = 0.0
    saturated_fat: float = 0.0
    trans_fat: float = 0.0
    serving_size: float = 100.0
    category: Optional[str] = None


class FoodNutritionResponse(BaseModel):
    id: int
    food_name: str
    food_type: Optional[str]
    calories: float
    energy: float
    protein: float
    fat: float
    carbs: float
    sugar: float
    fiber: float
    sodium: float
    cholesterol: float
    saturated_fat: float
    trans_fat: float
    serving_size: float
    category: Optional[str]

    class Config:
        from_attributes = True


class UserHistoryCreate(BaseModel):
    user_id: int
    food_name: str
    meal_type: Optional[str] = None  # 아침/점심/저녁/야식
    date: str  # YYYY-MM-DD
    calories: float = 0.0
    protein: float = 0.0
    carbs: float = 0.0
    fat: float = 0.0


class UserHistoryResponse(BaseModel):
    id: int
    user_id: int
    food_name: str
    meal_type: Optional[str]
    date: str
    calories: float
    protein: float
    carbs: float
    fat: float

    class Config:
        from_attributes = True


class FoodRecommendation(BaseModel):
    food_name: str
    similarity_score: float
    reason: str
    nutrition: Optional[Dict] = None


class RecommendationRequest(BaseModel):
    user_id: Optional[int] = None
    current_food: Optional[str] = None  # 현재 인식된 음식
    top_k: int = 5


class RecommendationResponse(BaseModel):
    recommendations: List[FoodRecommendation]
    user_stats: Optional[Dict] = None


class ImageClassifyRequest(BaseModel):
    image_base64: str


class ImageClassifyResponse(BaseModel):
    food_name: str
    confidence: float
    nutrition: Optional[FoodNutritionResponse] = None
    recommendations: Optional[List[FoodRecommendation]] = None
