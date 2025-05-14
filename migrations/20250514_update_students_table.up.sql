-- Update students table structure
ALTER TABLE students ADD COLUMN IF NOT EXISTS grade VARCHAR(5);
ALTER TABLE students ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE students ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

-- Drop email column if it exists (as per the new model)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
              WHERE table_name = 'students' AND column_name = 'email') THEN
        ALTER TABLE students DROP COLUMN email;
    END IF;
END
$$;
