from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.routes import router
from app.database import init_db, SessionLocal
from app.services.food_recommendation_service import init_nutrition_db, sync_food_records_to_nutrition_db
import os

app = FastAPI(
    title="찍밥 (JjikBap) API",
    description="음식 사진/텍스트로 영양 정보를 분석하고 기록하는 API",
    version="1.0.0"
)

# CORS 설정 (Flutter 앱과 통신을 위해)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인만 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 데이터베이스 초기화
@app.on_event("startup")
def on_startup():
    init_db()

    # 영양 DB 초기화 (기본 음식 데이터 삽입)
    db = SessionLocal()
    try:
        init_nutrition_db(db)
        # FoodRecord의 음식들도 영양 DB에 동기화
        sync_food_records_to_nutrition_db(db)
    finally:
        db.close()

# 라우터 등록
app.include_router(router, prefix="/api", tags=["nutrition"])

# 정적 파일 서빙 (이미지 등)
# 절대 경로 사용
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
uploads_dir = os.path.join(BASE_DIR, "uploads")
print(f"[Static Files] Uploads directory: {uploads_dir}")
print(f"[Static Files] Directory exists: {os.path.exists(uploads_dir)}")
if os.path.exists(uploads_dir):
    app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")
    print(f"[Static Files] Mounted /uploads -> {uploads_dir}")

@app.get("/")
def read_root():
    return {
        "message": "찍밥 (JjikBap) API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}
