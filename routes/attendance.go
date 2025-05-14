package routes

import (
	"log"
	"net/http"
	"time"

	"example.com/sre-bootcamp-rest-api/middleware"
	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// createAttendanceRecord creates a new attendance record
func createAttendanceRecord(c *gin.Context) {
	log.Println("Creating a new attendance record...")
	var attendance models.Attendance
	if err := c.ShouldBindJSON(&attendance); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}
	
	// Set the user who recorded this attendance
	user := middleware.GetUserFromContext(c)
	attendance.RecordedBy = user.ID

	if err := attendance.Save(); err != nil {
		log.Println("Error saving attendance:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not create attendance record. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":    "Attendance record created successfully!",
		"attendance": attendance,
	})
}

// getAttendanceByID retrieves an attendance record by ID
func getAttendanceByID(c *gin.Context) {
	id := c.Param("id")
	
	attendance, err := models.GetAttendanceByID(id)
	if err != nil {
		log.Println("Error fetching attendance:", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "Attendance record not found."})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"attendance": attendance,
	})
}

// updateAttendanceRecord updates an existing attendance record
func updateAttendanceRecord(c *gin.Context) {
	id := c.Param("id")
	
	// Check if record exists
	existingRecord, err := models.GetAttendanceByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Attendance record not found."})
		return
	}

	var attendance models.Attendance
	if err := c.ShouldBindJSON(&attendance); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}

	// Preserve the record ID and creator
	attendance.ID = existingRecord.ID
	attendance.RecordedBy = existingRecord.RecordedBy

	if err := attendance.Update(); err != nil {
		log.Println("Error updating attendance:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not update attendance record. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Attendance record updated successfully!",
		"attendance": attendance,
	})
}

// getAttendanceByStudentID retrieves all attendance records for a student
func getAttendanceByStudentID(c *gin.Context) {
	studentID := c.Param("studentId")
	
	attendance, err := models.GetAttendanceByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching attendance:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch attendance records. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if attendance == nil {
		attendance = []models.Attendance{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"attendance": attendance,
		"count":      len(attendance),
	})
}

// getAttendanceByDateRange retrieves attendance records within a date range
func getAttendanceByDateRange(c *gin.Context) {
	startDateStr := c.Query("startDate")
	endDateStr := c.Query("endDate")
	
	if startDateStr == "" || endDateStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Start date and end date are required."})
		return
	}
	
	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid start date format. Use YYYY-MM-DD."})
		return
	}
	
	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid end date format. Use YYYY-MM-DD."})
		return
	}
	
	// Add one day to end date to include the end date in the range
	endDate = endDate.Add(24 * time.Hour)
	
	attendance, err := models.GetAttendanceByDateRange(startDate, endDate)
	if err != nil {
		log.Println("Error fetching attendance:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch attendance records. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if attendance == nil {
		attendance = []models.Attendance{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"attendance": attendance,
		"count":      len(attendance),
		"dateRange": gin.H{
			"startDate": startDateStr,
			"endDate":   endDateStr,
		},
	})
}
