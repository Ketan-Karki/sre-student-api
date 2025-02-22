package models

import (
	"errors"
	"testing"

	"example.com/sre-bootcamp-rest-api/db"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

// Test Save Method
func TestStudent_Save(t *testing.T) {
	mockDB, mock, _ := sqlmock.New()
	defer mockDB.Close()
	db.DB = mockDB

	student := &Student{ID: "1", Name: "John Doe", Age: 20, Grade: "A+"}

	// Successful Insert
	mock.ExpectExec("INSERT INTO students").
		WithArgs(student.ID, student.Name, student.Age, student.Grade).
		WillReturnResult(sqlmock.NewResult(1, 1))

	err := student.Save()
	assert.NoError(t, err)

	// Failed Insert
	mock.ExpectExec("INSERT INTO students").
		WithArgs(student.ID, student.Name, student.Age, student.Grade).
		WillReturnError(errors.New("insert error"))

	err = student.Save()
	assert.Error(t, err)
}

// Test GetAllStudents
func TestGetAllStudents(t *testing.T) {
	mockDB, mock, _ := sqlmock.New()
	defer mockDB.Close()
	db.DB = mockDB

	// Mock the table check query
	tableCheckRows := sqlmock.NewRows([]string{"name"}).AddRow("students")
	mock.ExpectQuery("SELECT name FROM sqlite_master").
		WillReturnRows(tableCheckRows)

	rows := sqlmock.NewRows([]string{"id", "name", "age", "grade"}).
		AddRow("1", "John Doe", 20, "A+").
		AddRow("2", "Jane Doe", 22, "A")

	mock.ExpectQuery("SELECT id, name, age, grade FROM students").
		WillReturnRows(rows)

	students, err := GetAllStudents()
	assert.NoError(t, err)
	assert.Len(t, students, 2)
}

// Test GetStudentByID
func TestGetStudentByID(t *testing.T) {
	mockDB, mock, _ := sqlmock.New()
	defer mockDB.Close()
	db.DB = mockDB

	// Successful Fetch
	row := sqlmock.NewRows([]string{"id", "name", "age", "grade"}).
		AddRow("1", "John Doe", 20, "A+")
	mock.ExpectQuery("SELECT id, name, age, grade FROM students WHERE id = ?").
		WithArgs("1").
		WillReturnRows(row)

	student, err := GetStudentByID("1")
	assert.NoError(t, err)
	assert.Equal(t, "John Doe", student.Name)

	// Not Found
	mock.ExpectQuery("SELECT id, name, age, grade FROM students WHERE id = ?").
		WithArgs("2").
		WillReturnError(errors.New("not found"))

	student, err = GetStudentByID("2")
	assert.Error(t, err)
	assert.Nil(t, student)
}

// Test Update Method
func TestStudent_Update(t *testing.T) {
	mockDB, mock, _ := sqlmock.New()
	defer mockDB.Close()
	db.DB = mockDB

	student := &Student{ID: "1", Name: "Updated Name", Age: 21, Grade: "A+"}

	// Successful Update
	mock.ExpectExec(`UPDATE students SET name = \?, age = \?, grade = \? WHERE id = \?`).
		WithArgs(student.Name, student.Age, student.Grade, student.ID).
		WillReturnResult(sqlmock.NewResult(1, 1))

	err := student.Update()
	assert.NoError(t, err)

	// No Rows Affected (Student Not Found)
	mock.ExpectExec(`UPDATE students SET name = \?, age = \?, grade = \? WHERE id = \?`).
		WithArgs(student.Name, student.Age, student.Grade, student.ID).
		WillReturnResult(sqlmock.NewResult(0, 0))

	err = student.Update()
	assert.Error(t, err)
	assert.Equal(t, "student not found", err.Error())
}


// Test Delete Method
func TestStudent_Delete(t *testing.T) {
	mockDB, mock, _ := sqlmock.New()
	defer mockDB.Close()
	db.DB = mockDB

	student := &Student{ID: "1"}

	// Successful Delete
	mock.ExpectExec("DELETE FROM students WHERE id = ?").
		WithArgs(student.ID).
		WillReturnResult(sqlmock.NewResult(1, 1))

	err := student.Delete()
	assert.NoError(t, err)

	// No Rows Affected
	mock.ExpectExec("DELETE FROM students WHERE id = ?").
		WithArgs(student.ID).
		WillReturnResult(sqlmock.NewResult(0, 0))

	err = student.Delete()
	assert.Error(t, err)
	assert.Equal(t, "student not found", err.Error())
}
