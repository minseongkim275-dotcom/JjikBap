"""데이터 무결성 검증 스크립트"""
import json
from pathlib import Path

ml_dir = Path('app/ml_models')

print('=== 데이터 검증 ===')
print()

# 1. food_prices.json
prices_path = ml_dir / 'food_prices.json'
if prices_path.exists():
    with open(prices_path, 'r', encoding='utf-8') as f:
        prices = json.load(f)
    print(f'food_prices.json: {len(prices)}개 음식')
else:
    print('food_prices.json: 없음')

# 2. food_nutrition_lookup.json
nutrition_path = ml_dir / 'food_nutrition_lookup.json'
if nutrition_path.exists():
    with open(nutrition_path, 'r', encoding='utf-8') as f:
        nutrition = json.load(f)
    print(f'food_nutrition_lookup.json: {len(nutrition)}개 음식')
else:
    print('food_nutrition_lookup.json: 없음')

# 3. class_id_to_food.json
class_path = ml_dir / 'class_id_to_food.json'
if class_path.exists():
    with open(class_path, 'r', encoding='utf-8') as f:
        class_mapping = json.load(f)
    print(f'class_id_to_food.json: {len(class_mapping)}개 매핑')
else:
    print('class_id_to_food.json: 없음')

# 4. classifier_labels.txt
labels_path = ml_dir / 'classifier_labels.txt'
if labels_path.exists():
    with open(labels_path, 'r', encoding='utf-8') as f:
        labels = [l.strip() for l in f if l.strip()]
    print(f'classifier_labels.txt: {len(labels)}개 라벨')
else:
    print('classifier_labels.txt: 없음')

# 5. food_embedding_db.json
emb_path = ml_dir / 'food_embedding_db.json'
if emb_path.exists():
    with open(emb_path, 'r', encoding='utf-8') as f:
        emb_db = json.load(f)
    print(f'food_embedding_db.json: {len(emb_db)}개 임베딩')
else:
    print('food_embedding_db.json: 없음')

print()
print('=== 일관성 검사 ===')

# 가격 데이터에 영양정보가 있는지 확인
if prices and nutrition:
    missing_nutrition = [f for f in prices if f not in nutrition]
    if missing_nutrition:
        print(f'가격O 영양정보X: {len(missing_nutrition)}개')
        print(f'  예: {missing_nutrition[:5]}')
    else:
        print('가격 데이터의 모든 음식에 영양정보 있음')

# 클래스 매핑에 영양정보가 있는지 확인
if class_mapping and nutrition:
    missing_class_nutrition = [f for f in class_mapping.values() if f not in nutrition]
    if missing_class_nutrition:
        print(f'클래스O 영양정보X: {len(missing_class_nutrition)}개')
    else:
        print('클래스 매핑의 모든 음식에 영양정보 있음')

print()
print('=== 검증 완료 ===')
