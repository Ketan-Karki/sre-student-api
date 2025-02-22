package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/lib/pq"
)

var DB *sql.DB

func InitDB() error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/student_api?sslmode=disable" // fallback to local
	}
	log.Printf("Initializing database with URL: %s", dbURL)

	var err error
	DB, err = sql.Open("postgres", dbURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Set connection pool settings
	DB.SetMaxOpenConns(10)
	DB.SetMaxIdleConns(5)

	// Add retry logic for database connection
	for i := 0; i < 5; i++ {
		err = DB.Ping()
		if err == nil {
			break
		}
		log.Printf("Failed to ping database, retrying in 1 second...")
		time.Sleep(time.Second)
	}
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
	// First check if table exists
	var exists bool
	err := DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'students')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE students (
			id VARCHAR(36) PRIMARY KEY,
			name VARCHAR(255) NOT NULL,
			age INTEGER NOT NULL,
			grade VARCHAR(5) NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create table: %w", err)
		}
		log.Println("Created students table")
	} else {
		log.Println("Students table already exists")
	}

	return nil
}
