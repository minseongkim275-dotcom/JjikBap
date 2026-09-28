"""
샘플 음식 데이터를 백엔드 SQLite DB에 삽입하는 스크립트
데모 계정을 만들고, 이미지 파일 경로와 함께 과거 14일간의 기록을 그 계정에 생성
"""
import sqlite3
import os
from datetime import datetime, timedelta
import shutil

# 데모 계정 (로컬 시연/스크린샷용)
DEMO_USERNAME = "demo"
DEMO_PASSWORD = "demo1234"
DEMO_NAME = "찍밥데모"

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
    # 음식명은 sample_data/ 사진 내용에 맞춤 (파일명과 사진이 다른 것이 있음: 예 bbq.jpg = 수제버거)
    # 오늘
    {"name": "돌솥비빔밥 정식", "cal": 620, "pro": 20, "carb": 88, "fat": 18, "img": "kimchi_stew.jpg", "days": 0, "hour": 12},
    {"name": "닭가슴살 샐러드", "cal": 320, "pro": 35, "carb": 12, "fat": 8, "img": "salad.jpg", "days": 0, "hour": 19},
    # 1일 전
    {"name": "비빔밥", "cal": 580, "pro": 18, "carb": 85, "fat": 15, "img": "bibimbap.jpg", "days": 1, "hour": 12},
    {"name": "수제버거", "cal": 680, "pro": 32, "carb": 48, "fat": 38, "img": "bbq.jpg", "days": 1, "hour": 19},
    # 2일 전
    {"name": "바비큐 폭립", "cal": 780, "pro": 45, "carb": 20, "fat": 55, "img": "bulgogi.jpg", "days": 2, "hour": 12},
    {"name": "볶음밥", "cal": 480, "pro": 12, "carb": 65, "fat": 15, "img": "fried_rice.jpg", "days": 2, "hour": 18},
    # 3일 전
    {"name": "치킨", "cal": 850, "pro": 45, "carb": 30, "fat": 52, "img": "chicken.jpg", "days": 3, "hour": 19},
    {"name": "라멘", "cal": 550, "pro": 22, "carb": 68, "fat": 20, "img": "ramen.jpg", "days": 3, "hour": 22},
    # 4일 전
    {"name": "피자", "cal": 720, "pro": 28, "carb": 80, "fat": 32, "img": "pizza.jpg", "days": 4, "hour": 12},
    {"name": "햄버거", "cal": 650, "pro": 30, "carb": 45, "fat": 35, "img": "burger.jpg", "days": 4, "hour": 19},
    # 5일 전
    {"name": "연어 롤", "cal": 380, "pro": 22, "carb": 55, "fat": 8, "img": "sushi.jpg", "days": 5, "hour": 12},
    {"name": "꼬치구이", "cal": 520, "pro": 38, "carb": 12, "fat": 34, "img": "steak.jpg", "days": 5, "hour": 19},
    # 6일 전
    {"name": "새우 파스타", "cal": 620, "pro": 26, "carb": 82, "fat": 20, "img": "pasta.jpg", "days": 6, "hour": 12},
    {"name": "연어 포케", "cal": 450, "pro": 28, "carb": 45, "fat": 16, "img": "healthy_bowl.jpg", "days": 6, "hour": 19},
    # 7일 전
    {"name": "곡물 샐러드볼", "cal": 420, "pro": 14, "carb": 60, "fat": 14, "img": "curry.jpg", "days": 7, "hour": 12},
    {"name": "고기 한상", "cal": 680, "pro": 42, "carb": 18, "fat": 45, "img": "grilled_meat.jpg", "days": 7, "hour": 19},
    # 8일 전
    {"name": "팬케이크", "cal": 450, "pro": 10, "carb": 65, "fat": 18, "img": "pancakes.jpg", "days": 8, "hour": 9},
    {"name": "그린 샐러드", "cal": 180, "pro": 5, "carb": 25, "fat": 8, "img": "vegetable.jpg", "days": 8, "hour": 12},
    # 9일 전
    {"name": "미트볼", "cal": 480, "pro": 30, "carb": 18, "fat": 30, "img": "noodles.jpg", "days": 9, "hour": 12},
    {"name": "버거 세트", "cal": 980, "pro": 34, "carb": 95, "fat": 50, "img": "taco.jpg", "days": 9, "hour": 19},
    # 10일 전
    {"name": "그릴 플래터", "cal": 560, "pro": 30, "carb": 35, "fat": 32, "img": "sandwich.jpg", "days": 10, "hour": 12},
    {"name": "포크 스테이크", "cal": 620, "pro": 48, "carb": 22, "fat": 36, "img": "soup.jpg", "days": 10, "hour": 19},
    # 11일 전
    {"name": "프렌치 토스트", "cal": 380, "pro": 12, "carb": 48, "fat": 16, "img": "french_toast.jpg", "days": 11, "hour": 9},
    {"name": "브런치", "cal": 520, "pro": 28, "carb": 45, "fat": 25, "img": "brunch.jpg", "days": 11, "hour": 12},
    # 12일 전
    {"name": "파스타 샐러드", "cal": 420, "pro": 12, "carb": 58, "fat": 16, "img": "breakfast.jpg", "days": 12, "hour": 8},
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


def get_or_create_demo_user(cursor) -> int:
    """데모 계정을 찾거나 새로 만들고 id를 반환"""
    cursor.execute("SELECT id FROM users WHERE username = ?", (DEMO_USERNAME,))
    row = cursor.fetchone()
    if row:
        return row[0]
    # 삭제된 계정의 기록이 남아 있을 수 있으므로, 어떤 기록에도 쓰이지 않은 id를 사용
    cursor.execute(
        "SELECT MAX(m) FROM (SELECT MAX(id) AS m FROM users UNION ALL SELECT MAX(user_id) FROM food_records)"
    )
    new_id = (cursor.fetchone()[0] or 0) + 1
    cursor.execute(
        "INSERT INTO users (id, username, password, name, weight, height, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (new_id, DEMO_USERNAME, DEMO_PASSWORD, DEMO_NAME, 65.0, 172.0, datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
    )
    print(f"데모 계정 생성: {DEMO_USERNAME} (id={new_id})")
    return new_id


def insert_food_records():
    """음식 기록 삽입"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    user_id = get_or_create_demo_user(cursor)

    # 데모 계정의 기존 샘플 데이터만 삭제 (다른 사용자 기록은 건드리지 않음)
    cursor.execute("DELETE FROM food_records WHERE description = '샘플 데이터' AND user_id = ?", (user_id,))
    print(f"기존 샘플 데이터 삭제됨")

    now = datetime.now()
    inserted = 0

    for i, food in enumerate(SAMPLE_FOODS):
        created_at = now - timedelta(days=food["days"])
        created_at = created_at.replace(hour=food["hour"], minute=0, second=0)

        # 이미지 경로 (상대 경로)
        image_path = f"uploads/{food['img']}"

        cursor.execute("""
            INSERT INTO food_records
            (food_name, calories, protein, carbs, fat, fiber, image_path, description, created_at, rating, user_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            food["name"],
            food["cal"],
            food["pro"],
            food["carb"],
            food["fat"],
            2.0,  # fiber
            image_path,
            "샘플 데이터",
            created_at.strftime("%Y-%m-%d %H:%M:%S"),
            3 + i % 3,  # 별점 3~5
            user_id,
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
