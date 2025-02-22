package models

import (
	"errors"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"

	"example.com/sre-bootcamp-rest-api/db"
)

// Test Save Method
func TestStudent_Save(t *testing.T) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	db.DB = mockDB
	defer mockDB.Close()

	student := &Student{ID: "1", Name: "John Doe", Age: 20, Grade: "A+"}

	// Successful Insert
	mock.ExpectExec(`INSERT INTO students \(id, name, age, grade\) VALUES \(\$1, \$2, \$3, \$4\)`).
		WithArgs(student.ID, student.Name, student.Age, student.Grade).
		WillReturnResult(sqlmock.NewResult(1, 1))

	err = student.Save()
	assert.NoError(t, err)

	// Failed Insert
	mock.ExpectExec(`INSERT INTO students \(id, name, age, grade\) VALUES \(\$1, \$2, \$3, \$4\)`).
		WithArgs(student.ID, student.Name, student.Age, student.Grade).
		WillReturnError(errors.New("insert error"))

	err = student.Save()
	assert.Error(t, err)
	assert.Equal(t, "failed to execute insert query: insert error", err.Error())
}

// Test GetAllStudents Method
func TestGetAllStudents(t *testing.T) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	db.DB = mockDB
	defer mockDB.Close()

	rows := sqlmock.NewRows([]string{"id", "name", "age", "grade"}).
		AddRow("1", "John Doe", 20, "A+").
		AddRow("2", "Jane Doe", 22, "A")

	mock.ExpectQuery(`SELECT id, name, age, grade FROM students`).
		WillReturnRows(rows)

	students, err := GetAllStudents()
	assert.NoError(t, err)
	assert.Len(t, students, 2)
}

// Test GetStudentByID Method
func TestGetStudentByID(t *testing.T) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	db.DB = mockDB
	defer mockDB.Close()

	// Successful Fetch
	row := sqlmock.NewRows([]string{"id", "name", "age", "grade"}).
		AddRow("1", "John Doe", 20, "A+")
	mock.ExpectQuery(`SELECT id, name, age, grade FROM students WHERE id = \$1`).
		WithArgs("1").
		WillReturnRows(row)

	student, err := GetStudentByID("1")
	assert.NoError(t, err)
	assert.Equal(t, "John Doe", student.Name)

	// Not Found
	mock.ExpectQuery(`SELECT id, name, age, grade FROM students WHERE id = \$1`).
		WithArgs("2").
		WillReturnError(errors.New("not found"))

	student, err = GetStudentByID("2")
	assert.Error(t, err)
	assert.Nil(t, student)
}

// Test Update Method
func TestStudent_Update(t *testing.T) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	db.DB = mockDB
	defer mockDB.Close()

	student := &Student{ID: "1", Name: "Updated Name", Age: 21, Grade: "A+"}

	// Successful Update
	mock.ExpectExec(`UPDATE students SET name = \$1, age = \$2, grade = \$3 WHERE id = \$4`).
		WithArgs(student.Name, student.Age, student.Grade, student.ID).
		WillReturnResult(sqlmock.NewResult(1, 1))

	err = student.Update()
	assert.NoError(t, err)

	// No Rows Affected (Student Not Found)
	mock.ExpectExec(`UPDATE students SET name = \$1, age = \$2, grade = \$3 WHERE id = \$4`).
		WithArgs(student.Name, student.Age, student.Grade, student.ID).
		WillReturnResult(sqlmock.NewResult(0, 0))

	err = student.Update()
	assert.Error(t, err)
	assert.Equal(t, "student not found", err.Error())
}

// Test Delete Method
func TestStudent_Delete(t *testing.T) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
	}
	db.DB = mockDB
	defer mockDB.Close()

	student := &Student{ID: "1"}

	// Successful Delete
	mock.ExpectExec(`DELETE FROM students WHERE id = \$1`).
		WithArgs(student.ID).
		WillReturnResult(sqlmock.NewResult(1, 1))

	err = student.Delete()
	assert.NoError(t, err)

	// No Rows Affected
	mock.ExpectExec(`DELETE FROM students WHERE id = \$1`).
		WithArgs(student.ID).
		WillReturnResult(sqlmock.NewResult(0, 0))

	err = student.Delete()
	assert.Error(t, err)
	assert.Equal(t, "student not found", err.Error())
}
