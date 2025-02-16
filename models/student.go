package models

import (
	"errors"
	"fmt"
	"log"

	"example.com/sre-bootcamp-rest-api/db"
	"github.com/google/uuid"
)

type Student struct {
	ID    string `json:"id"`
	Name  string `json:"name" binding:"required"`
	Age   int    `json:"age" binding:"required"`
	Grade int    `json:"grade" binding:"required"`
}

func (s *Student) Save() error {
	if s.Name == "" || s.Age == 0 || s.Grade == 0 {
		return errors.New("invalid student data")
	}

	// Generate UUID if ID is empty
	if s.ID == "" {
		s.ID = uuid.New().String()
	}

	query := "INSERT INTO students (id, name, age, grade) VALUES (?, ?, ?, ?)"
	log.Printf("Executing INSERT query: %s with values: [%s, %s, %d, %d]", query, s.ID, s.Name, s.Age, s.Grade)
	
	result, err := db.DB.Exec(query, s.ID, s.Name, s.Age, s.Grade)
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
		return errors.New("failed to create student: no rows affected")
	}

	log.Printf("Successfully created student with ID: %s", s.ID)
	return nil
}

func GetAllStudents() ([]Student, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	// First, let's check if the table exists
	var tableName string
	err := db.DB.QueryRow("SELECT name FROM sqlite_master WHERE type='table' AND name='students'").Scan(&tableName)
	if err != nil {
		log.Printf("Table check error: %v", err)
		// Table might not exist, let's create it
		createTableSQL := `
		CREATE TABLE IF NOT EXISTS students (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			age INTEGER NOT NULL,
			grade INTEGER NOT NULL
		);`
		_, err = db.DB.Exec(createTableSQL)
		if err != nil {
			log.Printf("Error creating table: %v", err)
			return nil, fmt.Errorf("failed to create table: %w", err)
		}
	}

	query := "SELECT id, name, age, grade FROM students"
	log.Printf("Executing SELECT query: %s", query)
	
	rows, err := db.DB.Query(query)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var students []Student
	for rows.Next() {
		var student Student
		err := rows.Scan(&student.ID, &student.Name, &student.Age, &student.Grade)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan student row: %w", err)
		}
		log.Printf("Found student: %+v", student)
		students = append(students, student)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating student rows: %w", err)
	}

	log.Printf("Successfully retrieved %d students", len(students))
	return students, nil
}

func GetStudentByID(id string) (*Student, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := "SELECT id, name, age, grade FROM students WHERE id = ?"
	log.Printf("Executing SELECT query: %s with value: %s", query, id)
	
	row := db.DB.QueryRow(query, id)

	var student Student
	err := row.Scan(&student.ID, &student.Name, &student.Age, &student.Grade)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan student row: %w", err)
	}

	log.Printf("Successfully retrieved student with ID: %s", student.ID)
	return &student, nil
}

func (s *Student) Update() error {
	if s.Name == "" || s.Age == 0 || s.Grade == 0 {
		return errors.New("invalid student data")
	}

	query := "UPDATE students SET name = ?, age = ?, grade = ? WHERE id = ?"
	log.Printf("Executing UPDATE query: %s with values: [%s, %d, %d, %s]", query, s.Name, s.Age, s.Grade, s.ID)
	
	result, err := db.DB.Exec(query, s.Name, s.Age, s.Grade, s.ID)
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
		return errors.New("student not found")
	}

	log.Printf("Successfully updated student with ID: %s", s.ID)
	return nil
}

func (s *Student) Delete() error {
	if db.DB == nil {
		return errors.New("database connection not initialized")
	}

	query := "DELETE FROM students WHERE id = ?"
	log.Printf("Executing DELETE query: %s with value: %s", query, s.ID)
	
	result, err := db.DB.Exec(query, s.ID)
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
		return errors.New("student not found")
	}

	log.Printf("Successfully deleted student with ID: %s", s.ID)
	return nil
}
