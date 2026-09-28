from pydantic import BaseModel
from datetime import date
from typing import Optional

class NutritionGoalBase(BaseModel):
    calories: float = 2000.0
    protein: float = 50.0
    carbs: float = 250.0
    fat: float = 65.0
    fiber: float = 25.0
    target_date: Optional[date] = None

class NutritionGoalCreate(NutritionGoalBase):
    date: Optional[date] = None

class NutritionGoalResponse(NutritionGoalBase):
    id: int
    date: date

    class Config:
        from_attributes = True

class DailyStats(BaseModel):
    date: date
    consumed_calories: float
    consumed_protein: float
    consumed_carbs: float
    consumed_fat: float
    consumed_fiber: float
    goal_calories: float
    goal_protein: float
    goal_carbs: float
    goal_fat: float
    goal_fiber: float
    calories_percentage: float
    protein_percentage: float
    carbs_percentage: float
    fat_percentage: float
    fiber_percentage: float
