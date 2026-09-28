from sqlalchemy import Column, Integer, String, Boolean
from app.database import Base


class UserSettings(Base):
    __tablename__ = "user_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, unique=True, index=True)

    # 알림 설정
    meal_reminder = Column(Boolean, default=True)
    breakfast_reminder = Column(Boolean, default=True)
    lunch_reminder = Column(Boolean, default=True)
    dinner_reminder = Column(Boolean, default=True)
    goal_achievement = Column(Boolean, default=True)
    weekly_report = Column(Boolean, default=True)

    breakfast_hour = Column(Integer, default=8)
    breakfast_minute = Column(Integer, default=0)
    lunch_hour = Column(Integer, default=12)
    lunch_minute = Column(Integer, default=0)
    dinner_hour = Column(Integer, default=18)
    dinner_minute = Column(Integer, default=0)

    # 가격 설정
    recommend_min_price = Column(Integer, default=5000)
    recommend_max_price = Column(Integer, default=15000)
    skip_price_dialog = Column(Boolean, default=False)

    # 활동량 및 식단 목표
    activity_level = Column(String(50), default="moderate")
    diet_goal = Column(String(50), default="maintain")
