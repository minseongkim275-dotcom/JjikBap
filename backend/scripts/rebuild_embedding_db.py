"""food_embedding_db.json 수정 - embedding만 추출"""
import json
import re
from pathlib import Path

import sys

# 사용법: python scripts/rebuild_embedding_db.py <원본 food_embedding_db.json 경로>
src_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('food_embedding_db_raw.json')
dst_path = Path('app/ml_models/food_embedding_db.json')

# class_id_to_food.json 로드
class_id_path = Path('app/ml_models/class_id_to_food.json')
with open(class_id_path, 'r', encoding='utf-8') as f:
    class_id_to_food = json.load(f)
print(f'클래스 ID 매핑 로드: {len(class_id_to_food)}개')

data = {}

# 정규식으로 class_id와 embedding 배열만 추출
try:
    with open(src_path, 'rb') as f:
        raw = f.read()

    content = raw.decode('utf-8', errors='replace')

    # "CLASS_ID": { ... "embedding": [...] } 패턴 찾기
    # 클래스 ID 패턴: A13001, B11001, C01001 등
    class_pattern = re.compile(
        r'"([ABC]\d{5})"\s*:\s*\{[^}]*?"embedding"\s*:\s*\[([\d\s.,eE+-]+)\]',
        re.DOTALL
    )

    matches = class_pattern.findall(content)
    print(f'패턴 매칭: {len(matches)}개 발견')

    for class_id, embedding_str in matches:
        try:
            # 숫자 배열로 변환
            embedding = [float(x.strip()) for x in embedding_str.split(',') if x.strip()]
            food_name = class_id_to_food.get(class_id, class_id)
            data[class_id] = {
                'food_name': food_name,
                'embedding': embedding
            }
        except Exception as e:
            print(f'  {class_id} 파싱 실패: {e}')

    print(f'✓ 추출 성공: {len(data)}개 항목')

except Exception as e:
    print(f'✗ 오류: {e}')
    import traceback
    traceback.print_exc()

if data:
    # 샘플 확인
    key = list(data.keys())[0]
    val = data[key]
    print(f'\n샘플 데이터:')
    print(f'  키: {key}')
    if isinstance(val, dict):
        food_name = val.get('food_name', '없음')
        print(f'  food_name: {food_name}')
        if 'embedding' in val:
            print(f'  embedding 길이: {len(val["embedding"])}')

    # class_id_to_food.json에서 올바른 음식 이름 가져오기
    class_id_path = Path('app/ml_models/class_id_to_food.json')
    with open(class_id_path, 'r', encoding='utf-8') as f:
        class_id_to_food = json.load(f)

    # food_name 수정
    fixed_count = 0
    for class_id in data:
        if class_id in class_id_to_food:
            correct_name = class_id_to_food[class_id]
            if data[class_id].get('food_name') != correct_name:
                data[class_id]['food_name'] = correct_name
                fixed_count += 1

    print(f'\n수정된 food_name: {fixed_count}개')

    # UTF-8로 저장
    with open(dst_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False)

    print(f'✓ UTF-8로 저장 완료: {dst_path}')

    # 확인
    with open(dst_path, 'r', encoding='utf-8') as f:
        verify = json.load(f)
    print(f'✓ 검증 완료: {len(verify)}개 항목')
else:
    print('❌ 모든 인코딩 실패')
