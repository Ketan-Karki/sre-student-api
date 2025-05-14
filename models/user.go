package models

import (
	"errors"
	"fmt"
	"log"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// UserRole represents the role of a user in the system
type UserRole string

const (
	// RoleFaculty represents a faculty member (teacher)
	RoleFaculty UserRole = "faculty"
	// RoleStaff represents a staff member (admin, etc.)
	RoleStaff UserRole = "staff"
	// RoleParent represents a parent of a student
	RoleParent UserRole = "parent"
)

// User represents a user in the system
type User struct {
	ID           string    `json:"id,omitempty"`
	Username     string    `json:"username" binding:"required"`
	Email        string    `json:"email" binding:"required"`
	PasswordHash string    `json:"-"` // never expose password hash
	Password     string    `json:"password,omitempty" binding:"required"`
	FirstName    string    `json:"first_name" binding:"required"`
	LastName     string    `json:"last_name" binding:"required"`
	Role         UserRole  `json:"role" binding:"required"`
	StudentIDs   []string  `json:"student_ids,omitempty"` // Only for parents
	CreatedAt    time.Time `json:"created_at,omitempty"`
	UpdatedAt    time.Time `json:"updated_at,omitempty"`
}

// Save persists a new user to the database
func (u *User) Save() error {
	if u.Username == "" || u.Email == "" || u.Password == "" || u.FirstName == "" || u.LastName == "" || u.Role == "" {
		return errors.New("invalid user data")
	}

	// Check if username or email already exists
	var count int
	err := db.DB.QueryRow("SELECT COUNT(*) FROM users WHERE username = $1 OR email = $2", u.Username, u.Email).Scan(&count)
	if err != nil {
		log.Printf("Error checking existing user: %v", err)
		return fmt.Errorf("failed to check existing user: %w", err)
	}
	if count > 0 {
		return errors.New("username or email already exists")
	}

	// Generate UUID if ID is empty
	if u.ID == "" {
		u.ID = uuid.New().String()
	}

	// Hash the password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Error hashing password: %v", err)
		return fmt.Errorf("failed to hash password: %w", err)
	}
	u.PasswordHash = string(hashedPassword)

	// Set timestamps
	now := time.Now()
	u.CreatedAt = now
	u.UpdatedAt = now

	// Begin transaction
	tx, err := db.DB.Begin()
	if err != nil {
		log.Printf("Error beginning transaction: %v", err)
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Insert user
	query := `INSERT INTO users 
			(id, username, email, password_hash, first_name, last_name, role, created_at, updated_at) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`
	log.Printf("Executing INSERT query: %s", query)

	_, err = tx.Exec(query, u.ID, u.Username, u.Email, u.PasswordHash, u.FirstName, u.LastName, u.Role, u.CreatedAt, u.UpdatedAt)
	if err != nil {
		log.Printf("Error executing INSERT: %v", err)
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	// For parents, associate with students
	if u.Role == RoleParent && len(u.StudentIDs) > 0 {
		for _, studentID := range u.StudentIDs {
			_, err = tx.Exec("INSERT INTO parent_student (parent_id, student_id) VALUES ($1, $2)", u.ID, studentID)
			if err != nil {
				log.Printf("Error associating parent with student: %v", err)
				return fmt.Errorf("failed to associate parent with student: %w", err)
			}
		}
	}

	// Commit transaction
	err = tx.Commit()
	if err != nil {
		log.Printf("Error committing transaction: %v", err)
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	log.Printf("Successfully created user with ID: %s", u.ID)
	return nil
}

// Update updates an existing user in the database
func (u *User) Update() error {
	if u.ID == "" || u.Username == "" || u.Email == "" || u.FirstName == "" || u.LastName == "" || u.Role == "" {
		return errors.New("invalid user data")
	}

	// Check if username or email already exists for another user
	var count int
	err := db.DB.QueryRow("SELECT COUNT(*) FROM users WHERE (username = $1 OR email = $2) AND id != $3", 
		u.Username, u.Email, u.ID).Scan(&count)
	if err != nil {
		log.Printf("Error checking existing user: %v", err)
		return fmt.Errorf("failed to check existing user: %w", err)
	}
	if count > 0 {
		return errors.New("username or email already exists")
	}

	// Update timestamp
	u.UpdatedAt = time.Now()

	// Begin transaction
	tx, err := db.DB.Begin()
	if err != nil {
		log.Printf("Error beginning transaction: %v", err)
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Update password if provided
	if u.Password != "" {
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
		if err != nil {
			log.Printf("Error hashing password: %v", err)
			return fmt.Errorf("failed to hash password: %w", err)
		}
		u.PasswordHash = string(hashedPassword)

		query := `UPDATE users SET 
				username = $1, email = $2, password_hash = $3, first_name = $4, last_name = $5, role = $6, updated_at = $7 
				WHERE id = $8`
		log.Printf("Executing UPDATE query with password: %s", query)

		result, err := tx.Exec(query, u.Username, u.Email, u.PasswordHash, u.FirstName, u.LastName, u.Role, u.UpdatedAt, u.ID)
		if err != nil {
			log.Printf("Error executing UPDATE: %v", err)
			return fmt.Errorf("failed to execute update query: %w", err)
		}

		rows, err := result.RowsAffected()
		if err != nil {
			log.Printf("Error getting affected rows: %v", err)
			return fmt.Errorf("failed to get affected rows: %w", err)
		}
		if rows == 0 {
			return errors.New("user not found")
		}
	} else {
		query := `UPDATE users SET 
				username = $1, email = $2, first_name = $3, last_name = $4, role = $5, updated_at = $6 
				WHERE id = $7`
		log.Printf("Executing UPDATE query without password: %s", query)

		result, err := tx.Exec(query, u.Username, u.Email, u.FirstName, u.LastName, u.Role, u.UpdatedAt, u.ID)
		if err != nil {
			log.Printf("Error executing UPDATE: %v", err)
			return fmt.Errorf("failed to execute update query: %w", err)
		}

		rows, err := result.RowsAffected()
		if err != nil {
			log.Printf("Error getting affected rows: %v", err)
			return fmt.Errorf("failed to get affected rows: %w", err)
		}
		if rows == 0 {
			return errors.New("user not found")
		}
	}

	// For parents, update student associations
	if u.Role == RoleParent && len(u.StudentIDs) > 0 {
		// First remove all existing associations
		_, err = tx.Exec("DELETE FROM parent_student WHERE parent_id = $1", u.ID)
		if err != nil {
			log.Printf("Error removing parent-student associations: %v", err)
			return fmt.Errorf("failed to remove parent-student associations: %w", err)
		}

		// Then add new ones
		for _, studentID := range u.StudentIDs {
			_, err = tx.Exec("INSERT INTO parent_student (parent_id, student_id) VALUES ($1, $2)", u.ID, studentID)
			if err != nil {
				log.Printf("Error associating parent with student: %v", err)
				return fmt.Errorf("failed to associate parent with student: %w", err)
			}
		}
	}

	// Commit transaction
	err = tx.Commit()
	if err != nil {
		log.Printf("Error committing transaction: %v", err)
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	log.Printf("Successfully updated user with ID: %s", u.ID)
	return nil
}

// Delete removes a user from the database
func (u *User) Delete() error {
	if u.ID == "" {
		return errors.New("user ID is required")
	}

	// Begin transaction
	tx, err := db.DB.Begin()
	if err != nil {
		log.Printf("Error beginning transaction: %v", err)
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Remove parent-student associations if exists
	_, err = tx.Exec("DELETE FROM parent_student WHERE parent_id = $1", u.ID)
	if err != nil {
		log.Printf("Error removing parent-student associations: %v", err)
		return fmt.Errorf("failed to remove parent-student associations: %w", err)
	}

	// Delete user
	query := "DELETE FROM users WHERE id = $1"
	log.Printf("Executing DELETE query: %s", query)

	result, err := tx.Exec(query, u.ID)
	if err != nil {
		log.Printf("Error executing DELETE: %v", err)
		return fmt.Errorf("failed to execute delete query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("user not found")
	}

	// Commit transaction
	err = tx.Commit()
	if err != nil {
		log.Printf("Error committing transaction: %v", err)
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	log.Printf("Successfully deleted user with ID: %s", u.ID)
	return nil
}

// GetUserByID retrieves a user by ID
func GetUserByID(id string) (*User, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, username, email, password_hash, first_name, last_name, role, created_at, updated_at 
			FROM users WHERE id = $1`
	log.Printf("Executing SELECT query: %s", query)

	var user User
	err := db.DB.QueryRow(query, id).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.FirstName,
		&user.LastName,
		&user.Role,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan user row: %w", err)
	}

	// If user is a parent, get associated students
	if user.Role == RoleParent {
		rows, err := db.DB.Query("SELECT student_id FROM parent_student WHERE parent_id = $1", user.ID)
		if err != nil {
			log.Printf("Error getting student IDs: %v", err)
			return nil, fmt.Errorf("failed to get student IDs: %w", err)
		}
		defer rows.Close()

		var studentIDs []string
		for rows.Next() {
			var studentID string
			err := rows.Scan(&studentID)
			if err != nil {
				log.Printf("Error scanning student ID: %v", err)
				return nil, fmt.Errorf("failed to scan student ID: %w", err)
			}
			studentIDs = append(studentIDs, studentID)
		}
		user.StudentIDs = studentIDs
	}

	log.Printf("Successfully retrieved user with ID: %s", user.ID)
	return &user, nil
}

// GetUserByUsername retrieves a user by username
func GetUserByUsername(username string) (*User, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, username, email, password_hash, first_name, last_name, role, created_at, updated_at 
			FROM users WHERE username = $1`
	log.Printf("Executing SELECT query: %s", query)

	var user User
	err := db.DB.QueryRow(query, username).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.FirstName,
		&user.LastName,
		&user.Role,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan user row: %w", err)
	}

	// If user is a parent, get associated students
	if user.Role == RoleParent {
		rows, err := db.DB.Query("SELECT student_id FROM parent_student WHERE parent_id = $1", user.ID)
		if err != nil {
			log.Printf("Error getting student IDs: %v", err)
			return nil, fmt.Errorf("failed to get student IDs: %w", err)
		}
		defer rows.Close()

		var studentIDs []string
		for rows.Next() {
			var studentID string
			err := rows.Scan(&studentID)
			if err != nil {
				log.Printf("Error scanning student ID: %v", err)
				return nil, fmt.Errorf("failed to scan student ID: %w", err)
			}
			studentIDs = append(studentIDs, studentID)
		}
		user.StudentIDs = studentIDs
	}

	log.Printf("Successfully retrieved user with username: %s", user.Username)
	return &user, nil
}

// GetAllUsers retrieves all users
func GetAllUsers() ([]User, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, username, email, password_hash, first_name, last_name, role, created_at, updated_at 
			FROM users ORDER BY username`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var user User
		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&user.PasswordHash,
			&user.FirstName,
			&user.LastName,
			&user.Role,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan user row: %w", err)
		}
		users = append(users, user)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating user rows: %w", err)
	}

	log.Printf("Successfully retrieved %d users", len(users))
	return users, nil
}

// Authenticate checks if provided credentials are valid
func Authenticate(username, password string) (*User, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	user, err := GetUserByUsername(username)
	if err != nil {
		return nil, err
	}

	// Compare password hashes
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password))
	if err != nil {
		log.Printf("Authentication failed for user %s: %v", username, err)
		return nil, errors.New("invalid username or password")
	}

	log.Printf("User %s authenticated successfully", username)
	return user, nil
}

// GetStudentsByParentID retrieves all students associated with a parent
func GetStudentsByParentID(parentID string) ([]Student, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT s.id, s.name, s.age, s.grade 
			FROM students s 
			JOIN parent_student ps ON s.id = ps.student_id 
			WHERE ps.parent_id = $1`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, parentID)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var students []Student
	for rows.Next() {
		var student Student
		err := rows.Scan(
			&student.ID,
			&student.Name,
			&student.Age,
			&student.Grade,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan student row: %w", err)
		}
		students = append(students, student)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating student rows: %w", err)
	}

	return students, nil
}

// GetParentsByStudentID retrieves all parents associated with a student
func GetParentsByStudentID(studentID string) ([]User, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT u.id, u.username, u.email, u.password_hash, u.first_name, u.last_name, u.role, u.created_at, u.updated_at 
			FROM users u 
			JOIN parent_student ps ON u.id = ps.parent_id 
			WHERE ps.student_id = $1 AND u.role = $2`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, studentID, RoleParent)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var parents []User
	for rows.Next() {
		var parent User
		err := rows.Scan(
			&parent.ID,
			&parent.Username,
			&parent.Email,
			&parent.PasswordHash,
			&parent.FirstName,
			&parent.LastName,
			&parent.Role,
			&parent.CreatedAt,
			&parent.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan user row: %w", err)
		}
		parents = append(parents, parent)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating user rows: %w", err)
	}

	return parents, nil
}
