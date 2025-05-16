package migrations

import (
	"database/sql"
	"errors"
	"fmt"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/lib/pq" // postgres driver
	"github.com/sirupsen/logrus"
)

var logger *logrus.Entry

// SetLogger sets the logger for the migrations package
func SetLogger(l *logrus.Logger) {
	logger = l.WithField("component", "migrations")
}

// RunMigrations runs all pending migrations
func RunMigrations(dbURL string, migrationsPath string) error {
	// Initialize logger if not set
	if logger == nil {
		logger = logrus.StandardLogger().WithField("component", "migrations")
	}

	logger.Info("Starting database migrations")

	// Create a new migrate instance
	instance, err := openDatabaseConnection(dbURL, migrationsPath)
	if err != nil {
		return fmt.Errorf("failed to create migration instance: %w", err)
	}

	// Ensure that the migration instance is properly closed
	defer func() {
		sourceErr, databaseErr := instance.Close()
		if sourceErr != nil {
			logger.WithError(sourceErr).Warn("Error closing migration source")
		}
		if databaseErr != nil {
			logger.WithError(databaseErr).Warn("Error closing migration database connection")
		}
	}()

	// Run migrations
	err = instance.Up()
	if err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	if errors.Is(err, migrate.ErrNoChange) {
		logger.Info("No new migrations to apply")
		return nil
	}

	// Get current migration version
	version, dirty, err := instance.Version()
	if err != nil && !errors.Is(err, migrate.ErrNilVersion) {
		return fmt.Errorf("failed to get migration version: %w", err)
	}

	if errors.Is(err, migrate.ErrNilVersion) {
		logger.Info("No migrations have been applied yet")
	} else {
		status := "clean"
		if dirty {
			status = "dirty"
		}
		logger.WithFields(logrus.Fields{
			"version": version,
			"status":  status,
		}).Info("Current migration status")
	}

	logger.Info("Database migrations completed successfully")
	return nil
}

// openDatabaseConnection creates a new migrate instance
func openDatabaseConnection(dbURL, migrationsPath string) (*migrate.Migrate, error) {
	// Connect to database using the provided URL
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Ensure database is reachable
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Create a new postgres driver instance
	conn, err := postgres.WithInstance(db, &postgres.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to create postgres instance: %w", err)
	}

	// Check that migrations directory has correct format
	sourceURL := fmt.Sprintf("file://%s", migrationsPath)
	logger.WithField("source_url", sourceURL).Debug("Using migration source")

	m, err := migrate.NewWithDatabaseInstance(
		sourceURL,
		"postgres", // Database name (for logging)
		conn,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create migration instance: %w", err)
	}

	return m, nil
}
