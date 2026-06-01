import psycopg2
import sys

def main():
    db_uri = "postgresql://postgres.xernedkpgdrvjokokdoa:akshitsha84@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres"
    print("Connecting to Supabase PostgreSQL database...")
    try:
        conn = psycopg2.connect(db_uri)
        conn.autocommit = True
        cursor = conn.cursor()
        print("Connected successfully!")

        # 1. Create Views and Table
        print("Creating subjects and classes views + timetable_entries table...")
        sql_setup = """
        -- Create subjects view mapping to Subject table
        CREATE OR REPLACE VIEW public.subjects AS 
        SELECT 
            id, 
            name, 
            code, 
            description, 
            "classId" as class_id, 
            type, 
            "totalMarks" as total_marks, 
            "passMarks" as pass_marks, 
            credits, 
            "createdAt" as created_at, 
            "updatedAt" as updated_at
        FROM public."Subject";

        -- Create classes view mapping to Class table
        CREATE OR REPLACE VIEW public.classes AS 
        SELECT 
            id, 
            name, 
            "numericValue" as numeric_value, 
            description, 
            "academicYearId" as academic_year_id, 
            "classTeacherId" as class_teacher_id, 
            "createdAt" as created_at, 
            "updatedAt" as updated_at
        FROM public."Class";

        -- Drop existing table if any to seed fresh
        DROP TABLE IF EXISTS public.timetable_entries CASCADE;

        -- Create timetable_entries table
        CREATE TABLE public.timetable_entries (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            day_of_week TEXT NOT NULL, -- 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            subject_id TEXT REFERENCES public."Subject"(id) ON DELETE CASCADE,
            teacher_id UUID REFERENCES public.teachers(id) ON DELETE CASCADE,
            class_id TEXT NOT NULL, -- Standard text field to support 'Grade 12' student's class queries
            class_name TEXT NOT NULL,
            section TEXT NOT NULL DEFAULT 'A',
            room_number TEXT NOT NULL DEFAULT 'Room 101',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
        );

        -- Enable RLS and add permissive policy for development
        ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Allow all actions for timetable_entries" ON public.timetable_entries FOR ALL USING (true) WITH CHECK (true);
        """
        cursor.execute(sql_setup)
        print("Views and tables created successfully!")

        # 2. Get valid Teacher and Subject UUIDs
        print("Fetching teacher and subject UUIDs from database...")
        
        # Get Prof. Harrison's teacher ID
        cursor.execute("SELECT id FROM public.teachers WHERE email = 'prof.harrison@edusmart.edu' LIMIT 1;")
        harrison_row = cursor.fetchone()
        if harrison_row:
            harrison_id = harrison_row[0]
            print(f"Found Prof. Harrison ID: {harrison_id}")
        else:
            # Fallback: get any teacher
            cursor.execute("SELECT id FROM public.teachers LIMIT 1;")
            fallback_teacher = cursor.fetchone()
            harrison_id = fallback_teacher[0] if fallback_teacher else None
            print(f"Prof. Harrison email not found. Fallback teacher ID: {harrison_id}")

        if not harrison_id:
            print("ERROR: No teachers found in database. Please run seed script first.")
            sys.exit(1)

        # Get another teacher for filling other slots
        cursor.execute("SELECT id, name FROM public.teachers WHERE id != %s LIMIT 3;", (harrison_id,))
        other_teachers = cursor.fetchall()
        print(f"Found {len(other_teachers)} other teachers.")

        # Get Subject IDs
        cursor.execute('SELECT id, name FROM public."Subject" LIMIT 10;')
        subjects = cursor.fetchall()
        print(f"Found {len(subjects)} subjects in database.")
        
        if not subjects:
            print("ERROR: No subjects found in database.")
            sys.exit(1)

        subject_map = {row[1].upper(): row[0] for row in subjects}
        
        # Fallbacks if specific subjects are missing
        math_id = subject_map.get("MATHEMATICS") or subjects[0][0]
        physics_id = subject_map.get("PHYSICS") or (subjects[1][0] if len(subjects) > 1 else subjects[0][0])
        chemistry_id = subject_map.get("CHEMISTRY") or (subjects[2][0] if len(subjects) > 2 else subjects[0][0])
        english_id = subject_map.get("ENGLISH") or (subjects[3][0] if len(subjects) > 3 else subjects[0][0])
        cs_id = subject_map.get("COMPUTER SCIENCE") or subject_map.get("COMPUTER SC.") or (subjects[4][0] if len(subjects) > 4 else subjects[0][0])

        # 3. Seed Timetable entries
        print("Inserting timetable entries...")
        
        days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        
        # We will seed slots for Grade 12 - Section A (Alex Rivera's class)
        # Period times:
        # P1: 08:00 - 08:45
        # P2: 09:00 - 09:45
        # P3: 10:00 - 10:45
        # P4: 11:00 - 11:45
        # P5: 12:00 - 12:45
        # P6: 13:00 - 13:45
        
        slots = []
        
        # We want to make sure Prof. Harrison (teacher_id = harrison_id) teaches Grade 12 - A Physics on multiple days!
        # And he teaches other periods on other days as well to see his full timetable.
        
        # Grade 12 - A schedule mapping
        for day in days:
            # We seed different subjects for different periods
            if day == 'Mon':
                # P1: Physics with Prof. Harrison
                slots.append((day, '08:00', '08:45', physics_id, harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P2: Maths
                slots.append((day, '09:00', '09:45', math_id, other_teachers[0][0] if len(other_teachers) > 0 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P3: Chemistry
                slots.append((day, '10:00', '10:45', chemistry_id, other_teachers[1][0] if len(other_teachers) > 1 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P4: English
                slots.append((day, '11:00', '11:45', english_id, other_teachers[2][0] if len(other_teachers) > 2 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
            elif day == 'Tue':
                # P1: Maths
                slots.append((day, '08:00', '08:45', math_id, other_teachers[0][0] if len(other_teachers) > 0 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P2: Physics with Prof. Harrison
                slots.append((day, '09:00', '09:45', physics_id, harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P3: CS
                slots.append((day, '10:00', '10:45', cs_id, other_teachers[1][0] if len(other_teachers) > 1 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
            elif day == 'Wed':
                # P1: Chemistry
                slots.append((day, '08:00', '08:45', chemistry_id, other_teachers[1][0] if len(other_teachers) > 1 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P2: English
                slots.append((day, '09:00', '09:45', english_id, other_teachers[2][0] if len(other_teachers) > 2 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P3: Physics with Prof. Harrison
                slots.append((day, '10:00', '10:45', physics_id, harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
            elif day == 'Thu':
                # P1: Physics with Prof. Harrison
                slots.append((day, '08:00', '08:45', physics_id, harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P2: Maths
                slots.append((day, '09:00', '09:45', math_id, other_teachers[0][0] if len(other_teachers) > 0 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P3: CS
                slots.append((day, '10:00', '10:45', cs_id, other_teachers[1][0] if len(other_teachers) > 1 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
            elif day == 'Fri':
                # P1: English
                slots.append((day, '08:00', '08:45', english_id, other_teachers[2][0] if len(other_teachers) > 2 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P2: Chemistry
                slots.append((day, '09:00', '09:45', chemistry_id, other_teachers[1][0] if len(other_teachers) > 1 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P3: Physics with Prof. Harrison
                slots.append((day, '10:00', '10:45', physics_id, harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
            elif day == 'Sat':
                # P1: Physics with Prof. Harrison
                slots.append((day, '08:00', '08:45', physics_id, harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # P2: CS
                slots.append((day, '09:00', '09:45', cs_id, other_teachers[1][0] if len(other_teachers) > 1 else harrison_id, 'Grade 12', 'Grade 12', 'A', 'Room 302'))
                # Saturday has only 2 classes, then study leave!

        # Also seed some classes for Class 1 (Prisma seeded classes) to verify other classes work
        # Let's see what classes exist in public.classes or Class table
        cursor.execute('SELECT id, name FROM public."Class" LIMIT 2;')
        Prisma_classes = cursor.fetchall()
        for c in Prisma_classes:
            c_id = c[0]
            c_name = c[1]
            # Seed P1 and P2 for Monday
            slots.append(('Mon', '08:00', '08:45', math_id, harrison_id, c_id, c_name, 'A', 'Room 101'))
            slots.append(('Mon', '09:00', '09:45', english_id, other_teachers[0][0] if len(other_teachers) > 0 else harrison_id, c_id, c_name, 'A', 'Room 101'))

        # Insert all slots into timetable_entries
        insert_query = """
        INSERT INTO public.timetable_entries (day_of_week, start_time, end_time, subject_id, teacher_id, class_id, class_name, section, room_number)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
        """
        
        for slot in slots:
            cursor.execute(insert_query, slot)
            
        print(f"Successfully seeded {len(slots)} timetable entries!")
        
        cursor.close()
        conn.close()
        print("Done!")
    except Exception as e:
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
