import psycopg2

def main():
    db_uri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres"
    conn = psycopg2.connect(db_uri)
    cursor = conn.cursor()
    
    # Inspect TimetableSlot
    print("Columns in TimetableSlot:")
    cursor.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'TimetableSlot';")
    for row in cursor.fetchall():
        print(f"  {row[0]}: {row[1]}")
        
    # Inspect TimetableConfig
    print("\nColumns in TimetableConfig:")
    cursor.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'TimetableConfig';")
    for row in cursor.fetchall():
        print(f"  {row[0]}: {row[1]}")

    # Inspect other timetable related tables
    cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%Time%';")
    print("\nOther tables with 'Time':")
    for row in cursor.fetchall():
        print(f"  {row[0]}")

    cursor.close()
    conn.close()

if __name__ == "__main__":
    main()
