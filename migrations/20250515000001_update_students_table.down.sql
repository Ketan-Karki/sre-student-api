-- +migrate Down
-- SQL in this section is executed when the migration is rolled back

-- Remove the columns added in the up migration
ALTER TABLE students
DROP COLUMN IF EXISTS email,
DROP COLUMN IF EXISTS date_of_birth,
DROP COLUMN IF EXISTS enrollment_date,
DROP COLUMN IF EXISTS is_active;
