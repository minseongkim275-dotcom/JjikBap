from sqlalchemy import Column, Integer, String, DateTime
from app.models.food_record import Base, get_kst_now


class ExcludedFood(Base):
    """사용자별 제외된 음식 (추천에서 제외)"""
    __tablename__ = "excluded_foods"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    food_name = Column(String, nullable=False)
    created_at = Column(DateTime, default=get_kst_now)
