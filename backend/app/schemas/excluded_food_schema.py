from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ExcludedFoodCreate(BaseModel):
    user_id: int
    food_name: str


class ExcludedFoodResponse(BaseModel):
    id: int
    user_id: int
    food_name: str
    created_at: datetime

    class Config:
        from_attributes = True


class ExcludedFoodDelete(BaseModel):
    user_id: int
    food_name: str
