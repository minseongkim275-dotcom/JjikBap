"""
샘플 음식 데이터를 백엔드 SQLite DB에 삽입하는 스크립트
이미지 파일 경로와 함께 과거 14일간의 데이터를 생성
"""
import sqlite3
import os
from datetime import datetime, timedelta
import shutil

# backend 폴더 기준 경로 (이 스크립트는 backend/scripts/ 에 있음)
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# DB 경로
DB_PATH = os.path.join(BACKEND_DIR, "jjikbap.db")
# 이미지 저장 경로 (uploads 폴더)
UPLOADS_DIR = os.path.join(BACKEND_DIR, "uploads")
# 원본 샘플 이미지 경로
SAMPLE_IMAGES_DIR = os.path.join(BACKEND_DIR, "sample_data")

# uploads 폴더 생성
os.makedirs(UPLOADS_DIR, exist_ok=True)

# 샘플 데이터 정의 (음식명, 칼로리, 단백질, 탄수화물, 지방, 이미지 파일명, 며칠 전)
SAMPLE_FOODS = [
    # 오늘
    {"name": "김치찌개", "cal": 450, "pro": 22, "carb": 35, "fat": 18, "img": "kimchi_stew.jpg", "days": 0, "hour": 12},
    {"name": "닭가슴살 샐러드", "cal": 320, "pro": 35, "carb": 12, "fat": 8, "img": "salad.jpg", "days": 0, "hour": 19},
    # 1일 전
    {"name": "비빔밥", "cal": 580, "pro": 18, "carb": 85, "fat": 15, "img": "bibimbap.jpg", "days": 1, "hour": 12},
    {"name": "삼겹살 구이", "cal": 750, "pro": 28, "carb": 5, "fat": 55, "img": "bbq.jpg", "days": 1, "hour": 19},
    # 2일 전
    {"name": "불고기", "cal": 520, "pro": 32, "carb": 25, "fat": 22, "img": "bulgogi.jpg", "days": 2, "hour": 12},
    {"name": "볶음밥", "cal": 480, "pro": 12, "carb": 65, "fat": 15, "img": "fried_rice.jpg", "days": 2, "hour": 18},
    # 3일 전
    {"name": "치킨", "cal": 850, "pro": 45, "carb": 30, "fat": 52, "img": "chicken.jpg", "days": 3, "hour": 19},
    {"name": "라면", "cal": 500, "pro": 10, "carb": 70, "fat": 18, "img": "ramen.jpg", "days": 3, "hour": 22},
    # 4일 전
    {"name": "피자", "cal": 720, "pro": 28, "carb": 80, "fat": 32, "img": "pizza.jpg", "days": 4, "hour": 12},
    {"name": "햄버거", "cal": 650, "pro": 30, "carb": 45, "fat": 35, "img": "burger.jpg", "days": 4, "hour": 19},
    # 5일 전
    {"name": "초밥", "cal": 380, "pro": 22, "carb": 55, "fat": 8, "img": "sushi.jpg", "days": 5, "hour": 12},
    {"name": "스테이크", "cal": 550, "pro": 45, "carb": 5, "fat": 35, "img": "steak.jpg", "days": 5, "hour": 19},
    # 6일 전
    {"name": "파스타", "cal": 620, "pro": 18, "carb": 85, "fat": 22, "img": "pasta.jpg", "days": 6, "hour": 12},
    {"name": "헬시볼", "cal": 420, "pro": 25, "carb": 45, "fat": 15, "img": "healthy_bowl.jpg", "days": 6, "hour": 19},
    # 7일 전
    {"name": "카레라이스", "cal": 580, "pro": 18, "carb": 75, "fat": 20, "img": "curry.jpg", "days": 7, "hour": 12},
    {"name": "그릴 고기", "cal": 680, "pro": 42, "carb": 8, "fat": 45, "img": "grilled_meat.jpg", "days": 7, "hour": 19},
    # 8일 전
    {"name": "팬케이크", "cal": 450, "pro": 10, "carb": 65, "fat": 18, "img": "pancakes.jpg", "days": 8, "hour": 9},
    {"name": "야채 샐러드", "cal": 180, "pro": 5, "carb": 25, "fat": 8, "img": "vegetable.jpg", "days": 8, "hour": 12},
    # 9일 전
    {"name": "우동", "cal": 420, "pro": 14, "carb": 72, "fat": 8, "img": "noodles.jpg", "days": 9, "hour": 12},
    {"name": "타코", "cal": 380, "pro": 18, "carb": 35, "fat": 18, "img": "taco.jpg", "days": 9, "hour": 19},
    # 10일 전
    {"name": "샌드위치", "cal": 420, "pro": 22, "carb": 42, "fat": 18, "img": "sandwich.jpg", "days": 10, "hour": 12},
    {"name": "수프", "cal": 220, "pro": 12, "carb": 25, "fat": 8, "img": "soup.jpg", "days": 10, "hour": 19},
    # 11일 전
    {"name": "프렌치 토스트", "cal": 380, "pro": 12, "carb": 48, "fat": 16, "img": "french_toast.jpg", "days": 11, "hour": 9},
    {"name": "브런치", "cal": 520, "pro": 28, "carb": 45, "fat": 25, "img": "brunch.jpg", "days": 11, "hour": 12},
    # 12일 전
    {"name": "아침식사", "cal": 480, "pro": 22, "carb": 55, "fat": 18, "img": "breakfast.jpg", "days": 12, "hour": 8},
]


def copy_images():
    """샘플 이미지를 uploads 폴더로 복사"""
    print("이미지 복사 중...")
    for food in SAMPLE_FOODS:
        src = os.path.join(SAMPLE_IMAGES_DIR, food["img"])
        dst = os.path.join(UPLOADS_DIR, food["img"])
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy2(src, dst)
            print(f"  복사: {food['img']}")
        elif os.path.exists(dst):
            print(f"  이미 존재: {food['img']}")
        else:
            print(f"  원본 없음: {src}")


def insert_food_records():
    """음식 기록 삽입"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 기존 샘플 데이터 삭제 (description이 '샘플 데이터'인 것)
    cursor.execute("DELETE FROM food_records WHERE description = '샘플 데이터'")
    print(f"기존 샘플 데이터 삭제됨")

    now = datetime.now()
    inserted = 0

    for food in SAMPLE_FOODS:
        created_at = now - timedelta(days=food["days"])
        created_at = created_at.replace(hour=food["hour"], minute=0, second=0)

        # 이미지 경로 (상대 경로)
        image_path = f"uploads/{food['img']}"

        cursor.execute("""
            INSERT INTO food_records
            (food_name, calories, protein, carbs, fat, fiber, image_path, description, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            food["name"],
            food["cal"],
            food["pro"],
            food["carb"],
            food["fat"],
            2.0,  # fiber
            image_path,
            "샘플 데이터",
            created_at.strftime("%Y-%m-%d %H:%M:%S")
        ))
        inserted += 1

    conn.commit()
    print(f"음식 기록 {inserted}개 삽입 완료!")

    # 확인
    cursor.execute("SELECT COUNT(*) FROM food_records")
    total = cursor.fetchone()[0]
    print(f"전체 음식 기록: {total}개")

    conn.close()


def main():
    print("=" * 50)
    print("샘플 데이터 삽입 스크립트")
    print("=" * 50)

    # 이미지 복사
    copy_images()

    # 데이터 삽입
    insert_food_records()

    print("\n완료!")


if __name__ == "__main__":
    main()
