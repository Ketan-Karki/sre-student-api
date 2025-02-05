package routes

import (
	"net/http"

	"log"

	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func getStudents(c *gin.Context) {
	log.Println("Fetching all students...")
	students, err := models.GetAllStudents()
	if err != nil {
		log.Println("Error fetching students:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Could not fetch students. Try again later."})
		return
	}
	c.JSON(http.StatusOK, students)
}

func getStudent(c *gin.Context) {
	log.Printf("Fetching student with ID: %s...", c.Param("id"))
	id := c.Param("id")
	
	student, err := models.GetStudentByID(id)
	if err != nil {
		log.Println("Error fetching student:", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "Student not found."})
		return
	}

	c.JSON(http.StatusOK, student)
}

func createStudent(c *gin.Context) {
	log.Println("Creating a new student...")
	var student models.Student
	err := c.ShouldBindJSON(&student)

	if err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{"message": "Could not parse request data."})
		return
	}

	student.ID = uuid.New().String()

	if err := student.Save(); err != nil {
		log.Println("Error saving student:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Could not create student. Try again later."})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Student created successfully!", "student": student})
}

func updateStudent(c *gin.Context) {
	log.Printf("Updating student with ID: %s...", c.Param("id"))
	id := c.Param("id")
	
	existingStudent, err := models.GetStudentByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Student not found."})
		return
	}

	var student models.Student
	err = c.ShouldBindJSON(&student)
	if err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{"message": "Could not parse request data."})
		return
	}

	student.ID = existingStudent.ID
	err = student.Update()
	if err != nil {
		log.Println("Error updating student:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Could not update student. Try again later."})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Student updated successfully!", "student": student})
}

func deleteStudent(c *gin.Context) {
	log.Printf("Deleting student with ID: %s...", c.Param("id"))
	id := c.Param("id")

	student, err := models.GetStudentByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Student not found."})
		return
	}

	err = student.Delete()
	if err != nil {
		log.Println("Error deleting student:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Could not delete student. Try again later."})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Student deleted successfully!"})
}
