"""가격 범위 검색 테스트"""
import json
from pathlib import Path

# 가격 데이터 로드
prices_path = Path('app/ml_models/food_prices.json')
with open(prices_path, 'r', encoding='utf-8') as f:
    prices = json.load(f)

print('=== 가격 범위 검색 테스트 ===')
print()

def search_by_budget(min_budget, max_budget, limit=10):
    """예산 범위 내 음식 검색 (API 로직과 동일)"""
    matching_foods = []
    for food_name, price_info in prices.items():
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
    return matching_foods[:limit]

# 테스트 1: 5,000원 ~ 8,000원
print('테스트 1: 5,000원 ~ 8,000원')
results = search_by_budget(5000, 8000, limit=5)
print(f'  검색 결과: {len(results)}개')
for r in results:
    print(f'    - {r["food_name"]}: {r["min_price"]:,}원 ~ {r["max_price"]:,}원 (기준: {r["base_price"]:,}원)')
print()

# 테스트 2: 10,000원 ~ 15,000원
print('테스트 2: 10,000원 ~ 15,000원')
results = search_by_budget(10000, 15000, limit=5)
print(f'  검색 결과: {len(results)}개')
for r in results:
    print(f'    - {r["food_name"]}: {r["min_price"]:,}원 ~ {r["max_price"]:,}원 (기준: {r["base_price"]:,}원)')
print()

# 테스트 3: 20,000원 ~ 30,000원 (고가)
print('테스트 3: 20,000원 ~ 30,000원')
results = search_by_budget(20000, 30000, limit=5)
print(f'  검색 결과: {len(results)}개')
for r in results:
    print(f'    - {r["food_name"]}: {r["min_price"]:,}원 ~ {r["max_price"]:,}원 (기준: {r["base_price"]:,}원)')
print()

# 테스트 4: 정확히 가격대 맞는지 확인 (7,000원 정확히)
print('테스트 4: 7,000원 ~ 7,000원 (정확한 가격)')
results = search_by_budget(7000, 7000, limit=10)
print(f'  검색 결과: {len(results)}개')
for r in results:
    print(f'    - {r["food_name"]}: {r["min_price"]:,}원 ~ {r["max_price"]:,}원')
print()

# 전체 가격 분포 확인
print('=== 가격 분포 ===')
price_ranges = {
    '5천원 미만': 0,
    '5천~1만원': 0,
    '1만~1.5만원': 0,
    '1.5만~2만원': 0,
    '2만원 이상': 0
}

for food_name, info in prices.items():
    base = info['base_price']
    if base < 5000:
        price_ranges['5천원 미만'] += 1
    elif base < 10000:
        price_ranges['5천~1만원'] += 1
    elif base < 15000:
        price_ranges['1만~1.5만원'] += 1
    elif base < 20000:
        price_ranges['1.5만~2만원'] += 1
    else:
        price_ranges['2만원 이상'] += 1

for range_name, count in price_ranges.items():
    print(f'  {range_name}: {count}개')
