-- +migrate Up
-- SQL in this section is executed when the migration is applied

-- Add new columns to students table
ALTER TABLE students
ADD COLUMN IF NOT EXISTS email VARCHAR(100) UNIQUE,
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS enrollment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Update existing rows to have default values
UPDATE students 
SET 
    email = CONCAT('student_', id, '@example.com'),
    date_of_birth = '2000-01-01'::DATE,
    enrollment_date = CURRENT_TIMESTAMP,
    is_active = true
WHERE email IS NULL;
