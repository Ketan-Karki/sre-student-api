package db

import (
	"database/sql"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func InitDB() {
	err := godotenv.Load()
	if err != nil {
		panic("Could not load .env file.")
	}

	dbURL := os.Getenv("DATABASE_URL")

	DB, err = sql.Open("sqlite3", dbURL)

	if err != nil {
		panic("Could not connect to database.")
	}

	DB.SetMaxOpenConns(10)
	DB.SetMaxIdleConns(5)

	createTables()
}

func createTables() {
	createStudentsTable := `
	CREATE TABLE IF NOT EXISTS students (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		age INTEGER NOT NULL,
		grade INTEGER NOT NULL
	);`

	_, err := DB.Exec(createStudentsTable)
	if err != nil {
		panic("Could not create students table.")
	}
}
