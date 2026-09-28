"""
700개 음식에 대한 서울 기준 표준 가격 데이터 생성
카테고리별로 분류하고 ±10% 추천 가격대 설정
"""
import json
import re
from pathlib import Path

# 음식 카테고리별 기준 가격 (서울 2024-2025 기준)
CATEGORY_PRICES = {
    # 한식 밥류
    "비빔밥": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "덮밥": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "볶음밥": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "국밥": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "컵밥": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},

    # 면류
    "국수": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},
    "칼국수": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "냉면": {"base": 11000, "min_mult": 0.9, "max_mult": 1.1},
    "라면": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},
    "라멘": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "우동": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "파스타": {"base": 14000, "min_mult": 0.9, "max_mult": 1.1},
    "쌀국수": {"base": 10000, "min_mult": 0.9, "max_mult": 1.1},
    "소바": {"base": 10000, "min_mult": 0.9, "max_mult": 1.1},

    # 찌개/탕류
    "찌개": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},
    "탕": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "전골": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "찜": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "국": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},
    "해장국": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},

    # 구이류
    "구이": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "불고기": {"base": 14000, "min_mult": 0.9, "max_mult": 1.1},
    "갈비": {"base": 18000, "min_mult": 0.9, "max_mult": 1.1},
    "삼겹살": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "스테이크": {"base": 25000, "min_mult": 0.9, "max_mult": 1.1},

    # 튀김류
    "돈가스": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "돈까스": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "카츠": {"base": 13000, "min_mult": 0.9, "max_mult": 1.1},
    "튀김": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},
    "고로케": {"base": 3500, "min_mult": 0.9, "max_mult": 1.1},

    # 치킨류
    "치킨": {"base": 20000, "min_mult": 0.9, "max_mult": 1.1},
    "닭갈비": {"base": 13000, "min_mult": 0.9, "max_mult": 1.1},
    "닭볶음탕": {"base": 13000, "min_mult": 0.9, "max_mult": 1.1},

    # 분식류
    "떡볶이": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},
    "김밥": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "순대": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},
    "만두": {"base": 7000, "min_mult": 0.9, "max_mult": 1.1},
    "전": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},

    # 피자/버거
    "피자": {"base": 18000, "min_mult": 0.9, "max_mult": 1.1},
    "버거": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},
    "샌드위치": {"base": 6000, "min_mult": 0.9, "max_mult": 1.1},
    "토스트": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "핫도그": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},

    # 일식
    "초밥": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},  # 1피스
    "롤": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "동": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},  # 돈부리
    "나베": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "오코노미야끼": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "타코야끼": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},

    # 중식
    "짜장": {"base": 7000, "min_mult": 0.9, "max_mult": 1.1},
    "짬뽕": {"base": 8000, "min_mult": 0.9, "max_mult": 1.1},
    "탕수육": {"base": 20000, "min_mult": 0.9, "max_mult": 1.1},
    "마라": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "양꼬치": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},  # 1꼬치

    # 양식
    "리조또": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "그라탕": {"base": 13000, "min_mult": 0.9, "max_mult": 1.1},
    "샐러드": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},

    # 동남아
    "쌀국수": {"base": 10000, "min_mult": 0.9, "max_mult": 1.1},
    "팟타이": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "커리": {"base": 11000, "min_mult": 0.9, "max_mult": 1.1},
    "부리또": {"base": 10000, "min_mult": 0.9, "max_mult": 1.1},
    "타코": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},
    "포케": {"base": 14000, "min_mult": 0.9, "max_mult": 1.1},

    # 족발/보쌈
    "족발": {"base": 35000, "min_mult": 0.9, "max_mult": 1.1},
    "보쌈": {"base": 35000, "min_mult": 0.9, "max_mult": 1.1},

    # 회/해산물
    "회": {"base": 20000, "min_mult": 0.9, "max_mult": 1.1},
    "해물": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "새우": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "조개": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},

    # 곱창/내장
    "곱창": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "막창": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},
    "대창": {"base": 15000, "min_mult": 0.9, "max_mult": 1.1},

    # 떡류
    "떡": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},
    "호떡": {"base": 2000, "min_mult": 0.9, "max_mult": 1.1},
    "송편": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},

    # 빵/디저트
    "빵": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "케이크": {"base": 7000, "min_mult": 0.9, "max_mult": 1.1},  # 조각
    "마카롱": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},
    "크로와상": {"base": 4500, "min_mult": 0.9, "max_mult": 1.1},
    "베이글": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "스콘": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "도넛": {"base": 3500, "min_mult": 0.9, "max_mult": 1.1},
    "타르트": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},
    "파이": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},
    "와플": {"base": 7000, "min_mult": 0.9, "max_mult": 1.1},
    "크로플": {"base": 6000, "min_mult": 0.9, "max_mult": 1.1},
    "붕어빵": {"base": 2000, "min_mult": 0.9, "max_mult": 1.1},
    "호두과자": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},
    "까눌레": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "휘낭시에": {"base": 3500, "min_mult": 0.9, "max_mult": 1.1},
    "마들렌": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},
    "브라우니": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "티라미수": {"base": 7000, "min_mult": 0.9, "max_mult": 1.1},
    "크레이프": {"base": 6000, "min_mult": 0.9, "max_mult": 1.1},

    # 죽류
    "죽": {"base": 9000, "min_mult": 0.9, "max_mult": 1.1},

    # 수프류
    "수프": {"base": 7000, "min_mult": 0.9, "max_mult": 1.1},

    # 시리얼/간편식
    "시리얼": {"base": 5000, "min_mult": 0.9, "max_mult": 1.1},
    "닭가슴살": {"base": 4000, "min_mult": 0.9, "max_mult": 1.1},
    "소시지": {"base": 3000, "min_mult": 0.9, "max_mult": 1.1},
    "핫바": {"base": 2000, "min_mult": 0.9, "max_mult": 1.1},

    # 볶음류
    "볶음": {"base": 12000, "min_mult": 0.9, "max_mult": 1.1},
    "두루치기": {"base": 10000, "min_mult": 0.9, "max_mult": 1.1},

    # 기본값
    "default": {"base": 10000, "min_mult": 0.9, "max_mult": 1.1},
}

def get_food_category(food_name: str) -> dict:
    """음식 이름에서 카테고리 추출 및 가격 정보 반환"""

    # 우선순위가 높은 키워드부터 매칭
    priority_keywords = [
        # 특정 음식 (가장 먼저 체크)
        "시리얼", "닭가슴살", "소시지", "핫바",
        "마카롱", "크로와상", "베이글", "스콘", "도넛", "타르트", "파이",
        "와플", "크로플", "붕어빵", "호두과자", "까눌레", "휘낭시에",
        "마들렌", "브라우니", "티라미수", "크레이프",

        # 치킨 (치킨이 먼저 와야 함)
        "치킨",

        # 일식
        "돈부리", "카츠동", "규동", "에비동", "부타동", "카이센동",
        "오코노미야끼", "타코야끼", "나베",

        # 면류 (구체적인 것 먼저)
        "칼국수", "냉면", "쌀국수", "라멘", "파스타", "우동", "소바", "국수", "라면",

        # 밥류
        "비빔밥", "덮밥", "볶음밥", "국밥", "컵밥",

        # 찌개/탕
        "해장국", "전골", "찌개", "탕", "찜", "국",

        # 구이
        "갈비", "삼겹살", "스테이크", "불고기", "구이",

        # 튀김
        "돈까스", "돈가스", "카츠", "고로케", "튀김",

        # 분식
        "떡볶이", "김밥", "순대", "만두", "전",

        # 피자/버거
        "피자", "버거", "샌드위치", "토스트", "핫도그",

        # 일식
        "초밥", "롤",

        # 중식
        "마라", "짬뽕", "짜장", "탕수육", "양꼬치",

        # 양식
        "리조또", "그라탕", "샐러드",

        # 동남아/멕시칸
        "팟타이", "커리", "부리또", "타코", "포케",

        # 족발/보쌈
        "족발", "보쌈",

        # 해산물
        "회", "해물", "새우", "조개",

        # 곱창
        "곱창", "막창", "대창",

        # 떡
        "호떡", "송편", "떡",

        # 빵
        "케이크", "빵",

        # 죽/수프
        "죽", "수프",

        # 볶음
        "두루치기", "볶음",

        # 닭요리
        "닭갈비", "닭볶음탕",
    ]

    for keyword in priority_keywords:
        if keyword in food_name:
            if keyword in CATEGORY_PRICES:
                return CATEGORY_PRICES[keyword]
            # 동으로 끝나는 일본식 덮밥
            if keyword.endswith("동"):
                return CATEGORY_PRICES["동"]

    return CATEGORY_PRICES["default"]


def generate_food_prices():
    """700개 음식에 대한 가격 데이터 생성"""

    base_dir = Path(__file__).resolve().parent.parent / "app" / "ml_models"

    # class_id_to_food.json 로드
    with open(base_dir / "class_id_to_food.json", 'r', encoding='utf-8') as f:
        class_id_to_food = json.load(f)

    print(f"총 {len(class_id_to_food)}개 음식 처리 중...")

    food_prices = {}
    category_stats = {}

    for class_id, food_name in class_id_to_food.items():
        price_info = get_food_category(food_name)

        base_price = price_info["base"]
        min_price = int(base_price * price_info["min_mult"])
        max_price = int(base_price * price_info["max_mult"])

        food_prices[food_name] = {
            "base_price": base_price,
            "min_price": min_price,
            "max_price": max_price,
            "currency": "KRW",
            "unit": "1인분",
            "region": "서울"
        }

        # 통계
        cat = None
        for kw in CATEGORY_PRICES.keys():
            if kw in food_name and kw != "default":
                cat = kw
                break
        if cat is None:
            cat = "기타"
        category_stats[cat] = category_stats.get(cat, 0) + 1

    # 저장
    output_path = base_dir / "food_prices.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(food_prices, f, ensure_ascii=False, indent=2)

    print(f"\n✓ 가격 데이터 저장 완료: {output_path}")
    print(f"  총 {len(food_prices)}개 음식")

    # 카테고리별 통계 출력
    print(f"\n카테고리별 분포:")
    for cat, count in sorted(category_stats.items(), key=lambda x: -x[1])[:20]:
        print(f"  {cat}: {count}개")

    # 샘플 출력
    print(f"\n샘플 데이터:")
    samples = ["비빔밥", "김치찌개", "돈까스", "치킨", "피자", "마라탕"]
    for sample in samples:
        for food_name, price in food_prices.items():
            if sample in food_name:
                print(f"  {food_name}: {price['min_price']:,}원 ~ {price['max_price']:,}원 (기준: {price['base_price']:,}원)")
                break


if __name__ == "__main__":
    generate_food_prices()
