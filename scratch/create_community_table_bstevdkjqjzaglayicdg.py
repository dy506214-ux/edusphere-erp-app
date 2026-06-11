import psycopg2
import sys

def main():
    regions = [
        "ap-south-1",      # Mumbai
        "ap-southeast-1",  # Singapore
        "ap-northeast-1",  # Tokyo
        "ap-northeast-2",  # Seoul
        "us-east-1",       # N. Virginia
        "us-east-2",       # Ohio
        "us-west-1",       # N. California
        "us-west-2",       # Oregon
        "eu-central-1",    # Frankfurt
        "eu-west-1",       # Ireland
        "eu-west-2",       # London
        "eu-west-3",       # Paris
        "sa-east-1",       # São Paulo
        "ca-central-1",    # Canada
        "ap-southeast-2",  # Sydney
    ]
    
    password = "akshitsha84"
    project_ref = "bstevdkjqjzaglayicdg"
    username = f"postgres.{project_ref}"
    
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
    
    success = False
    for region in regions:
        for num in ["aws-0", "aws-1"]:
            host = f"{num}-{region}.pooler.supabase.com"
            db_uri = f"postgresql://{username}:{password}@{host}:6543/postgres"
            try:
                conn = psycopg2.connect(db_uri, connect_timeout=3)
                conn.autocommit = True
                cursor = conn.cursor()
                print(f"Connected to {host}!")
                cursor.execute(sql)
                print("CommunityPost table successfully created!")
                cursor.close()
                conn.close()
                success = True
                break
            except Exception as e:
                pass
        if success:
            break
            
    if not success:
        print("Could not connect to any pooler.")

if __name__ == "__main__":
    main()
