-- Drop tables in reverse order to respect foreign key constraints
DROP TABLE IF EXISTS forum_comments;
DROP TABLE IF EXISTS forum_posts;
DROP TABLE IF EXISTS grades;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS parent_student;
DROP TABLE IF EXISTS users;
