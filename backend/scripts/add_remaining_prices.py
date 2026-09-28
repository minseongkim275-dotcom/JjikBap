"""남은 누락 음식 가격 추가"""
import json
from pathlib import Path

prices_path = Path('app/ml_models/food_prices.json')
with open(prices_path, 'r', encoding='utf-8') as f:
    prices = json.load(f)

# 남은 누락 음식 가격 추가
REMAINING = {
    "광어회": 30000,       # 광어회 30,000원
    "낙지호롱": 18000,     # 낙지호롱 18,000원
    "내장볶음": 15000,     # 내장볶음 15,000원
    "대구뽈찜": 35000,     # 대구뽈찜 35,000원
    "대하구이": 25000,     # 대하구이 25,000원
    "돼지불백": 12000,     # 돼지불백 12,000원
}

for food_name, base_price in REMAINING.items():
    prices[food_name] = {
        "base_price": base_price,
        "min_price": int(base_price * 0.9),
        "max_price": int(base_price * 1.1),
        "currency": "KRW",
        "unit": "1인분",
        "region": "서울"
    }
    print(f'추가: {food_name} - {base_price:,}원')

with open(prices_path, 'w', encoding='utf-8') as f:
    json.dump(prices, f, ensure_ascii=False, indent=2)

print(f'\n저장 완료: {len(prices)}개 음식')
