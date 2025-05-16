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

	// Create tables
	logger.Info("Creating database tables if they don't exist")
	err = createTables()
	if err != nil {
		logger.WithError(err).Error("Failed to create tables")
		return fmt.Errorf("failed to create tables: %w", err)
	}

	logger.Info("Successfully initialized database connection")
	return nil
}

func createTables() error {
	// Check if students table exists
	var exists bool
	err := DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'students')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if students table exists: %w", err)
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
			return fmt.Errorf("failed to create students table: %w", err)
		}
		logger.Info("Created students table")
	} else {
		logger.Debug("Students table already exists")
	}

	// Check if users table exists
	err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if users table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE users (
			id VARCHAR(36) PRIMARY KEY,
			username VARCHAR(50) NOT NULL UNIQUE,
			email VARCHAR(100) NOT NULL UNIQUE,
			password_hash VARCHAR(255) NOT NULL,
			first_name VARCHAR(50) NOT NULL,
			last_name VARCHAR(50) NOT NULL,
			role VARCHAR(20) NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create users table: %w", err)
		}
		logger.Info("Created users table")

		// Create parent-student relationship table
		query = `
		CREATE TABLE parent_student (
			parent_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			student_id VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
			PRIMARY KEY (parent_id, student_id)
		)`

		_, err = DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create parent_student table: %w", err)
		}
		logger.Info("Created parent_student table")
	} else {
		logger.Debug("Users table already exists")

		// Check if parent_student table exists
		err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'parent_student')").Scan(&exists)
		if err != nil {
			return fmt.Errorf("failed to check if parent_student table exists: %w", err)
		}

		if !exists {
			query := `
			CREATE TABLE parent_student (
				parent_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				student_id VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
				PRIMARY KEY (parent_id, student_id)
			)`

			_, err = DB.Exec(query)
			if err != nil {
				return fmt.Errorf("failed to create parent_student table: %w", err)
			}
			logger.Info("Created parent_student table")
		} else {
			logger.Debug("Parent_student table already exists")
		}
	}

	// Check if attendance table exists
	err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'attendance')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if attendance table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE attendance (
			id VARCHAR(36) PRIMARY KEY,
			student_id VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
			date DATE NOT NULL,
			status VARCHAR(20) NOT NULL,
			excuse TEXT,
			recorded_by VARCHAR(36) NOT NULL REFERENCES users(id),
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			UNIQUE(student_id, date)
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create attendance table: %w", err)
		}
		logger.Info("Created attendance table")
	} else {
		logger.Debug("Attendance table already exists")
	}

	// Check if assignments table exists
	err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'assignments')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if assignments table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE assignments (
			id VARCHAR(36) PRIMARY KEY,
			title VARCHAR(255) NOT NULL,
			description TEXT,
			subject VARCHAR(50) NOT NULL,
			due_date TIMESTAMP WITH TIME ZONE NOT NULL,
			created_by VARCHAR(36) NOT NULL REFERENCES users(id),
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create assignments table: %w", err)
		}
		logger.Info("Created assignments table")
	} else {
		logger.Debug("Assignments table already exists")
	}

	// Check if grades table exists
	err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'grades')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if grades table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE grades (
			id VARCHAR(36) PRIMARY KEY,
			student_id VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
			assignment_id VARCHAR(36) NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
			score DECIMAL(5,2),
			max_score DECIMAL(5,2) NOT NULL,
			status VARCHAR(20) NOT NULL,
			feedback TEXT,
			graded_by VARCHAR(36) NOT NULL REFERENCES users(id),
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			UNIQUE(student_id, assignment_id)
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create grades table: %w", err)
		}
		logger.Info("Created grades table")
	} else {
		logger.Debug("Grades table already exists")
	}

	// Check if forum_posts table exists
	err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'forum_posts')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if forum_posts table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE forum_posts (
			id VARCHAR(36) PRIMARY KEY,
			title VARCHAR(255) NOT NULL,
			content TEXT NOT NULL,
			author_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			student_id VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create forum_posts table: %w", err)
		}
		logger.Info("Created forum_posts table")
	} else {
		logger.Debug("Forum_posts table already exists")
	}

	// Check if forum_comments table exists
	err = DB.QueryRow("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'forum_comments')").Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check if forum_comments table exists: %w", err)
	}

	if !exists {
		query := `
		CREATE TABLE forum_comments (
			id VARCHAR(36) PRIMARY KEY,
			post_id VARCHAR(36) NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
			content TEXT NOT NULL,
			author_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		)`

		_, err := DB.Exec(query)
		if err != nil {
			return fmt.Errorf("failed to create forum_comments table: %w", err)
		}
		logger.Info("Created forum_comments table")
	} else {
		logger.Debug("Forum_comments table already exists")
	}

	return nil
}
