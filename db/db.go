package db

import (
	"database/sql"
	"fmt"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/sirupsen/logrus"
)

var logger *logrus.Entry

// SetLogger sets the logger instance for the db package
func SetLogger(l *logrus.Logger) {
	logger = l.WithField("component", "database")
}

// Mask sensitive information in connection strings
func maskSensitiveData(connStr string) string {
	// In a real application, you might want to properly parse and mask the connection string
	return "[MASKED]"
}

var DB *sql.DB

func InitDB() error {
	// Initialize logger if not set
	if logger == nil {
		logger = logrus.StandardLogger().WithField("component", "database")
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/student_api?sslmode=disable" // fallback to local
		logger.Warn("Using default database URL as DATABASE_URL is not set")
	}
	logger = logger.WithField("db_url", maskSensitiveData(dbURL))
	logger.Info("Initializing database connection")

	var err error
	DB, err = sql.Open("postgres", dbURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Set connection pool settings
	DB.SetMaxOpenConns(10)
	DB.SetMaxIdleConns(5)
	DB.SetConnMaxLifetime(time.Hour)

	// Add retry logic for database connection
	for i := 0; i < 5; i++ {
		err = DB.Ping()
		if err == nil {
			break
		}
		retryIn := time.Second * time.Duration(i+1)
		logger.WithError(err).Warnf("Failed to ping database, retrying in %v...", retryIn)
		time.Sleep(retryIn)
	}
	if err != nil {
		logger.WithError(err).Error("Failed to ping database after retries")
		return fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("Successfully initialized database connection")
	return nil
}

// CloseDB closes the database connection if it's open
func CloseDB() error {
	if DB != nil {
		logger.Info("Closing database connection")
		return DB.Close()
	}
	return nil
}
