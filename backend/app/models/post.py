from sqlalchemy import Column, Integer, String, DateTime, Text
from app.models.food_record import Base, get_kst_now

class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)  # 작성자 ID
    title = Column(String, nullable=False)  # 게시글 제목
    content = Column(Text, nullable=True)  # 게시글 내용
    image_path = Column(String, nullable=True)  # 이미지 경로
    created_at = Column(DateTime, default=get_kst_now)
    updated_at = Column(DateTime, default=get_kst_now, onupdate=get_kst_now)
