package routes

import (
	"log"
	"net/http"

	"example.com/sre-bootcamp-rest-api/middleware"
	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// createAssignment creates a new assignment
func createAssignment(c *gin.Context) {
	log.Println("Creating a new assignment...")
	var assignment models.Assignment
	if err := c.ShouldBindJSON(&assignment); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}
	
	// Set the user who created this assignment
	user := middleware.GetUserFromContext(c)
	assignment.CreatedBy = user.ID

	if err := assignment.Save(); err != nil {
		log.Println("Error saving assignment:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not create assignment. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":    "Assignment created successfully!",
		"assignment": assignment,
	})
}

// getAssignments retrieves all assignments
func getAssignments(c *gin.Context) {
	assignments, err := models.GetAllAssignments()
	if err != nil {
		log.Println("Error fetching assignments:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch assignments. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if assignments == nil {
		assignments = []models.Assignment{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"assignments": assignments,
		"count":       len(assignments),
	})
}

// getAssignmentByID retrieves an assignment by ID
func getAssignmentByID(c *gin.Context) {
	id := c.Param("id")
	
	assignment, err := models.GetAssignmentByID(id)
	if err != nil {
		log.Println("Error fetching assignment:", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "Assignment not found."})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"assignment": assignment,
	})
}

// updateAssignment updates an existing assignment
func updateAssignment(c *gin.Context) {
	id := c.Param("id")
	
	// Check if assignment exists
	existingAssignment, err := models.GetAssignmentByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Assignment not found."})
		return
	}

	var assignment models.Assignment
	if err := c.ShouldBindJSON(&assignment); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}

	// Preserve the assignment ID and creator
	assignment.ID = existingAssignment.ID
	assignment.CreatedBy = existingAssignment.CreatedBy

	if err := assignment.Update(); err != nil {
		log.Println("Error updating assignment:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not update assignment. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Assignment updated successfully!",
		"assignment": assignment,
	})
}

// deleteAssignment deletes an assignment
func deleteAssignment(c *gin.Context) {
	id := c.Param("id")
	
	assignment, err := models.GetAssignmentByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Assignment not found."})
		return
	}

	if err := assignment.Delete(); err != nil {
		log.Println("Error deleting assignment:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not delete assignment. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Assignment deleted successfully!",
	})
}

// createGrade creates a new grade for a student's assignment
func createGrade(c *gin.Context) {
	log.Println("Creating a new grade...")
	var grade models.Grade
	if err := c.ShouldBindJSON(&grade); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}
	
	// Set the user who graded this assignment
	user := middleware.GetUserFromContext(c)
	grade.GradedBy = user.ID

	if err := grade.Save(); err != nil {
		log.Println("Error saving grade:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not create grade. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Grade created successfully!",
		"grade":   grade,
	})
}

// getGradeByID retrieves a grade by ID
func getGradeByID(c *gin.Context) {
	id := c.Param("id")
	
	grade, err := models.GetGradeByID(id)
	if err != nil {
		log.Println("Error fetching grade:", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "Grade not found."})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"grade": grade,
	})
}

// updateGrade updates an existing grade
func updateGrade(c *gin.Context) {
	id := c.Param("id")
	
	// Check if grade exists
	existingGrade, err := models.GetGradeByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Grade not found."})
		return
	}

	var grade models.Grade
	if err := c.ShouldBindJSON(&grade); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}

	// Preserve the grade ID and grader
	grade.ID = existingGrade.ID
	grade.GradedBy = existingGrade.GradedBy

	if err := grade.Update(); err != nil {
		log.Println("Error updating grade:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not update grade. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Grade updated successfully!",
		"grade":   grade,
	})
}

// getGradesByStudentID retrieves all grades for a student
func getGradesByStudentID(c *gin.Context) {
	studentID := c.Param("studentId")
	
	grades, err := models.GetGradesByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching grades:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch grades. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if grades == nil {
		grades = []models.Grade{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"grades": grades,
		"count":  len(grades),
	})
}

// getGradesByAssignmentID retrieves all grades for an assignment
func getGradesByAssignmentID(c *gin.Context) {
	assignmentID := c.Param("assignmentId")
	
	grades, err := models.GetGradesByAssignmentID(assignmentID)
	if err != nil {
		log.Println("Error fetching grades:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch grades. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if grades == nil {
		grades = []models.Grade{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"grades": grades,
		"count":  len(grades),
	})
}
