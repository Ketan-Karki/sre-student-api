-- Revert changes to students table
ALTER TABLE students DROP COLUMN IF EXISTS grade;
ALTER TABLE students DROP COLUMN IF EXISTS created_at;
ALTER TABLE students DROP COLUMN IF EXISTS updated_at;

-- Add back email column if it was dropped
ALTER TABLE students ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;
