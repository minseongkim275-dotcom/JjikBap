from sqlalchemy import Column, Integer, Float, Date
from app.database import Base
from datetime import date

class NutritionGoal(Base):
    __tablename__ = "nutrition_goals"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, default=date.today, unique=True, nullable=False)
    calories = Column(Float, default=2000.0)
    protein = Column(Float, default=50.0)
    carbs = Column(Float, default=250.0)
    fat = Column(Float, default=65.0)
    fiber = Column(Float, default=25.0)
    target_date = Column(Date, nullable=True)  # D-Day 목표 날짜
