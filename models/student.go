package models

import (
	"errors"

	"example.com/sre-bootcamp-rest-api/db"
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

	query := "INSERT INTO students (id, name, age, grade) VALUES (?, ?, ?, ?)"
	result, err := db.DB.Exec(query, s.ID, s.Name, s.Age, s.Grade)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return errors.New("failed to create student")
	}

	return nil
}

func GetAllStudents() ([]Student, error) {
	query := "SELECT id, name, age, grade FROM students"
	rows, err := db.DB.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var students []Student
	for rows.Next() {
		var student Student
		err := rows.Scan(&student.ID, &student.Name, &student.Age, &student.Grade)
		if err != nil {
			return nil, err
		}
		students = append(students, student)
	}

	return students, nil
}

func GetStudentByID(id string) (*Student, error) {
	query := "SELECT id, name, age, grade FROM students WHERE id = ?"
	row := db.DB.QueryRow(query, id)

	var student Student
	err := row.Scan(&student.ID, &student.Name, &student.Age, &student.Grade)
	if err != nil {
		return nil, err
	}

	return &student, nil
}

func (s *Student) Update() error {
	if s.Name == "" || s.Age == 0 || s.Grade == 0 {
		return errors.New("invalid student data")
	}

	query := "UPDATE students SET name = ?, age = ?, grade = ? WHERE id = ?"
	result, err := db.DB.Exec(query, s.Name, s.Age, s.Grade, s.ID)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return errors.New("student not found")
	}

	return nil
}

func (s *Student) Delete() error {
	query := "DELETE FROM students WHERE id = ?"
	result, err := db.DB.Exec(query, s.ID)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return errors.New("student not found")
	}

	return nil
}
