package main

import (
	"database/sql"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/lib/pq"
	"github.com/sirupsen/logrus"
)

var (
	dbURL        = flag.String("db-url", "", "Database connection URL")
	migrationsDir = flag.String("migrations-dir", "", "Directory containing migration files")
	command      = flag.String("command", "", "Migration command (up, down, version, create)")
	steps        = flag.Int("steps", 0, "Number of migrations to apply (0 means all)")
	name         = flag.String("name", "", "Name for new migration")
	verbose      = flag.Bool("verbose", false, "Enable verbose logging")
)

func main() {
	flag.Parse()
	logger := setupLogger()

	// Set defaults if not provided
	if *dbURL == "" {
		*dbURL = os.Getenv("DATABASE_URL")
		if *dbURL == "" {
			*dbURL = "postgres://postgres:postgres@localhost:5432/student_api?sslmode=disable"
			logger.Warn("Using default database connection string")
		}
	}

	if *migrationsDir == "" {
		*migrationsDir = filepath.Join(".", "migrations")
	}

	// Check if command is provided
	if *command == "" {
		logger.Fatal("No command specified. Use -command=up|down|version|create|force")
	}

	// Handle create command separately
	if *command == "create" {
		if *name == "" {
			logger.Fatal("Migration name is required for create command")
		}
		if err := createMigration(*migrationsDir, *name); err != nil {
			logger.Fatalf("Failed to create migration: %v", err)
		}
		logger.Infof("Created migration files in %s", *migrationsDir)
		return
	}

	// Connect to database for other commands
	logger.Info("Connecting to database...")
	db, err := connectDB(*dbURL)
	if err != nil {
		logger.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	m, err := getMigrate(db, *migrationsDir)
	if err != nil {
		logger.Fatalf("Failed to initialize migrate: %v", err)
	}

	// Close migrate instance when done
	defer func() {
		sourceErr, dbErr := m.Close()
		if sourceErr != nil {
			logger.Warnf("Error closing source: %v", sourceErr)
		}
		if dbErr != nil {
			logger.Warnf("Error closing database: %v", dbErr)
		}
	}()

	// Execute command
	switch *command {
	case "up":
		if *steps > 0 {
			logger.Infof("Applying %d migrations...", *steps)
			if err := m.Steps(*steps); err != nil && err != migrate.ErrNoChange {
				logger.Fatalf("Error applying migrations: %v", err)
			}
		} else {
			logger.Info("Applying all pending migrations...")
			if err := m.Up(); err != nil && err != migrate.ErrNoChange {
				logger.Fatalf("Error applying migrations: %v", err)
			}
		}
		logger.Info("Migrations applied successfully")

	case "down":
		if *steps > 0 {
			logger.Infof("Rolling back %d migrations...", *steps)
			if err := m.Steps(-(*steps)); err != nil && err != migrate.ErrNoChange {
				logger.Fatalf("Error rolling back migrations: %v", err)
			}
		} else {
			logger.Info("Rolling back all migrations...")
			if err := m.Down(); err != nil && err != migrate.ErrNoChange {
				logger.Fatalf("Error rolling back migrations: %v", err)
			}
		}
		logger.Info("Rollback completed successfully")

	case "version":
		version, dirty, err := m.Version()
		if err != nil {
			if err == migrate.ErrNilVersion {
				logger.Info("No migrations have been applied yet")
				return
			}
			logger.Fatalf("Error getting migration version: %v", err)
		}
		status := "clean"
		if dirty {
			status = "dirty"
		}
		logger.Infof("Current migration version: %d (%s)", version, status)

	case "force":
		if *steps == 0 {
			logger.Fatal("Version number is required for force command")
		}
		if err := m.Force(*steps); err != nil {
			logger.Fatalf("Error forcing version: %v", err)
		}
		logger.Infof("Migration version forced to %d", *steps)

	default:
		logger.Fatalf("Unknown command: %s", *command)
	}
}

func setupLogger() *logrus.Logger {
	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{
		FullTimestamp:    true,
		TimestampFormat:  time.RFC3339,
		DisableTimestamp: false,
	})

	if *verbose {
		logger.SetLevel(logrus.DebugLevel)
	} else {
		logger.SetLevel(logrus.InfoLevel)
	}

	return logger
}

func connectDB(dbURL string) (*sql.DB, error) {
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return db, nil
}

func getMigrate(db *sql.DB, migrationsDir string) (*migrate.Migrate, error) {
	driver, err := postgres.WithInstance(db, &postgres.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to create postgres instance: %w", err)
	}

	sourceURL := fmt.Sprintf("file://%s", migrationsDir)
	m, err := migrate.NewWithDatabaseInstance(sourceURL, "postgres", driver)
	if err != nil {
		return nil, fmt.Errorf("failed to create migration instance: %w", err)
	}

	return m, nil
}

func createMigration(dir, name string) error {
	timestamp := time.Now().Format("20060102150405")
	basename := fmt.Sprintf("%s_%s", timestamp, name)
	
	// Create migrations directory if it doesn't exist
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create migrations directory: %w", err)
	}

	upFile := filepath.Join(dir, basename+".up.sql")
	downFile := filepath.Join(dir, basename+".down.sql")

	// Check if files already exist
	if _, err := os.Stat(upFile); err == nil {
		return fmt.Errorf("up migration file already exists: %s", upFile)
	}
	if _, err := os.Stat(downFile); err == nil {
		return fmt.Errorf("down migration file already exists: %s", downFile)
	}

	// Create up migration file with header comment
	upContent := fmt.Sprintf("-- Migration: %s\n-- Created: %s\n\n", name, time.Now().Format(time.RFC3339))
	if err := os.WriteFile(upFile, []byte(upContent), 0644); err != nil {
		return fmt.Errorf("failed to create up migration file: %w", err)
	}

	// Create down migration file with header comment
	downContent := fmt.Sprintf("-- Rollback: %s\n-- Created: %s\n\n", name, time.Now().Format(time.RFC3339))
	if err := os.WriteFile(downFile, []byte(downContent), 0644); err != nil {
		return fmt.Errorf("failed to create down migration file: %w", err)
	}

	return nil
}
