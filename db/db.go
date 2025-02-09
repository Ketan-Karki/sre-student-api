package db

import (
	"database/sql"
	"fmt"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func InitDB() error {
	err := godotenv.Load()
	if err != nil {
		return fmt.Errorf("failed to load .env file: %w", err)
	}

	dbURL := os.Getenv("DATABASE_URL")

	var err2 error
	DB, err2 = sql.Open("sqlite3", dbURL)

	if err2 != nil {
		return fmt.Errorf("failed to connect to database: %w", err2)
	}

	DB.SetMaxOpenConns(10)
	DB.SetMaxIdleConns(5)

	return createTables()
}

func createTables() error {
	createStudentsTable := `
	CREATE TABLE IF NOT EXISTS students (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		age INTEGER NOT NULL,
		grade INTEGER NOT NULL
	);`

	_, err := DB.Exec(createStudentsTable)
	if err != nil {
		return fmt.Errorf("failed to create students table: %w", err)
	}
	return nil
}
