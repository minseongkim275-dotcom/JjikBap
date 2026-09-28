"""데이터베이스 무결성 점검 스크립트"""
import json
import sqlite3
from pathlib import Path

print('=== 데이터베이스 점검 ===')
print()

# 1. SQLite DB 점검
print('1. SQLite 데이터베이스')
print('-' * 50)

db_files = ['jjikbap.db']
for db_file in db_files:
    if Path(db_file).exists():
        print(f'  📁 {db_file}: 존재')
        try:
            conn = sqlite3.connect(db_file)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = cursor.fetchall()
            print(f'     테이블: {[t[0] for t in tables]}')
            for table in tables:
                cursor.execute(f'SELECT COUNT(*) FROM {table[0]}')
                count = cursor.fetchone()[0]
                print(f'     - {table[0]}: {count}개 레코드')

                # 스키마 확인
                cursor.execute(f'PRAGMA table_info({table[0]})')
                columns = cursor.fetchall()
                col_names = [c[1] for c in columns]
                print(f'       컬럼: {col_names}')
            conn.close()
        except Exception as e:
            print(f'     ❌ 오류: {e}')
    else:
        print(f'  📁 {db_file}: 없음')

print()

# 2. JSON DB 점검
print('2. JSON 데이터베이스 (ml_models)')
print('-' * 50)

ml_models_dir = Path('app/ml_models')

# food_nutrition_lookup.json
nutrition_path = ml_models_dir / 'food_nutrition_lookup.json'
nutrition_db = {}
if nutrition_path.exists():
    with open(nutrition_path, 'r', encoding='utf-8') as f:
        nutrition_db = json.load(f)
    print(f'  📁 food_nutrition_lookup.json: {len(nutrition_db)}개 음식')

    # 결함 검사
    issues = []
    for food, info in nutrition_db.items():
        if not isinstance(info, dict):
            issues.append(f'{food}: dict가 아님')
        elif 'e' not in info:
            issues.append(f'{food}: 칼로리(e) 필드 없음')
        elif info.get('e', 0) <= 0:
            issues.append(f'{food}: 칼로리 0 이하 ({info.get("e")})')

    if issues:
        print(f'     ⚠️  결함 발견: {len(issues)}개')
        for issue in issues[:10]:
            print(f'        - {issue}')
        if len(issues) > 10:
            print(f'        ... 외 {len(issues) - 10}개')
    else:
        print('     ✅ 결함 없음')
else:
    print(f'  📁 food_nutrition_lookup.json: 없음 ❌')

print()

# class_id_to_food.json
class_id_path = ml_models_dir / 'class_id_to_food.json'
class_id_db = {}
if class_id_path.exists():
    with open(class_id_path, 'r', encoding='utf-8') as f:
        class_id_db = json.load(f)
    print(f'  📁 class_id_to_food.json: {len(class_id_db)}개 매핑')

    # 결함 검사: 영양 정보에 없는 음식
    missing = []
    for class_id, food in class_id_db.items():
        if food not in nutrition_db:
            missing.append(f'{class_id}: {food}')

    if missing:
        print(f'     ⚠️  영양정보 누락: {len(missing)}개')
        for m in missing[:10]:
            print(f'        - {m}')
    else:
        print('     ✅ 모든 음식 영양정보 존재')
else:
    print(f'  📁 class_id_to_food.json: 없음 ❌')

print()

# classifier_labels.txt
labels_path = ml_models_dir / 'classifier_labels.txt'
if labels_path.exists():
    with open(labels_path, 'r', encoding='utf-8') as f:
        labels = [l.strip() for l in f if l.strip()]
    print(f'  📁 classifier_labels.txt: {len(labels)}개 라벨')

    # class_id_to_food와 일치 검사
    sorted_class_ids = sorted(class_id_db.keys())
    class_foods = [class_id_db[cid] for cid in sorted_class_ids]

    mismatch = []
    for i, label in enumerate(labels):
        if i < len(class_foods) and label != class_foods[i]:
            mismatch.append(f'인덱스 {i}: labels={label}, class_id={class_foods[i]}')

    if mismatch:
        print(f'     ⚠️  불일치: {len(mismatch)}개')
        for m in mismatch[:5]:
            print(f'        - {m}')
    else:
        print('     ✅ class_id_to_food와 순서 일치')
else:
    print(f'  📁 classifier_labels.txt: 없음 ❌')

print()

# labels.txt (Detection 모델용)
labels_path = ml_models_dir / 'labels.txt'
if labels_path.exists():
    with open(labels_path, 'r', encoding='utf-8') as f:
        det_labels = [l.strip() for l in f if l.strip()]
    print(f'  📁 labels.txt (Detection): {len(det_labels)}개 라벨')

    # 영양 정보 매칭 검사
    missing_det = [l for l in det_labels if l not in nutrition_db]
    if missing_det:
        print(f'     ⚠️  영양정보 누락: {len(missing_det)}개')
        for m in missing_det[:5]:
            print(f'        - {m}')
    else:
        print('     ✅ 모든 라벨 영양정보 존재')

print()

# food_embedding_db.json
emb_path = ml_models_dir / 'food_embedding_db.json'
if emb_path.exists():
    file_size = emb_path.stat().st_size / (1024 * 1024)
    print(f'  📁 food_embedding_db.json: {file_size:.1f}MB')

    # 샘플 로드해서 구조 확인
    try:
        with open(emb_path, 'r', encoding='utf-8') as f:
            emb_db = json.load(f)
        print(f'     항목 수: {len(emb_db)}개')

        # 구조 검사
        sample_key = list(emb_db.keys())[0]
        sample_val = emb_db[sample_key]
        print(f'     샘플 키: {sample_key}')
        print(f'     샘플 구조: {list(sample_val.keys()) if isinstance(sample_val, dict) else type(sample_val)}')

        if isinstance(sample_val, dict) and 'embedding' in sample_val:
            emb_len = len(sample_val['embedding'])
            print(f'     임베딩 차원: {emb_len}')
    except Exception as e:
        print(f'     ❌ 로드 오류: {e}')
else:
    print(f'  📁 food_embedding_db.json: 없음')

print()
print('=== 점검 완료 ===')
