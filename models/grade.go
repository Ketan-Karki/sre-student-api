package models

import (
	"errors"
	"fmt"
	"log"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"github.com/google/uuid"
)

// AssignmentStatus represents the status of an assignment
type AssignmentStatus string

const (
	// AssignmentStatusAssigned represents an assignment that has been assigned
	AssignmentStatusAssigned AssignmentStatus = "assigned"
	// AssignmentStatusCompleted represents an assignment that has been completed
	AssignmentStatusCompleted AssignmentStatus = "completed"
	// AssignmentStatusLate represents an assignment that was submitted late
	AssignmentStatusLate AssignmentStatus = "late"
	// AssignmentStatusMissing represents an assignment that was not submitted
	AssignmentStatusMissing AssignmentStatus = "missing"
)

// Assignment represents an academic assignment for students
type Assignment struct {
	ID          string           `json:"id,omitempty"`
	Title       string           `json:"title" binding:"required"`
	Description string           `json:"description"`
	Subject     string           `json:"subject" binding:"required"`
	DueDate     time.Time        `json:"due_date" binding:"required"`
	CreatedBy   string           `json:"created_by" binding:"required"` // ID of user who created the assignment
	CreatedAt   time.Time        `json:"created_at,omitempty"`
	UpdatedAt   time.Time        `json:"updated_at,omitempty"`
}

// Grade represents a student's grade for a particular assignment
type Grade struct {
	ID           string           `json:"id,omitempty"`
	StudentID    string           `json:"student_id" binding:"required"`
	AssignmentID string           `json:"assignment_id" binding:"required"`
	Score        float64          `json:"score"`
	MaxScore     float64          `json:"max_score" binding:"required"`
	Status       AssignmentStatus `json:"status" binding:"required"`
	Feedback     string           `json:"feedback"`
	GradedBy     string           `json:"graded_by" binding:"required"` // ID of user who graded
	CreatedAt    time.Time        `json:"created_at,omitempty"`
	UpdatedAt    time.Time        `json:"updated_at,omitempty"`
}

// Save persists a new assignment to the database
func (a *Assignment) Save() error {
	if a.Title == "" || a.Subject == "" || a.CreatedBy == "" {
		return errors.New("invalid assignment data")
	}

	// Generate UUID if ID is empty
	if a.ID == "" {
		a.ID = uuid.New().String()
	}

	// Set timestamps
	now := time.Now()
	a.CreatedAt = now
	a.UpdatedAt = now

	query := `INSERT INTO assignments 
			(id, title, description, subject, due_date, created_by, created_at, updated_at) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	log.Printf("Executing INSERT query: %s", query)

	result, err := db.DB.Exec(query, a.ID, a.Title, a.Description, a.Subject, a.DueDate, a.CreatedBy, a.CreatedAt, a.UpdatedAt)
	if err != nil {
		log.Printf("Error executing INSERT: %v", err)
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("failed to create assignment: no rows affected")
	}

	log.Printf("Successfully created assignment with ID: %s", a.ID)
	return nil
}

// Update updates an existing assignment in the database
func (a *Assignment) Update() error {
	if a.ID == "" || a.Title == "" || a.Subject == "" || a.CreatedBy == "" {
		return errors.New("invalid assignment data")
	}

	// Update timestamp
	a.UpdatedAt = time.Now()

	query := `UPDATE assignments SET 
			title = $1, description = $2, subject = $3, due_date = $4, created_by = $5, updated_at = $6 
			WHERE id = $7`
	log.Printf("Executing UPDATE query: %s", query)

	result, err := db.DB.Exec(query, a.Title, a.Description, a.Subject, a.DueDate, a.CreatedBy, a.UpdatedAt, a.ID)
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
		return errors.New("assignment not found")
	}

	log.Printf("Successfully updated assignment with ID: %s", a.ID)
	return nil
}

// Delete removes an assignment from the database
func (a *Assignment) Delete() error {
	if a.ID == "" {
		return errors.New("assignment ID is required")
	}

	query := "DELETE FROM assignments WHERE id = $1"
	log.Printf("Executing DELETE query: %s", query)

	result, err := db.DB.Exec(query, a.ID)
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
		return errors.New("assignment not found")
	}

	log.Printf("Successfully deleted assignment with ID: %s", a.ID)
	return nil
}

// GetAssignmentByID retrieves an assignment by its ID
func GetAssignmentByID(id string) (*Assignment, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, title, description, subject, due_date, created_by, created_at, updated_at 
			FROM assignments WHERE id = $1`
	log.Printf("Executing SELECT query: %s", query)

	var assignment Assignment
	err := db.DB.QueryRow(query, id).Scan(
		&assignment.ID,
		&assignment.Title,
		&assignment.Description,
		&assignment.Subject,
		&assignment.DueDate,
		&assignment.CreatedBy,
		&assignment.CreatedAt,
		&assignment.UpdatedAt,
	)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan assignment row: %w", err)
	}

	log.Printf("Successfully retrieved assignment with ID: %s", assignment.ID)
	return &assignment, nil
}

// GetAllAssignments retrieves all assignments
func GetAllAssignments() ([]Assignment, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, title, description, subject, due_date, created_by, created_at, updated_at 
			FROM assignments ORDER BY due_date`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var assignments []Assignment
	for rows.Next() {
		var assignment Assignment
		err := rows.Scan(
			&assignment.ID,
			&assignment.Title,
			&assignment.Description,
			&assignment.Subject,
			&assignment.DueDate,
			&assignment.CreatedBy,
			&assignment.CreatedAt,
			&assignment.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan assignment row: %w", err)
		}
		assignments = append(assignments, assignment)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating assignment rows: %w", err)
	}

	return assignments, nil
}

// Save persists a new grade to the database
func (g *Grade) Save() error {
	if g.StudentID == "" || g.AssignmentID == "" || g.GradedBy == "" {
		return errors.New("invalid grade data")
	}

	// Generate UUID if ID is empty
	if g.ID == "" {
		g.ID = uuid.New().String()
	}

	// Set timestamps
	now := time.Now()
	g.CreatedAt = now
	g.UpdatedAt = now

	query := `INSERT INTO grades 
			(id, student_id, assignment_id, score, max_score, status, feedback, graded_by, created_at, updated_at) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`
	log.Printf("Executing INSERT query: %s", query)

	result, err := db.DB.Exec(query, g.ID, g.StudentID, g.AssignmentID, g.Score, g.MaxScore, g.Status, g.Feedback, g.GradedBy, g.CreatedAt, g.UpdatedAt)
	if err != nil {
		log.Printf("Error executing INSERT: %v", err)
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("failed to create grade: no rows affected")
	}

	log.Printf("Successfully created grade with ID: %s", g.ID)
	return nil
}

// Update updates an existing grade in the database
func (g *Grade) Update() error {
	if g.ID == "" || g.StudentID == "" || g.AssignmentID == "" || g.GradedBy == "" {
		return errors.New("invalid grade data")
	}

	// Update timestamp
	g.UpdatedAt = time.Now()

	query := `UPDATE grades SET 
			student_id = $1, assignment_id = $2, score = $3, max_score = $4, status = $5, feedback = $6, graded_by = $7, updated_at = $8 
			WHERE id = $9`
	log.Printf("Executing UPDATE query: %s", query)

	result, err := db.DB.Exec(query, g.StudentID, g.AssignmentID, g.Score, g.MaxScore, g.Status, g.Feedback, g.GradedBy, g.UpdatedAt, g.ID)
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
		return errors.New("grade not found")
	}

	log.Printf("Successfully updated grade with ID: %s", g.ID)
	return nil
}

// GetGradeByID retrieves a grade by its ID
func GetGradeByID(id string) (*Grade, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, student_id, assignment_id, score, max_score, status, feedback, graded_by, created_at, updated_at 
			FROM grades WHERE id = $1`
	log.Printf("Executing SELECT query: %s", query)

	var grade Grade
	err := db.DB.QueryRow(query, id).Scan(
		&grade.ID,
		&grade.StudentID,
		&grade.AssignmentID,
		&grade.Score,
		&grade.MaxScore,
		&grade.Status,
		&grade.Feedback,
		&grade.GradedBy,
		&grade.CreatedAt,
		&grade.UpdatedAt,
	)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan grade row: %w", err)
	}

	log.Printf("Successfully retrieved grade with ID: %s", grade.ID)
	return &grade, nil
}

// GetGradesByStudentID retrieves all grades for a student
func GetGradesByStudentID(studentID string) ([]Grade, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, student_id, assignment_id, score, max_score, status, feedback, graded_by, created_at, updated_at 
			FROM grades WHERE student_id = $1`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, studentID)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var grades []Grade
	for rows.Next() {
		var grade Grade
		err := rows.Scan(
			&grade.ID,
			&grade.StudentID,
			&grade.AssignmentID,
			&grade.Score,
			&grade.MaxScore,
			&grade.Status,
			&grade.Feedback,
			&grade.GradedBy,
			&grade.CreatedAt,
			&grade.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan grade row: %w", err)
		}
		grades = append(grades, grade)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating grade rows: %w", err)
	}

	return grades, nil
}

// GetGradesByAssignmentID retrieves all grades for an assignment
func GetGradesByAssignmentID(assignmentID string) ([]Grade, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, student_id, assignment_id, score, max_score, status, feedback, graded_by, created_at, updated_at 
			FROM grades WHERE assignment_id = $1`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, assignmentID)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var grades []Grade
	for rows.Next() {
		var grade Grade
		err := rows.Scan(
			&grade.ID,
			&grade.StudentID,
			&grade.AssignmentID,
			&grade.Score,
			&grade.MaxScore,
			&grade.Status,
			&grade.Feedback,
			&grade.GradedBy,
			&grade.CreatedAt,
			&grade.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan grade row: %w", err)
		}
		grades = append(grades, grade)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating grade rows: %w", err)
	}

	return grades, nil
}
