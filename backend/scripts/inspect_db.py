import sqlite3
import json

conn = sqlite3.connect('jjikbap.db')
cursor = conn.cursor()

# Check food_records table
print("=" * 50)
print("food_records TABLE SCHEMA:")
print("=" * 50)
cursor.execute('PRAGMA table_info(food_records)')
for row in cursor.fetchall():
    print(f"  {row[1]:20} {row[2]:10}")

print("\n" + "=" * 50)
print("food_records TABLE DATA:")
print("=" * 50)
cursor.execute('SELECT * FROM food_records LIMIT 5')
rows = cursor.fetchall()
if rows:
    cursor.execute('PRAGMA table_info(food_records)')
    columns = [col[1] for col in cursor.fetchall()]
    for row in rows:
        print("\nRecord:")
        for col, val in zip(columns, row):
            print(f"  {col:20}: {val}")
else:
    print("  No data found")

# Check posts table
print("\n" + "=" * 50)
print("posts TABLE SCHEMA:")
print("=" * 50)
cursor.execute('PRAGMA table_info(posts)')
for row in cursor.fetchall():
    print(f"  {row[1]:20} {row[2]:10}")

print("\n" + "=" * 50)
print("posts TABLE DATA:")
print("=" * 50)
cursor.execute('SELECT * FROM posts LIMIT 5')
rows = cursor.fetchall()
if rows:
    cursor.execute('PRAGMA table_info(posts)')
    columns = [col[1] for col in cursor.fetchall()]
    for row in rows:
        print("\nPost:")
        for col, val in zip(columns, row):
            print(f"  {col:20}: {val}")
else:
    print("  No data found")

# Get counts
print("\n" + "=" * 50)
print("DATABASE STATISTICS:")
print("=" * 50)
cursor.execute('SELECT COUNT(*) FROM food_records')
print(f"Total food_records: {cursor.fetchone()[0]}")

cursor.execute('SELECT COUNT(*) FROM posts')
print(f"Total posts: {cursor.fetchone()[0]}")

cursor.execute('SELECT COUNT(*) FROM nutrition_goals')
print(f"Total nutrition_goals: {cursor.fetchone()[0]}")

# Check for image_path entries
cursor.execute('SELECT COUNT(*) FROM food_records WHERE image_path IS NOT NULL')
food_with_images = cursor.fetchone()[0]
print(f"\nfood_records with images: {food_with_images}")

cursor.execute('SELECT COUNT(*) FROM posts WHERE image_path IS NOT NULL')
posts_with_images = cursor.fetchone()[0]
print(f"posts with images: {posts_with_images}")

conn.close()
