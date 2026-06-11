import psycopg2
import sys

def main():
    # Use credentials from server's .env
    password = "akshitsha84"
    project_ref = "uodmjwjnhinbbvexbyvd"
    username = f"postgres.{project_ref}"
    host = "aws-1-ap-south-1.pooler.supabase.com" # ap-south-1 region
    db_uri = f"postgresql://{username}:{password}@{host}:5432/postgres"
    
    print("Connecting to Supabase PostgreSQL database...")
    try:
        conn = psycopg2.connect(db_uri, connect_timeout=5)
        conn.autocommit = True
        cursor = conn.cursor()
        print("Connected successfully!")
        
        # Create CommunityPost table
        sql = """
        CREATE TABLE IF NOT EXISTS public."CommunityPost" (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            author_name TEXT,
            author_role TEXT,
            category TEXT,
            content TEXT,
            poll_options JSONB DEFAULT '[]'::jsonb,
            comments JSONB DEFAULT '[]'::jsonb,
            likes INT DEFAULT 0,
            insightfuls INT DEFAULT 0,
            userLiked BOOLEAN DEFAULT false,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
        );
        
        -- Enable RLS
        ALTER TABLE public."CommunityPost" ENABLE ROW LEVEL SECURITY;
        
        -- Drop policy if exists and create
        DROP POLICY IF EXISTS "Allow all actions for CommunityPost" ON public."CommunityPost";
        CREATE POLICY "Allow all actions for CommunityPost" ON public."CommunityPost" FOR ALL USING (true) WITH CHECK (true);
        """
        
        cursor.execute(sql)
        print("CommunityPost table successfully created and RLS policies set!")
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error executing SQL: {e}")

if __name__ == "__main__":
    main()
