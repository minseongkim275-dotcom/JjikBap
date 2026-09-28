import json
from pathlib import Path

prices_path = Path('app/ml_models/food_prices.json')
with open(prices_path, 'r', encoding='utf-8') as f:
    prices = json.load(f)

foods = ['삼계탕', '갈비탕', '닭갈비', '돼지갈비', '돈까스']
for food in foods:
    if food in prices:
        p = prices[food]
        print(f'{food}: {p["min_price"]:,}원 ~ {p["max_price"]:,}원 (기준: {p["base_price"]:,}원)')
    else:
        print(f'{food}: 가격 정보 없음')
