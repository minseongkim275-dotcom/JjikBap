"""가격 정보 없는 음식 찾기"""
import json
import sqlite3
from pathlib import Path

# 가격 데이터 로드
prices_path = Path('app/ml_models/food_prices.json')
with open(prices_path, 'r', encoding='utf-8') as f:
    prices = json.load(f)

print(f'가격 정보 있는 음식: {len(prices)}개')

# DB에서 음식 목록 가져오기
db_path = Path('jjikbap.db')
if db_path.exists():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT DISTINCT food_name FROM food_nutrition_db")
    db_foods = [row[0] for row in cursor.fetchall()]
    conn.close()

    print(f'DB 음식: {len(db_foods)}개')

    # 가격 정보 없는 음식
    missing = [f for f in db_foods if f not in prices]
    print(f'\n가격 정보 없는 음식: {len(missing)}개')
    for food in missing:
        print(f'  - {food}')
else:
    print('DB 파일 없음')
