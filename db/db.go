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

// DBConfig holds the database configuration
type DBConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// GetDBConfig loads database configuration from environment variables with fallback values
func GetDBConfig() DBConfig {
	return DBConfig{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnv("DB_PORT", "5432"),
		User:     getEnv("DB_USER", "postgres"),
		Password: getEnv("DB_PASSWORD", "postgres"),
		DBName:   getEnv("DB_NAME", "student_api"),
		SSLMode:  getEnv("DB_SSLMODE", "disable"),
	}
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

// GetDBConnectionString returns a connection string from the configuration
func (c *DBConfig) GetDBConnectionString() string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode)
}

func InitDB() error {
	// Initialize logger if not set
	if logger == nil {
		logger = logrus.StandardLogger().WithField("component", "database")
	}

	// First try to use DATABASE_URL if it exists (for backward compatibility)
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		// If DATABASE_URL is not set, use individual environment variables
		config := GetDBConfig()
		dbURL = config.GetDBConnectionString()
		logger.Info("Using individual database configuration from environment variables")
	} else {
		logger.Info("Using DATABASE_URL for database connection")
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
