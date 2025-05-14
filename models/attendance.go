package models

import (
	"errors"
	"fmt"
	"log"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"github.com/google/uuid"
)

// AttendanceStatus represents the status of a student for a particular day
type AttendanceStatus string

const (
	// AttendanceStatusPresent represents that a student was present
	AttendanceStatusPresent AttendanceStatus = "present"
	// AttendanceStatusAbsent represents that a student was absent
	AttendanceStatusAbsent AttendanceStatus = "absent"
	// AttendanceStatusTardy represents that a student was late
	AttendanceStatusTardy AttendanceStatus = "tardy"
	// AttendanceStatusExcused represents that a student's absence was excused
	AttendanceStatusExcused AttendanceStatus = "excused"
)

// Attendance represents a student's attendance record for a particular day
type Attendance struct {
	ID         string           `json:"id,omitempty"`
	StudentID  string           `json:"student_id" binding:"required"`
	Date       time.Time        `json:"date" binding:"required"`
	Status     AttendanceStatus `json:"status" binding:"required"`
	Excuse     string           `json:"excuse,omitempty"`
	RecordedBy string           `json:"recorded_by" binding:"required"` // ID of the user who recorded this attendance
	CreatedAt  time.Time        `json:"created_at,omitempty"`
	UpdatedAt  time.Time        `json:"updated_at,omitempty"`
}

// Save saves a new attendance record to the database
func (a *Attendance) Save() error {
	if a.StudentID == "" || a.Status == "" || a.RecordedBy == "" {
		return errors.New("invalid attendance data")
	}

	// Generate UUID if ID is empty
	if a.ID == "" {
		a.ID = uuid.New().String()
	}

	// Set timestamps
	now := time.Now()
	a.CreatedAt = now
	a.UpdatedAt = now

	query := `INSERT INTO attendance 
			(id, student_id, date, status, excuse, recorded_by, created_at, updated_at) 
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	log.Printf("Executing INSERT query: %s", query)

	result, err := db.DB.Exec(query, a.ID, a.StudentID, a.Date, a.Status, a.Excuse, a.RecordedBy, a.CreatedAt, a.UpdatedAt)
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
		return errors.New("failed to create attendance record: no rows affected")
	}

	log.Printf("Successfully created attendance record with ID: %s", a.ID)
	return nil
}

// Update updates an existing attendance record in the database
func (a *Attendance) Update() error {
	if a.ID == "" || a.StudentID == "" || a.Status == "" || a.RecordedBy == "" {
		return errors.New("invalid attendance data")
	}

	// Update timestamp
	a.UpdatedAt = time.Now()

	query := `UPDATE attendance SET 
			student_id = $1, date = $2, status = $3, excuse = $4, recorded_by = $5, updated_at = $6 
			WHERE id = $7`
	log.Printf("Executing UPDATE query: %s", query)

	result, err := db.DB.Exec(query, a.StudentID, a.Date, a.Status, a.Excuse, a.RecordedBy, a.UpdatedAt, a.ID)
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
		return errors.New("attendance record not found")
	}

	log.Printf("Successfully updated attendance record with ID: %s", a.ID)
	return nil
}

// Delete removes an attendance record from the database
func (a *Attendance) Delete() error {
	if a.ID == "" {
		return errors.New("attendance ID is required")
	}

	query := "DELETE FROM attendance WHERE id = $1"
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
		return errors.New("attendance record not found")
	}

	log.Printf("Successfully deleted attendance record with ID: %s", a.ID)
	return nil
}

// GetAttendanceByID retrieves an attendance record by its ID
func GetAttendanceByID(id string) (*Attendance, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, student_id, date, status, excuse, recorded_by, created_at, updated_at 
			FROM attendance WHERE id = $1`
	log.Printf("Executing SELECT query: %s", query)

	var attendance Attendance
	err := db.DB.QueryRow(query, id).Scan(
		&attendance.ID,
		&attendance.StudentID,
		&attendance.Date,
		&attendance.Status,
		&attendance.Excuse,
		&attendance.RecordedBy,
		&attendance.CreatedAt,
		&attendance.UpdatedAt,
	)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan attendance row: %w", err)
	}

	log.Printf("Successfully retrieved attendance record with ID: %s", attendance.ID)
	return &attendance, nil
}

// GetAttendanceByStudentID retrieves all attendance records for a student
func GetAttendanceByStudentID(studentID string) ([]Attendance, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, student_id, date, status, excuse, recorded_by, created_at, updated_at 
			FROM attendance WHERE student_id = $1 ORDER BY date DESC`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, studentID)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var attendances []Attendance
	for rows.Next() {
		var attendance Attendance
		err := rows.Scan(
			&attendance.ID,
			&attendance.StudentID,
			&attendance.Date,
			&attendance.Status,
			&attendance.Excuse,
			&attendance.RecordedBy,
			&attendance.CreatedAt,
			&attendance.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan attendance row: %w", err)
		}
		attendances = append(attendances, attendance)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating attendance rows: %w", err)
	}

	return attendances, nil
}

// GetAttendanceByDateRange retrieves all attendance records within a date range
func GetAttendanceByDateRange(startDate, endDate time.Time) ([]Attendance, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, student_id, date, status, excuse, recorded_by, created_at, updated_at 
			FROM attendance WHERE date BETWEEN $1 AND $2 ORDER BY date`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, startDate, endDate)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var attendances []Attendance
	for rows.Next() {
		var attendance Attendance
		err := rows.Scan(
			&attendance.ID,
			&attendance.StudentID,
			&attendance.Date,
			&attendance.Status,
			&attendance.Excuse,
			&attendance.RecordedBy,
			&attendance.CreatedAt,
			&attendance.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan attendance row: %w", err)
		}
		attendances = append(attendances, attendance)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating attendance rows: %w", err)
	}

	return attendances, nil
}
