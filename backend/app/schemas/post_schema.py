from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class PostCreate(BaseModel):
    user_id: Optional[int] = None
    title: str
    content: Optional[str] = None
    image_path: Optional[str] = None

class PostUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    image_path: Optional[str] = None

class PostResponse(BaseModel):
    id: int
    user_id: Optional[int]
    title: str
    content: Optional[str]
    image_path: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
