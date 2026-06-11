import psycopg2

def main():
    try:
        conn = psycopg2.connect(
            host="aws-1-ap-south-1.pooler.supabase.com",
            port=5432,
            dbname="postgres",
            user="postgres.uodmjwjnhinbbvexbyvd",
            password="akshitsha84",
            sslmode="require"
        )
        cur = conn.cursor()
        cur.execute('SELECT id, email, "qrCode" FROM public."User" WHERE role=\'TEACHER\';')
        rows = cur.fetchall()
        print(f"Found {len(rows)} teachers:")
        for r in rows:
            qr_val = r[2]
            print(f"ID: {r[0]} | Email: {r[1]} | QR Value (length={len(qr_val) if qr_val else None}): {str(qr_val)[:100]}")
        conn.close()
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
