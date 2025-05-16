-- Rollback: add_performance_indexes
-- Created: 2025-05-16T19:48:47+05:30

-- Drop all indexes created in the up migration

-- Student table indexes
DROP INDEX IF EXISTS idx_students_name;
DROP INDEX IF EXISTS idx_students_grade;

-- Attendance table indexes
DROP INDEX IF EXISTS idx_attendance_student_id;
DROP INDEX IF EXISTS idx_attendance_date;
DROP INDEX IF EXISTS idx_attendance_status;

-- Users table indexes
DROP INDEX IF EXISTS idx_users_username;
DROP INDEX IF EXISTS idx_users_email;
DROP INDEX IF EXISTS idx_users_role;

-- Assignment table indexes
DROP INDEX IF EXISTS idx_assignments_due_date;
DROP INDEX IF EXISTS idx_assignments_created_by;
DROP INDEX IF EXISTS idx_assignments_subject;

-- Grades table indexes
DROP INDEX IF EXISTS idx_grades_student_id;
DROP INDEX IF EXISTS idx_grades_assignment_id;
DROP INDEX IF EXISTS idx_grades_status;

-- Forum posts table indexes
DROP INDEX IF EXISTS idx_forum_posts_student_id;
DROP INDEX IF EXISTS idx_forum_posts_author_id;

-- Forum comments table indexes
DROP INDEX IF EXISTS idx_forum_comments_post_id;
DROP INDEX IF EXISTS idx_forum_comments_author_id;
