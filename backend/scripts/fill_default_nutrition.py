"""
새 모델의 음식들을 영양 정보 DB에 추가/업데이트하는 스크립트
"""
import json
from pathlib import Path

def main():
    base_dir = Path(__file__).resolve().parent.parent / "app" / "ml_models"

    # 기존 영양 정보 로드
    nutrition_path = base_dir / "food_nutrition_lookup.json"
    with open(nutrition_path, 'r', encoding='utf-8') as f:
        nutrition_db = json.load(f)

    print(f"기존 영양 정보: {len(nutrition_db)}개 음식")

    # 새 클래스 ID -> 음식 이름 매핑 로드
    class_id_path = base_dir / "class_id_to_food.json"
    with open(class_id_path, 'r', encoding='utf-8') as f:
        class_id_to_food = json.load(f)

    print(f"새 음식 매핑: {len(class_id_to_food)}개 음식")

    # 새 음식들 추가 (기존에 없는 것만)
    added_count = 0
    updated_count = 0

    # 기본 영양 정보 (1인분 기준 추정치)
    default_nutrition = {
        "e": 300.0,      # 칼로리 (kcal)
        "cal": 40.0,     # 탄수화물 (g)
        "fat": 10.0,     # 지방 (g)
        "pro": 15.0,     # 단백질 (g)
        "na": 500.0,     # 나트륨 (mg)
        "chol": 30.0,    # 콜레스테롤 (mg)
        "total_sfa": 3.0,  # 포화지방산 (g)
        "total_tfa": 0.1   # 트랜스지방산 (g)
    }

    for class_id, food_name in class_id_to_food.items():
        if food_name in nutrition_db:
            # 이미 존재하면 업데이트 (기존 값 유지, 누락된 필드만 추가)
            for key, value in default_nutrition.items():
                if key not in nutrition_db[food_name]:
                    nutrition_db[food_name][key] = value
            updated_count += 1
        else:
            # 새로 추가
            nutrition_db[food_name] = default_nutrition.copy()
            added_count += 1

    print(f"추가된 음식: {added_count}개")
    print(f"업데이트된 음식: {updated_count}개")
    print(f"총 음식 수: {len(nutrition_db)}개")

    # 저장
    with open(nutrition_path, 'w', encoding='utf-8') as f:
        json.dump(nutrition_db, f, ensure_ascii=False, indent=2)

    print(f"✓ 영양 정보 DB 업데이트 완료: {nutrition_path}")

    # 새 labels.txt 생성 (음식 이름 목록)
    labels_path = base_dir / "classifier_labels.txt"

    # 클래스 ID 순서대로 정렬
    sorted_items = sorted(class_id_to_food.items(), key=lambda x: x[0])

    with open(labels_path, 'w', encoding='utf-8') as f:
        for class_id, food_name in sorted_items:
            f.write(f"{food_name}\n")

    print(f"✓ 새 라벨 파일 생성 완료: {labels_path}")
    print(f"  총 {len(sorted_items)}개 클래스")

if __name__ == "__main__":
    main()
