package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func InitDB() error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "api.db" // fallback to local file
	}
	log.Printf("Initializing database with URL: %s", dbURL)

	var err error
	DB, err = sql.Open("sqlite3", dbURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Set connection pool settings
	DB.SetMaxOpenConns(10)
	DB.SetMaxIdleConns(5)

	// Test the connection
	err = DB.Ping()
	if err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// Create tables
	err = createTables()
	if err != nil {
		return fmt.Errorf("failed to create tables: %w", err)
	}

	log.Printf("Successfully initialized database at %s", dbURL)
	return nil
}

func createTables() error {
	query := `
	CREATE TABLE IF NOT EXISTS students (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		age INTEGER NOT NULL,
		grade INTEGER NOT NULL
	);`

	_, err := DB.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to create students table: %w", err)
	}

	return nil
}
