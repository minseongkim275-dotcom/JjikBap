from pydantic import BaseModel
from typing import Optional


class UserSettingsCreate(BaseModel):
    user_id: int

    # 알림 설정
    meal_reminder: Optional[bool] = True
    breakfast_reminder: Optional[bool] = True
    lunch_reminder: Optional[bool] = True
    dinner_reminder: Optional[bool] = True
    goal_achievement: Optional[bool] = True
    weekly_report: Optional[bool] = True

    breakfast_hour: Optional[int] = 8
    breakfast_minute: Optional[int] = 0
    lunch_hour: Optional[int] = 12
    lunch_minute: Optional[int] = 0
    dinner_hour: Optional[int] = 18
    dinner_minute: Optional[int] = 0

    # 가격 설정
    recommend_min_price: Optional[int] = 5000
    recommend_max_price: Optional[int] = 15000
    skip_price_dialog: Optional[bool] = False

    # 활동량 및 식단 목표
    activity_level: Optional[str] = "moderate"
    diet_goal: Optional[str] = "maintain"


class UserSettingsResponse(BaseModel):
    id: int
    user_id: int

    meal_reminder: bool
    breakfast_reminder: bool
    lunch_reminder: bool
    dinner_reminder: bool
    goal_achievement: bool
    weekly_report: bool

    breakfast_hour: int
    breakfast_minute: int
    lunch_hour: int
    lunch_minute: int
    dinner_hour: int
    dinner_minute: int

    recommend_min_price: int
    recommend_max_price: int
    skip_price_dialog: bool

    activity_level: str
    diet_goal: str

    class Config:
        from_attributes = True
