# Database Migrations

This directory contains database migration files for the Student API. Migrations are managed using the [golang-migrate/migrate](https://github.com/golang-migrate/migrate) library.

## Migration File Format

Each migration has two files:
- `{version}_{description}.up.sql`: Contains SQL statements to apply the migration
- `{version}_{description}.down.sql`: Contains SQL statements to revert the migration

Version numbers should follow the format `YYYYMMDD` (e.g., `20250516`).

## Migration Process

Migrations run automatically when the application starts. The application checks the current database version and applies any missing migrations in order.

## Creating New Migrations

To create a new migration:

1. Create two new files in this directory:
   - `YYYYMMDD_description.up.sql`
   - `YYYYMMDD_description.down.sql`

2. Add SQL statements to create, modify, or drop tables in the up migration. 

3. Add SQL statements to revert all changes made in the up migration to the down migration.

## Migration Order

Migrations are executed in order of their version numbers. Ensure that dependencies between tables (like foreign keys) are correctly handled by ordering migrations properly.

## Existing Migrations

Current migrations include:
1. `20250204_create_student_table`: Creates the initial students table
2. `20250514_update_students_table`: Updates the students table structure
3. `20250514_create_new_tables`: Creates additional tables (users, attendance, grades, etc.)
