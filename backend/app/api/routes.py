from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date
import uuid
import os
import shutil
import base64

from app.database import get_db
from app.models.food_record import FoodRecord, get_kst_now
from app.models.nutrition_goal import NutritionGoal
from app.models.post import Post
from app.schemas.food_schema import (
    FoodRecordCreate,
    FoodRecordResponse,
    AnalyzeRequest,
    NutritionInfo,
    SearchFoodResponse,
    FoodSuggestion
)
from app.schemas.nutrition_goal_schema import (
    NutritionGoalCreate,
    NutritionGoalResponse,
    DailyStats
)
from app.schemas.post_schema import (
    PostCreate,
    PostUpdate,
    PostResponse
)
from app.services.nutrition_analyzer import nutrition_analyzer
from app.services.ner_food_recognizer import get_recognizer
from app.services.food_recommendation_service import get_recommendation_service
from app.models.food_nutrition_db import FoodNutritionDB, UserFoodHistory
from app.schemas.food_recommendation_schema import (
    FoodNutritionCreate,
    FoodNutritionResponse,
    UserHistoryCreate,
    UserHistoryResponse,
    RecommendationRequest,
    RecommendationResponse,
    FoodRecommendation
)
from app.models.excluded_food import ExcludedFood
from app.schemas.excluded_food_schema import (
    ExcludedFoodCreate,
    ExcludedFoodResponse,
    ExcludedFoodDelete
)
from app.models.user_settings import UserSettings
from app.schemas.user_settings_schema import (
    UserSettingsCreate,
    UserSettingsResponse
)
from app.models.user import User
from app.schemas.user_schema import (
    UserCreate,
    UserLogin,
    UserResponse,
    UserUpdate
)

router = APIRouter()

@router.get("/search-food", response_model=SearchFoodResponse)
async def search_food(query: str):
    """텍스트로 음식 검색 (여러 제안 반환)"""
    recognizer = get_recognizer()
    matches = recognizer.search_foods(query, max_results=10)

    suggestions = [
        FoodSuggestion(food_name=m["food_name"], match_score=m["score"])
        for m in matches
    ]

    return SearchFoodResponse(query=query, suggestions=suggestions)

@router.post("/analyze", response_model=NutritionInfo)
async def analyze_food(request: AnalyzeRequest):
    """텍스트 또는 이미지로 음식 분석"""

    if request.text:
        # 텍스트 분석
        result = nutrition_analyzer.analyze_text(request.text)
        if result:
            return result
        raise HTTPException(status_code=400, detail="음식을 인식하지 못했습니다")

    elif request.image_base64:
        # 이미지 분석
        result = nutrition_analyzer.analyze_image(request.image_base64)
        if result:
            return result
        raise HTTPException(status_code=400, detail="이미지를 분석하지 못했습니다")

    raise HTTPException(status_code=400, detail="텍스트 또는 이미지를 입력해주세요")

@router.post("/records", response_model=FoodRecordResponse)
async def create_food_record(
    record: FoodRecordCreate,
    db: Session = Depends(get_db)
):
    """음식 기록 생성"""
    db_record = FoodRecord(
        user_id=record.user_id,
        food_name=record.food_name,
        calories=record.calories,
        protein=record.protein,
        carbs=record.carbs,
        fat=record.fat,
        fiber=record.fiber,
        image_path=record.image_path,
        description=record.description,
        latitude=record.latitude,
        longitude=record.longitude,
        rating=record.rating
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record

def _calculate_food_score(record) -> tuple[float, str]:
    """개별 음식 점수 계산 (노트북 알고리즘 기반)"""
    score = 0.0

    # 칼로리 점수 (적정 범위: 400-800 kcal per meal)
    if 400 <= record.calories <= 800:
        score += 25
    elif 300 <= record.calories <= 900:
        score += 18
    elif 200 <= record.calories <= 1000:
        score += 10

    # 단백질 점수 (15g 이상 권장)
    if record.protein >= 25:
        score += 25
    elif record.protein >= 20:
        score += 22
    elif record.protein >= 15:
        score += 18
    elif record.protein >= 10:
        score += 12
    else:
        score += 5

    # 탄수화물 점수 (적정 범위: 50-100g)
    if 50 <= record.carbs <= 100:
        score += 25
    elif 30 <= record.carbs <= 120:
        score += 18
    elif 20 <= record.carbs <= 150:
        score += 10

    # 지방 점수 (적정 범위: 10-25g)
    if 10 <= record.fat <= 25:
        score += 25
    elif 5 <= record.fat <= 35:
        score += 18
    elif record.fat < 5:
        score += 10
    else:
        score += 5

    # 등급 계산
    if score >= 90:
        grade = 'A'
    elif score >= 75:
        grade = 'B'
    elif score >= 60:
        grade = 'C'
    elif score >= 45:
        grade = 'D'
    else:
        grade = 'F'

    return score, grade

@router.get("/records", response_model=List[FoodRecordResponse])
async def get_food_records(
    user_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """음식 기록 조회 (최신순) - 점수/등급 포함, 사용자별 필터링"""
    query = db.query(FoodRecord)

    # 사용자별 필터링
    if user_id is not None:
        query = query.filter(FoodRecord.user_id == user_id)

    records = query.order_by(FoodRecord.created_at.desc())\
        .offset(skip)\
        .limit(limit)\
        .all()

    # 각 레코드에 점수/등급 추가
    result = []
    for record in records:
        score, grade = _calculate_food_score(record)
        record_dict = {
            "id": record.id,
            "food_name": record.food_name,
            "calories": record.calories,
            "protein": record.protein,
            "carbs": record.carbs,
            "fat": record.fat,
            "fiber": record.fiber,
            "image_path": record.image_path,
            "description": record.description,
            "created_at": record.created_at,
            "latitude": record.latitude,
            "longitude": record.longitude,
            "rating": record.rating,
            "score": score,
            "grade": grade
        }
        result.append(record_dict)

    return result

@router.get("/records/{record_id}", response_model=FoodRecordResponse)
async def get_food_record(
    record_id: int,
    db: Session = Depends(get_db)
):
    """특정 음식 기록 조회"""
    record = db.query(FoodRecord).filter(FoodRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="기록을 찾을 수 없습니다")
    return record

@router.delete("/records/{record_id}")
async def delete_food_record(
    record_id: int,
    db: Session = Depends(get_db)
):
    """음식 기록 삭제"""
    record = db.query(FoodRecord).filter(FoodRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="기록을 찾을 수 없습니다")

    db.delete(record)
    db.commit()
    return {"message": "기록이 삭제되었습니다"}

@router.get("/records/stats/summary")
async def get_nutrition_summary(db: Session = Depends(get_db)):
    """전체 영양 통계"""
    records = db.query(FoodRecord).all()

    total_calories = sum(r.calories for r in records)
    total_protein = sum(r.protein for r in records)
    total_carbs = sum(r.carbs for r in records)
    total_fat = sum(r.fat for r in records)
    total_fiber = sum(r.fiber for r in records)

    return {
        "total_records": len(records),
        "total_calories": round(total_calories, 2),
        "total_protein": round(total_protein, 2),
        "total_carbs": round(total_carbs, 2),
        "total_fat": round(total_fat, 2),
        "total_fiber": round(total_fiber, 2)
    }

# 영양 목표 관련 API
@router.post("/goals", response_model=NutritionGoalResponse)
async def create_or_update_goal(
    goal: NutritionGoalCreate,
    db: Session = Depends(get_db)
):
    """영양 목표 생성 또는 업데이트"""
    target_date = goal.date if goal.date else date.today()

    # 기존 목표 확인
    existing_goal = db.query(NutritionGoal).filter(
        NutritionGoal.date == target_date
    ).first()

    if existing_goal:
        # 업데이트
        existing_goal.calories = goal.calories
        existing_goal.protein = goal.protein
        existing_goal.carbs = goal.carbs
        existing_goal.fat = goal.fat
        existing_goal.fiber = goal.fiber
        db.commit()
        db.refresh(existing_goal)
        return existing_goal
    else:
        # 새로 생성
        db_goal = NutritionGoal(
            date=target_date,
            calories=goal.calories,
            protein=goal.protein,
            carbs=goal.carbs,
            fat=goal.fat,
            fiber=goal.fiber
        )
        db.add(db_goal)
        db.commit()
        db.refresh(db_goal)
        return db_goal

@router.get("/goals/today", response_model=NutritionGoalResponse)
async def get_today_goal(db: Session = Depends(get_db)):
    """오늘의 영양 목표 조회"""
    today = date.today()
    goal = db.query(NutritionGoal).filter(NutritionGoal.date == today).first()

    if not goal:
        # 목표가 없으면 기본값 생성
        goal = NutritionGoal(date=today)
        db.add(goal)
        db.commit()
        db.refresh(goal)

    return goal

@router.get("/stats/daily", response_model=DailyStats)
async def get_daily_stats(
    target_date: str = None,
    db: Session = Depends(get_db)
):
    """하루별 영양 통계 (목표 대비 섭취량)"""
    if target_date:
        try:
            query_date = datetime.strptime(target_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="날짜 형식이 올바르지 않습니다 (YYYY-MM-DD)")
    else:
        query_date = date.today()

    # 해당 날짜의 목표 조회
    goal = db.query(NutritionGoal).filter(NutritionGoal.date == query_date).first()
    if not goal:
        # 목표가 없으면 기본값 생성
        goal = NutritionGoal(date=query_date)
        db.add(goal)
        db.commit()
        db.refresh(goal)

    # 해당 날짜의 음식 기록 조회
    start_datetime = datetime.combine(query_date, datetime.min.time())
    end_datetime = datetime.combine(query_date, datetime.max.time())

    records = db.query(FoodRecord).filter(
        FoodRecord.created_at >= start_datetime,
        FoodRecord.created_at <= end_datetime
    ).all()

    # 섭취량 계산
    consumed_calories = sum(r.calories for r in records)
    consumed_protein = sum(r.protein for r in records)
    consumed_carbs = sum(r.carbs for r in records)
    consumed_fat = sum(r.fat for r in records)
    consumed_fiber = sum(r.fiber for r in records)

    # 목표 대비 퍼센티지 계산
    calories_pct = (consumed_calories / goal.calories * 100) if goal.calories > 0 else 0
    protein_pct = (consumed_protein / goal.protein * 100) if goal.protein > 0 else 0
    carbs_pct = (consumed_carbs / goal.carbs * 100) if goal.carbs > 0 else 0
    fat_pct = (consumed_fat / goal.fat * 100) if goal.fat > 0 else 0
    fiber_pct = (consumed_fiber / goal.fiber * 100) if goal.fiber > 0 else 0

    return DailyStats(
        date=query_date,
        consumed_calories=round(consumed_calories, 1),
        consumed_protein=round(consumed_protein, 1),
        consumed_carbs=round(consumed_carbs, 1),
        consumed_fat=round(consumed_fat, 1),
        consumed_fiber=round(consumed_fiber, 1),
        goal_calories=goal.calories,
        goal_protein=goal.protein,
        goal_carbs=goal.carbs,
        goal_fat=goal.fat,
        goal_fiber=goal.fiber,
        calories_percentage=round(calories_pct, 1),
        protein_percentage=round(protein_pct, 1),
        carbs_percentage=round(carbs_pct, 1),
        fat_percentage=round(fat_pct, 1),
        fiber_percentage=round(fiber_pct, 1)
    )

# 게시글 관련 API
@router.post("/posts", response_model=PostResponse)
async def create_post(
    post: PostCreate,
    db: Session = Depends(get_db)
):
    """게시글 생성"""
    db_post = Post(
        user_id=post.user_id,
        title=post.title,
        content=post.content,
        image_path=post.image_path
    )
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    return db_post

@router.get("/posts", response_model=List[PostResponse])
async def get_posts(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """게시글 목록 조회 (최신순)"""
    posts = db.query(Post)\
        .order_by(Post.created_at.desc())\
        .offset(skip)\
        .limit(limit)\
        .all()
    return posts

@router.get("/posts/{post_id}", response_model=PostResponse)
async def get_post(
    post_id: int,
    db: Session = Depends(get_db)
):
    """특정 게시글 조회"""
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다")
    return post

@router.put("/posts/{post_id}", response_model=PostResponse)
async def update_post(
    post_id: int,
    post_update: PostUpdate,
    db: Session = Depends(get_db)
):
    """게시글 수정"""
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다")

    if post_update.title is not None:
        post.title = post_update.title
    if post_update.content is not None:
        post.content = post_update.content
    if post_update.image_path is not None:
        post.image_path = post_update.image_path

    post.updated_at = get_kst_now()
    db.commit()
    db.refresh(post)
    return post

@router.delete("/posts/{post_id}")
async def delete_post(
    post_id: int,
    db: Session = Depends(get_db)
):
    """게시글 삭제"""
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다")

    db.delete(post)
    db.commit()
    return {"message": "게시글이 삭제되었습니다"}

# 음식 추천 API (DB 기반 - 하드코딩 제거)
@router.get("/recommendations")
async def get_food_recommendations(
    user_id: int = None,
    limit: int = 5,
    min_price: int = None,
    max_price: int = None,
    db: Session = Depends(get_db)
):
    """사용자의 식습관 기반 음식 추천 (DB에서 조회)"""
    from collections import Counter
    import random

    # 가격 필터링을 위한 가격 데이터 로드
    food_prices = _load_food_prices()

    def is_in_price_range(food_name: str) -> bool:
        """음식이 가격 범위 내에 있는지 확인"""
        if min_price is None and max_price is None:
            return True
        if food_name not in food_prices:
            return False  # 가격 정보 없으면 제외

        price_info = food_prices[food_name]
        food_min = price_info.get("min_price", 0)
        food_max = price_info.get("max_price", 0)

        # 가격 범위가 겹치는지 확인
        if min_price is not None and max_price is not None:
            return food_min <= max_price and food_max >= min_price
        elif min_price is not None:
            return food_max >= min_price
        elif max_price is not None:
            return food_min <= max_price
        return True

    # FoodNutritionDB에서 전체 음식 조회
    all_foods = db.query(FoodNutritionDB).all()

    # 가격 필터 적용
    if min_price is not None or max_price is not None:
        all_foods = [f for f in all_foods if is_in_price_range(f.food_name)]

    if not all_foods:
        return {"recommendations": [], "message": "DB에 등록된 음식이 없습니다"}

    # 최근 음식 기록 가져오기 (사용자별 필터링)
    query = db.query(FoodRecord)
    if user_id is not None:
        query = query.filter(FoodRecord.user_id == user_id)
    records = query.order_by(FoodRecord.created_at.desc()).limit(50).all()

    if not records:
        # 기록이 없으면 DB에서 랜덤 음식 추천
        random.shuffle(all_foods)
        recommendations = [
            {
                "food_name": food.food_name,
                "reason": f"DB에 등록된 {food.food_type or '음식'}입니다",
                "category": food.food_type or "기타",
                "nutrition": {
                    "calories": food.calories or 0,
                    "protein": food.protein or 0,
                    "carbs": food.carbs or 0,
                    "fat": food.fat or 0
                }
            }
            for food in all_foods[:limit]
        ]
        return {"recommendations": recommendations}

    # 이미 먹은 음식 목록
    eaten_foods = {r.food_name for r in records}

    # 평균 영양소 섭취 분석
    avg_calories = sum(r.calories or 0 for r in records) / len(records)
    avg_protein = sum(r.protein or 0 for r in records) / len(records)
    avg_carbs = sum(r.carbs or 0 for r in records) / len(records)

    # DB 기반 추천 로직
    recommendations = []

    # 1. 단백질이 부족하면 DB에서 고단백 음식 조회
    if avg_protein < 60:
        high_protein_foods = db.query(FoodNutritionDB).filter(
            FoodNutritionDB.protein >= 20,
            FoodNutritionDB.food_name.notin_(eaten_foods)
        ).order_by(FoodNutritionDB.protein.desc()).limit(10).all()

        # 가격 필터 적용
        high_protein_foods = [f for f in high_protein_foods if is_in_price_range(f.food_name)][:2]

        for food in high_protein_foods:
            recommendations.append({
                "food_name": food.food_name,
                "reason": f"평균 단백질 섭취량({avg_protein:.1f}g)이 부족해요. 단백질 {food.protein}g",
                "category": "고단백",
                "nutrition": {
                    "calories": food.calories or 0,
                    "protein": food.protein or 0,
                    "carbs": food.carbs or 0,
                    "fat": food.fat or 0
                }
            })

    # 2. 칼로리가 높으면 DB에서 저칼로리 음식 조회
    if avg_calories > 600:
        low_cal_foods = db.query(FoodNutritionDB).filter(
            FoodNutritionDB.calories <= 200,
            FoodNutritionDB.food_name.notin_(eaten_foods)
        ).order_by(FoodNutritionDB.calories.asc()).limit(10).all()

        # 가격 필터 적용
        low_cal_foods = [f for f in low_cal_foods if is_in_price_range(f.food_name)][:2]

        for food in low_cal_foods:
            recommendations.append({
                "food_name": food.food_name,
                "reason": f"평균 칼로리({avg_calories:.0f}kcal)를 낮춰보세요. {food.calories}kcal",
                "category": "저칼로리",
                "nutrition": {
                    "calories": food.calories or 0,
                    "protein": food.protein or 0,
                    "carbs": food.carbs or 0,
                    "fat": food.fat or 0
                }
            })

    # 3. 탄수화물이 많으면 DB에서 저탄수 음식 조회
    if avg_carbs > 80:
        low_carb_foods = db.query(FoodNutritionDB).filter(
            FoodNutritionDB.carbs <= 20,
            FoodNutritionDB.food_name.notin_(eaten_foods)
        ).order_by(FoodNutritionDB.carbs.asc()).limit(10).all()

        # 가격 필터 적용
        low_carb_foods = [f for f in low_carb_foods if is_in_price_range(f.food_name)][:2]

        for food in low_carb_foods:
            recommendations.append({
                "food_name": food.food_name,
                "reason": f"평균 탄수화물({avg_carbs:.1f}g)이 많아요. 탄수화물 {food.carbs}g",
                "category": "저탄수",
                "nutrition": {
                    "calories": food.calories or 0,
                    "protein": food.protein or 0,
                    "carbs": food.carbs or 0,
                    "fat": food.fat or 0
                }
            })

    # 4. 추천이 부족하면 안 먹은 음식 중 랜덤 추가
    if len(recommendations) < limit:
        remaining_foods = [f for f in all_foods if f.food_name not in eaten_foods]
        random.shuffle(remaining_foods)

        for food in remaining_foods[:limit - len(recommendations)]:
            recommendations.append({
                "food_name": food.food_name,
                "reason": "새로운 음식을 시도해보세요",
                "category": food.food_type or "기타",
                "nutrition": {
                    "calories": food.calories or 0,
                    "protein": food.protein or 0,
                    "carbs": food.carbs or 0,
                    "fat": food.fat or 0
                }
            })

    # 중복 제거 및 limit 적용
    unique_recommendations = []
    seen_foods = set()
    for rec in recommendations:
        if rec["food_name"] not in seen_foods:
            unique_recommendations.append(rec)
            seen_foods.add(rec["food_name"])
        if len(unique_recommendations) >= limit:
            break

    return {
        "recommendations": unique_recommendations,
        "user_stats": {
            "avg_calories": round(avg_calories, 1),
            "avg_protein": round(avg_protein, 1),
            "avg_carbs": round(avg_carbs, 1),
            "total_records": len(records)
        }
    }


# ============ 음식 추천 시스템 API (DB 기반) ============

@router.get("/nutrition-db/{food_name}")
async def get_food_nutrition(food_name: str, db: Session = Depends(get_db)):
    """음식 영양정보 조회 (DB에서)"""
    service = get_recommendation_service(db)
    nutrition = service.get_nutrition(food_name)

    if nutrition:
        return {
            "food_name": food_name,
            "nutrition": nutrition,
            "found": True
        }

    return {
        "food_name": food_name,
        "nutrition": None,
        "found": False,
        "message": "영양정보를 찾을 수 없습니다"
    }


@router.get("/nutrition-db")
async def list_all_nutrition(db: Session = Depends(get_db)):
    """전체 영양정보 목록 조회 (DB에서)"""
    service = get_recommendation_service(db)
    all_foods = service.get_all_foods()

    foods_dict = {}
    food_names = []
    for food in all_foods:
        food_names.append(food.food_name)
        foods_dict[food.food_name] = service._food_to_dict(food)

    return {
        "total": len(all_foods),
        "foods": food_names,
        "data": foods_dict
    }


@router.get("/recommend/similar/{food_name}")
async def recommend_similar(
    food_name: str,
    top_k: int = 5,
    db: Session = Depends(get_db)
):
    """유사한 음식 추천 (코사인 유사도 기반, DB 사용)"""
    service = get_recommendation_service(db)
    recommendations = service.recommend_similar_foods(food_name, top_k)

    return {
        "query_food": food_name,
        "recommendations": recommendations,
        "algorithm": "cosine_similarity"
    }


@router.get("/recommend/diverse/{food_name}")
async def recommend_diverse(
    food_name: str,
    top_k: int = 5,
    db: Session = Depends(get_db)
):
    """다양한 음식 추천 (낮은 유사도 = 다양성, DB 사용)"""
    service = get_recommendation_service(db)
    recommendations = service.recommend_diverse_foods(food_name, top_k)

    return {
        "query_food": food_name,
        "recommendations": recommendations,
        "algorithm": "diversity"
    }


@router.post("/recommend/personalized")
async def recommend_personalized(
    request: RecommendationRequest,
    db: Session = Depends(get_db)
):
    """사용자 식사 기록 기반 개인화 추천 (DB 사용)"""
    service = get_recommendation_service(db)

    # 현재 음식 기준 추천
    if request.current_food:
        recommendations = service.recommend_similar_foods(
            request.current_food,
            request.top_k
        )
    else:
        # FoodRecord 기반 추천
        recommendations = service.recommend_by_user_history(
            request.user_id,
            request.top_k
        )

    return {
        "user_id": request.user_id,
        "recommendations": recommendations,
        "algorithm": "personalized"
    }


@router.post("/recommend/balanced")
async def recommend_balanced(
    request: RecommendationRequest,
    db: Session = Depends(get_db)
):
    """영양 균형을 고려한 추천 (DB 사용)"""
    service = get_recommendation_service(db)
    recommendations = service.recommend_balanced(request.user_id, request.top_k)

    # 최근 섭취량 계산 (FoodRecord에서)
    query = db.query(FoodRecord)
    if request.user_id is not None:
        query = query.filter(FoodRecord.user_id == request.user_id)
    food_records = query.order_by(
        FoodRecord.created_at.desc()
    ).limit(10).all()

    total_nutrition = {
        "calories": sum(r.calories or 0 for r in food_records),
        "protein": sum(r.protein or 0 for r in food_records),
        "carbs": sum(r.carbs or 0 for r in food_records),
        "fat": sum(r.fat or 0 for r in food_records)
    }

    return {
        "user_id": request.user_id,
        "recommendations": recommendations,
        "recent_nutrition": total_nutrition,
        "algorithm": "balanced"
    }


@router.post("/user-history")
async def add_user_history(
    history: UserHistoryCreate,
    db: Session = Depends(get_db)
):
    """사용자 식사 기록 추가"""
    db_history = UserFoodHistory(
        user_id=history.user_id,
        food_name=history.food_name,
        meal_type=history.meal_type,
        date=history.date,
        calories=history.calories,
        protein=history.protein,
        carbs=history.carbs,
        fat=history.fat
    )
    db.add(db_history)
    db.commit()
    db.refresh(db_history)

    return {
        "message": "식사 기록이 추가되었습니다",
        "id": db_history.id
    }


@router.get("/user-history/{user_id}")
async def get_user_history(
    user_id: int,
    days: int = 7,
    db: Session = Depends(get_db)
):
    """사용자 식사 기록 조회"""
    from datetime import timedelta

    start_date = (date.today() - timedelta(days=days)).isoformat()

    records = db.query(UserFoodHistory).filter(
        UserFoodHistory.user_id == user_id,
        UserFoodHistory.date >= start_date
    ).order_by(UserFoodHistory.date.desc(), UserFoodHistory.id.desc()).all()

    # 날짜별 그룹화
    history_by_date = {}
    for r in records:
        if r.date not in history_by_date:
            history_by_date[r.date] = {"meals": {}, "total": {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}}

        meal_type = r.meal_type or "기타"
        if meal_type not in history_by_date[r.date]["meals"]:
            history_by_date[r.date]["meals"][meal_type] = []

        history_by_date[r.date]["meals"][meal_type].append(r.food_name)
        history_by_date[r.date]["total"]["calories"] += r.calories
        history_by_date[r.date]["total"]["protein"] += r.protein
        history_by_date[r.date]["total"]["carbs"] += r.carbs
        history_by_date[r.date]["total"]["fat"] += r.fat

    return {
        "user_id": user_id,
        "days": days,
        "history": history_by_date,
        "total_records": len(records)
    }


# ========================================
# v2 API - 노트북 알고리즘 통합
# ========================================

@router.get("/recommend/diverse-v2/{food_name}")
async def recommend_diverse_v2(
    food_name: str,
    top_k: int = 5,
    threshold: float = 0.5,
    user_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    """
    다양성 기반 음식 추천 (v2 - 노트북 알고리즘)

    - threshold 이상의 유사도를 가진 음식은 제외
    - 사용자 프로필과 현재 음식을 blend하여 추천
    - 향상된 추천 이유 제공
    """
    service = get_recommendation_service(db)
    recommendations = service.recommend_diverse_v2(
        food_name,
        user_id=user_id,
        top_k=top_k,
        threshold=threshold
    )

    return {
        "query_food": food_name,
        "recommendations": recommendations,
        "algorithm": "diverse_v2",
        "threshold": threshold
    }


@router.get("/user-score")
async def get_user_score(
    user_id: Optional[int] = None,
    days: int = 7,
    db: Session = Depends(get_db)
):
    """
    사용자 식단 점수/등급 조회 (노트북 알고리즘)

    Returns:
        - score: 0-100 점수
        - grade: A/B/C/D/F 등급
        - details: 세부 점수 (음식점수, 영양점수, 습관점수)
        - feedback: 개선 피드백 목록
        - stats: 총 섭취 영양소 통계
    """
    service = get_recommendation_service(db)
    result = service.compute_user_score(user_id=user_id, days=days)

    return {
        "user_id": user_id,
        "period_days": days,
        **result
    }


@router.post("/recommend/diverse-v2")
async def recommend_diverse_v2_post(
    request: RecommendationRequest,
    db: Session = Depends(get_db)
):
    """
    다양성 기반 음식 추천 (v2 - POST 버전)

    Body:
        - current_food: 현재 음식명
        - user_id: 사용자 ID (선택)
        - top_k: 추천 개수 (기본 5)
    """
    service = get_recommendation_service(db)

    if not request.current_food:
        return {"error": "current_food is required"}

    recommendations = service.recommend_diverse_v2(
        request.current_food,
        user_id=request.user_id,
        top_k=request.top_k,
        threshold=0.5
    )

    return {
        "query_food": request.current_food,
        "user_id": request.user_id,
        "recommendations": recommendations,
        "algorithm": "diverse_v2"
    }


# ========================================
# EMB_DB 기반 임베딩 추천 API (노트북 원본 알고리즘)
# ========================================

@router.get("/recommend/embedding/{food_name}")
async def recommend_by_embedding(
    food_name: str,
    top_k: int = 5,
    db: Session = Depends(get_db)
):
    """
    EMB_DB 임베딩 기반 유사 음식 추천

    - 1305차원 임베딩 벡터 사용 (이미지+텍스트+영양+타입)
    - EMB_DB 없으면 기존 cosine similarity fallback
    """
    service = get_recommendation_service(db)
    recommendations = service.recommend_by_embedding(food_name, top_k)

    return {
        "query_food": food_name,
        "recommendations": recommendations,
        "algorithm": "embedding_similarity",
        "emb_db_available": service.emb_db is not None
    }


@router.get("/recommend/embedding-opposite/{food_name}")
async def recommend_opposite_by_embedding(
    food_name: str,
    top_k: int = 5,
    db: Session = Depends(get_db)
):
    """
    EMB_DB 기반 반대 계열 음식 추천

    - 유사도가 낮은 순으로 정렬
    - 다양성 확보를 위한 추천
    """
    service = get_recommendation_service(db)
    recommendations = service.recommend_opposite_by_embedding(food_name, top_k)

    return {
        "query_food": food_name,
        "recommendations": recommendations,
        "algorithm": "embedding_opposite",
        "emb_db_available": service.emb_db is not None
    }


@router.get("/recommend/embedding-diverse/{food_name}")
async def recommend_diverse_embedding(
    food_name: str,
    top_k: int = 5,
    threshold: float = 0.5,
    user_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    """
    EMB_DB 기반 다양성 추천 (노트북 recommend_diverse 원본)

    - 유사도가 threshold 이상인 음식은 제외
    - 사용자 프로필과 blend (0.8 * 현재음식 + 0.2 * 사용자)
    """
    service = get_recommendation_service(db)
    recommendations = service.recommend_diverse_embedding(
        food_name,
        user_id=user_id,
        top_k=top_k,
        threshold=threshold
    )

    return {
        "query_food": food_name,
        "recommendations": recommendations,
        "algorithm": "embedding_diverse",
        "threshold": threshold,
        "emb_db_available": service.emb_db is not None
    }


@router.get("/emb-db/foods")
async def get_emb_db_foods(db: Session = Depends(get_db)):
    """EMB_DB에 등록된 음식 목록 조회"""
    service = get_recommendation_service(db)
    foods = service.get_emb_db_foods()

    return {
        "total": len(foods),
        "foods": foods,
        "emb_db_available": service.emb_db is not None
    }


# ========================================
# 제외된 음식 API (사용자별)
# ========================================

@router.get("/excluded-foods", response_model=List[ExcludedFoodResponse])
async def get_excluded_foods(
    user_id: int,
    db: Session = Depends(get_db)
):
    """사용자의 제외된 음식 목록 조회"""
    foods = db.query(ExcludedFood).filter(
        ExcludedFood.user_id == user_id
    ).order_by(ExcludedFood.created_at.desc()).all()
    return foods


@router.post("/excluded-foods", response_model=ExcludedFoodResponse)
async def add_excluded_food(
    food: ExcludedFoodCreate,
    db: Session = Depends(get_db)
):
    """제외할 음식 추가"""
    # 이미 존재하는지 확인
    existing = db.query(ExcludedFood).filter(
        ExcludedFood.user_id == food.user_id,
        ExcludedFood.food_name == food.food_name
    ).first()

    if existing:
        return existing

    db_food = ExcludedFood(
        user_id=food.user_id,
        food_name=food.food_name
    )
    db.add(db_food)
    db.commit()
    db.refresh(db_food)
    return db_food


@router.delete("/excluded-foods")
async def remove_excluded_food(
    user_id: int,
    food_name: str,
    db: Session = Depends(get_db)
):
    """제외된 음식 삭제"""
    food = db.query(ExcludedFood).filter(
        ExcludedFood.user_id == user_id,
        ExcludedFood.food_name == food_name
    ).first()

    if not food:
        raise HTTPException(status_code=404, detail="제외된 음식을 찾을 수 없습니다")

    db.delete(food)
    db.commit()
    return {"message": "제외 목록에서 삭제되었습니다"}


@router.delete("/excluded-foods/all")
async def clear_excluded_foods(
    user_id: int,
    db: Session = Depends(get_db)
):
    """사용자의 모든 제외된 음식 삭제"""
    db.query(ExcludedFood).filter(
        ExcludedFood.user_id == user_id
    ).delete()
    db.commit()
    return {"message": "모든 제외 목록이 삭제되었습니다"}


# ========================================
# 음식 가격 API (서울 기준)
# ========================================

import json
from pathlib import Path

# 가격 데이터 로드 (앱 시작 시 1회)
_food_prices = None

def _load_food_prices():
    global _food_prices
    if _food_prices is None:
        price_path = Path(__file__).parent.parent / "ml_models" / "food_prices.json"
        try:
            with open(price_path, 'r', encoding='utf-8') as f:
                _food_prices = json.load(f)
            print(f"✓ 가격 데이터 로드 완료: {len(_food_prices)}개 음식")
        except Exception as e:
            print(f"✗ 가격 데이터 로드 실패: {e}")
            _food_prices = {}
    return _food_prices


@router.get("/food-price/{food_name}")
async def get_food_price(food_name: str):
    """
    음식 가격 조회 (서울 기준)

    Returns:
        - base_price: 기준 가격 (원)
        - min_price: 최소 추천 가격 (기준 -10%)
        - max_price: 최대 추천 가격 (기준 +10%)
        - currency: 통화 (KRW)
        - unit: 단위 (1인분)
        - region: 지역 (서울)
    """
    prices = _load_food_prices()

    if food_name in prices:
        return {
            "food_name": food_name,
            "found": True,
            **prices[food_name]
        }

    # 부분 일치 검색
    for name, price_info in prices.items():
        if food_name in name or name in food_name:
            return {
                "food_name": name,
                "query": food_name,
                "found": True,
                "partial_match": True,
                **price_info
            }

    return {
        "food_name": food_name,
        "found": False,
        "message": "가격 정보를 찾을 수 없습니다"
    }


@router.get("/food-prices")
async def get_all_food_prices(
    category: Optional[str] = None,
    min_price: Optional[int] = None,
    max_price: Optional[int] = None,
    limit: int = 100
):
    """
    전체 음식 가격 목록 조회

    Query params:
        - category: 카테고리 필터 (예: 비빔밥, 치킨, 피자)
        - min_price: 최소 가격 필터
        - max_price: 최대 가격 필터
        - limit: 결과 개수 제한
    """
    prices = _load_food_prices()

    results = []
    for food_name, price_info in prices.items():
        # 카테고리 필터
        if category and category not in food_name:
            continue

        # 가격 필터
        base = price_info.get("base_price", 0)
        if min_price and base < min_price:
            continue
        if max_price and base > max_price:
            continue

        results.append({
            "food_name": food_name,
            **price_info
        })

        if len(results) >= limit:
            break

    return {
        "total": len(results),
        "foods": results
    }


@router.get("/food-price-range")
async def get_price_range(
    min_budget: int,
    max_budget: int,
    limit: int = 20
):
    """
    예산 범위 내 음식 검색

    Query params:
        - min_budget: 최소 예산 (원)
        - max_budget: 최대 예산 (원)
        - limit: 결과 개수 제한
    """
    prices = _load_food_prices()

    matching_foods = []
    for food_name, price_info in prices.items():
        base = price_info.get("base_price", 0)
        min_p = price_info.get("min_price", 0)
        max_p = price_info.get("max_price", 0)

        # 예산 범위와 가격 범위가 겹치는지 확인
        if min_p <= max_budget and max_p >= min_budget:
            matching_foods.append({
                "food_name": food_name,
                **price_info
            })

    # 기준 가격으로 정렬
    matching_foods.sort(key=lambda x: x["base_price"])

    return {
        "budget_range": f"{min_budget:,}원 ~ {max_budget:,}원",
        "total": len(matching_foods),
        "foods": matching_foods[:limit]
    }


# ==================== 회원 관리 API ====================

@router.post("/users/register", response_model=UserResponse, tags=["users"])
async def register_user(user: UserCreate, db: Session = Depends(get_db)):
    """회원가입"""
    # 아이디 중복 확인
    existing_user = db.query(User).filter(User.username == user.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 존재하는 아이디입니다")
    
    db_user = User(
        username=user.username,
        password=user.password,  # 실제 서비스에서는 해시 처리 필요
        name=user.name,
        weight=user.weight,
        height=user.height
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@router.post("/users/login", response_model=UserResponse, tags=["users"])
async def login_user(login: UserLogin, db: Session = Depends(get_db)):
    """로그인"""
    user = db.query(User).filter(
        User.username == login.username,
        User.password == login.password
    ).first()
    
    if not user:
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다")
    
    return user


@router.get("/users/{user_id}", response_model=UserResponse, tags=["users"])
async def get_user(user_id: int, db: Session = Depends(get_db)):
    """사용자 정보 조회"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    return user


@router.put("/users/{user_id}", response_model=UserResponse, tags=["users"])
async def update_user(user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)):
    """사용자 정보 수정"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    
    if user_update.name:
        user.name = user_update.name
    if user_update.weight:
        user.weight = user_update.weight
    if user_update.height:
        user.height = user_update.height
    if user_update.password:
        user.password = user_update.password
    
    db.commit()
    db.refresh(user)
    return user


@router.get("/users/check/{username}", tags=["users"])
async def check_username(username: str, db: Session = Depends(get_db)):
    """아이디 중복 확인"""
    exists = db.query(User).filter(User.username == username).first() is not None
    return {"username": username, "exists": exists}


@router.delete("/users/{user_id}", tags=["users"])
async def delete_user(user_id: int, db: Session = Depends(get_db)):
    """회원 탈퇴"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    
    db.delete(user)
    db.commit()
    return {"message": "회원 탈퇴가 완료되었습니다"}


# ==================== 이미지 업로드 API ====================

# 업로드 디렉토리 설정
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/upload-image", tags=["images"])
async def upload_image(
    file: UploadFile = File(...),
    user_id: int = Form(None)
):
    """
    이미지 업로드
    - 이미지를 서버의 uploads 폴더에 저장
    - 저장된 이미지 경로를 반환
    """
    try:
        # 파일 확장자 확인
        allowed_extensions = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
        file_ext = os.path.splitext(file.filename)[1].lower()
        
        if file_ext not in allowed_extensions:
            raise HTTPException(status_code=400, detail=f"허용되지 않는 파일 형식입니다. 허용: {allowed_extensions}")
        
        # 고유한 파일명 생성 (user_id_timestamp_uuid.ext)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        
        if user_id:
            filename = f"user{user_id}_{timestamp}_{unique_id}{file_ext}"
        else:
            filename = f"food_{timestamp}_{unique_id}{file_ext}"
        
        # 파일 저장 경로
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        # 파일 저장
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # 상대 경로 반환 (클라이언트에서 접근할 URL)
        image_url = f"/uploads/{filename}"
        
        print(f"[Upload] 이미지 저장 완료: {file_path}")
        
        return {
            "success": True,
            "filename": filename,
            "image_url": image_url,
            "full_path": file_path
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Upload] 이미지 업로드 실패: {e}")
        raise HTTPException(status_code=500, detail=f"이미지 업로드 실패: {str(e)}")


@router.post("/upload-image-base64", tags=["images"])
async def upload_image_base64(
    image_base64: str = Form(...),
    user_id: int = Form(None),
    file_ext: str = Form(".jpg")
):
    """
    Base64 이미지 업로드
    - Base64로 인코딩된 이미지를 디코딩하여 저장
    - 저장된 이미지 경로를 반환
    """
    try:
        # 파일 확장자 확인
        allowed_extensions = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
        if file_ext.lower() not in allowed_extensions:
            file_ext = ".jpg"
        
        # Base64 디코딩
        try:
            # data:image/jpeg;base64, 형식 처리
            if "," in image_base64:
                image_base64 = image_base64.split(",")[1]
            
            image_data = base64.b64decode(image_base64)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Base64 디코딩 실패: {str(e)}")
        
        # 고유한 파일명 생성
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        
        if user_id:
            filename = f"user{user_id}_{timestamp}_{unique_id}{file_ext}"
        else:
            filename = f"food_{timestamp}_{unique_id}{file_ext}"
        
        # 파일 저장 경로
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        # 파일 저장
        with open(file_path, "wb") as f:
            f.write(image_data)
        
        # 상대 경로 반환
        image_url = f"/uploads/{filename}"
        
        print(f"[Upload] Base64 이미지 저장 완료: {file_path}")
        
        return {
            "success": True,
            "filename": filename,
            "image_url": image_url,
            "full_path": file_path
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Upload] Base64 이미지 업로드 실패: {e}")
        raise HTTPException(status_code=500, detail=f"이미지 업로드 실패: {str(e)}")


@router.delete("/delete-image/{filename}", tags=["images"])
async def delete_image(filename: str):
    """이미지 삭제"""
    try:
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"[Upload] 이미지 삭제 완료: {file_path}")
            return {"success": True, "message": "이미지가 삭제되었습니다"}
        else:
            raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Upload] 이미지 삭제 실패: {e}")
        raise HTTPException(status_code=500, detail=f"이미지 삭제 실패: {str(e)}")


# ============ 사용자 설정 API ============

@router.get("/user-settings/{user_id}", response_model=UserSettingsResponse, tags=["settings"])
async def get_user_settings(user_id: int, db: Session = Depends(get_db)):
    """사용자 설정 조회"""
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()

    if not settings:
        # 설정이 없으면 기본값으로 생성
        settings = UserSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)

    return settings


@router.post("/user-settings", response_model=UserSettingsResponse, tags=["settings"])
async def save_user_settings(settings_data: UserSettingsCreate, db: Session = Depends(get_db)):
    """사용자 설정 저장/업데이트"""
    existing = db.query(UserSettings).filter(UserSettings.user_id == settings_data.user_id).first()

    if existing:
        # 업데이트
        existing.meal_reminder = settings_data.meal_reminder
        existing.breakfast_reminder = settings_data.breakfast_reminder
        existing.lunch_reminder = settings_data.lunch_reminder
        existing.dinner_reminder = settings_data.dinner_reminder
        existing.goal_achievement = settings_data.goal_achievement
        existing.weekly_report = settings_data.weekly_report
        existing.breakfast_hour = settings_data.breakfast_hour
        existing.breakfast_minute = settings_data.breakfast_minute
        existing.lunch_hour = settings_data.lunch_hour
        existing.lunch_minute = settings_data.lunch_minute
        existing.dinner_hour = settings_data.dinner_hour
        existing.dinner_minute = settings_data.dinner_minute
        existing.recommend_min_price = settings_data.recommend_min_price
        existing.recommend_max_price = settings_data.recommend_max_price
        existing.skip_price_dialog = settings_data.skip_price_dialog
        existing.activity_level = settings_data.activity_level
        existing.diet_goal = settings_data.diet_goal
        db.commit()
        db.refresh(existing)
        return existing
    else:
        # 새로 생성
        settings = UserSettings(
            user_id=settings_data.user_id,
            meal_reminder=settings_data.meal_reminder,
            breakfast_reminder=settings_data.breakfast_reminder,
            lunch_reminder=settings_data.lunch_reminder,
            dinner_reminder=settings_data.dinner_reminder,
            goal_achievement=settings_data.goal_achievement,
            weekly_report=settings_data.weekly_report,
            breakfast_hour=settings_data.breakfast_hour,
            breakfast_minute=settings_data.breakfast_minute,
            lunch_hour=settings_data.lunch_hour,
            lunch_minute=settings_data.lunch_minute,
            dinner_hour=settings_data.dinner_hour,
            dinner_minute=settings_data.dinner_minute,
            recommend_min_price=settings_data.recommend_min_price,
            recommend_max_price=settings_data.recommend_max_price,
            skip_price_dialog=settings_data.skip_price_dialog,
            activity_level=settings_data.activity_level,
            diet_goal=settings_data.diet_goal
        )
        db.add(settings)
        db.commit()
        db.refresh(settings)
        return settings
