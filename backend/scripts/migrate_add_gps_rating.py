import sqlite3
import sys

def migrate_database():
    """Add latitude, longitude, and rating columns to food_records table"""
    try:
        conn = sqlite3.connect('jjikbap.db')
        cursor = conn.cursor()

        # Check current schema
        print("=" * 50)
        print("Current food_records schema:")
        print("=" * 50)
        cursor.execute('PRAGMA table_info(food_records)')
        columns = [row[1] for row in cursor.fetchall()]
        for col in columns:
            print(f"  - {col}")

        # Check if columns already exist
        needs_migration = False
        if 'latitude' not in columns:
            print("\n✓ Need to add 'latitude' column")
            needs_migration = True
        else:
            print("\n✓ 'latitude' column already exists")

        if 'longitude' not in columns:
            print("✓ Need to add 'longitude' column")
            needs_migration = True
        else:
            print("✓ 'longitude' column already exists")

        if 'rating' not in columns:
            print("✓ Need to add 'rating' column")
            needs_migration = True
        else:
            print("✓ 'rating' column already exists")

        if not needs_migration:
            print("\n" + "=" * 50)
            print("Database is already up to date. No migration needed.")
            print("=" * 50)
            conn.close()
            return

        # Perform migration
        print("\n" + "=" * 50)
        print("Starting migration...")
        print("=" * 50)

        if 'latitude' not in columns:
            cursor.execute('ALTER TABLE food_records ADD COLUMN latitude REAL')
            print("✓ Added 'latitude' column")

        if 'longitude' not in columns:
            cursor.execute('ALTER TABLE food_records ADD COLUMN longitude REAL')
            print("✓ Added 'longitude' column")

        if 'rating' not in columns:
            cursor.execute('ALTER TABLE food_records ADD COLUMN rating INTEGER')
            print("✓ Added 'rating' column")

        conn.commit()

        # Verify new schema
        print("\n" + "=" * 50)
        print("Updated food_records schema:")
        print("=" * 50)
        cursor.execute('PRAGMA table_info(food_records)')
        for row in cursor.fetchall():
            print(f"  {row[1]:20} {row[2]:10}")

        # Check existing data
        cursor.execute('SELECT COUNT(*) FROM food_records')
        total_records = cursor.fetchone()[0]
        print("\n" + "=" * 50)
        print(f"Total records in database: {total_records}")
        print("=" * 50)

        if total_records > 0:
            cursor.execute('SELECT COUNT(*) FROM food_records WHERE latitude IS NOT NULL')
            records_with_gps = cursor.fetchone()[0]
            print(f"Records with GPS data: {records_with_gps}")
            print(f"Records without GPS data: {total_records - records_with_gps}")

        conn.close()

        print("\n" + "=" * 50)
        print("✓ Migration completed successfully!")
        print("=" * 50)
        print("\nNext steps:")
        print("  1. Restart the backend server")
        print("  2. Test uploading a photo with GPS data from the app")
        print("  3. Check if GPS coordinates are saved correctly")

    except Exception as e:
        print(f"\n✗ Migration failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    migrate_database()
