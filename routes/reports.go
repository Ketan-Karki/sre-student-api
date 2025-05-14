package routes

import (
	"log"
	"net/http"
	"time"

	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// generateAttendanceReport generates a report on student attendance
func generateAttendanceReport(c *gin.Context) {
	log.Println("Generating attendance report...")
	
	// Get query parameters for date range
	startDateStr := c.DefaultQuery("startDate", "")
	endDateStr := c.DefaultQuery("endDate", "")
	
	var startDate, endDate time.Time
	var err error
	
	// If start date is not provided, use the beginning of the current month
	if startDateStr == "" {
		now := time.Now()
		startDate = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	} else {
		startDate, err = time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid start date format. Use YYYY-MM-DD."})
			return
		}
	}
	
	// If end date is not provided, use the current date
	if endDateStr == "" {
		endDate = time.Now()
	} else {
		endDate, err = time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid end date format. Use YYYY-MM-DD."})
			return
		}
		// Add one day to end date to include the end date in the range
		endDate = endDate.Add(24 * time.Hour)
	}
	
	// Get all attendance records for the date range
	records, err := models.GetAttendanceByDateRange(startDate, endDate)
	if err != nil {
		log.Println("Error fetching attendance records:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not generate attendance report. Try again later.",
			"error":   err.Error(),
		})
		return
	}
	
	// Get all students
	students, err := models.GetAllStudents()
	if err != nil {
		log.Println("Error fetching students:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not generate attendance report. Try again later.",
			"error":   err.Error(),
		})
		return
	}
	
	// Create a map of student IDs to student names
	studentMap := make(map[string]string)
	for _, student := range students {
		studentMap[student.ID] = student.Name
	}
	
	// Process records into a summary
	summary := make(map[string]map[string]int)
	for _, record := range records {
		studentName := studentMap[record.StudentID]
		
		// Initialize summary for this student if it doesn't exist
		if _, exists := summary[studentName]; !exists {
			summary[studentName] = map[string]int{
				"present": 0,
				"absent":  0,
				"tardy":   0,
				"excused": 0,
				"total":   0,
			}
		}
		
		// Increment the appropriate counter
		summary[studentName][string(record.Status)]++
		summary[studentName]["total"]++
	}
	
	// Convert summary to a slice for easier rendering
	var reportData []gin.H
	for student, counts := range summary {
		reportData = append(reportData, gin.H{
			"student":  student,
			"present":  counts["present"],
			"absent":   counts["absent"],
			"tardy":    counts["tardy"],
			"excused":  counts["excused"],
			"total":    counts["total"],
			"percent_present": float64(counts["present"]) / float64(counts["total"]) * 100,
		})
	}
	
	c.JSON(http.StatusOK, gin.H{
		"report":     reportData,
		"date_range": gin.H{"start_date": startDate.Format("2006-01-02"), "end_date": endDate.Format("2006-01-02")},
		"count":      len(reportData),
	})
}

// generateGradesReport generates a report on student grades
func generateGradesReport(c *gin.Context) {
	log.Println("Generating grades report...")
	
	// Get all students
	students, err := models.GetAllStudents()
	if err != nil {
		log.Println("Error fetching students:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not generate grades report. Try again later.",
			"error":   err.Error(),
		})
		return
	}
	
	var reportData []gin.H
	
	// For each student, get their grades
	for _, student := range students {
		grades, err := models.GetGradesByStudentID(student.ID)
		if err != nil {
			log.Printf("Error fetching grades for student %s: %v", student.ID, err)
			continue
		}
		
		if len(grades) == 0 {
			// No grades for this student
			reportData = append(reportData, gin.H{
				"student":     student.Name,
				"grade":       student.Grade,
				"assignments": 0,
				"average":     0,
				"highest":     0,
				"lowest":      0,
				"missing":     0,
			})
			continue
		}
		
		// Calculate statistics
		var totalScore, totalPossible float64
		var highest, lowest float64
		var missing int
		
		for i, grade := range grades {
			if grade.Status == models.AssignmentStatusMissing {
				missing++
				continue
			}
			
			if i == 0 || grade.Score > highest {
				highest = grade.Score
			}
			
			if i == 0 || grade.Score < lowest {
				lowest = grade.Score
			}
			
			totalScore += grade.Score
			totalPossible += grade.MaxScore
		}
		
		// Calculate average as a percentage
		var average float64
		if totalPossible > 0 {
			average = (totalScore / totalPossible) * 100
		}
		
		reportData = append(reportData, gin.H{
			"student":     student.Name,
			"grade":       student.Grade,
			"assignments": len(grades),
			"average":     average,
			"highest":     highest,
			"lowest":      lowest,
			"missing":     missing,
		})
	}
	
	c.JSON(http.StatusOK, gin.H{
		"report": reportData,
		"count":  len(reportData),
	})
}

// generateStudentActivityReport generates a comprehensive report for a specific student
func generateStudentActivityReport(c *gin.Context) {
	studentID := c.Param("studentId")
	
	// Get the student
	student, err := models.GetStudentByID(studentID)
	if err != nil {
		log.Println("Error fetching student:", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "Student not found."})
		return
	}
	
	// Get attendance records
	attendance, err := models.GetAttendanceByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching attendance:", err)
		attendance = []models.Attendance{} // Continue with empty attendance
	}
	
	// Get grades
	grades, err := models.GetGradesByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching grades:", err)
		grades = []models.Grade{} // Continue with empty grades
	}
	
	// Get assignments for the grades
	var assignmentMap = make(map[string]models.Assignment)
	for _, grade := range grades {
		assignment, err := models.GetAssignmentByID(grade.AssignmentID)
		if err != nil {
			log.Printf("Error fetching assignment %s: %v", grade.AssignmentID, err)
			continue
		}
		assignmentMap[grade.AssignmentID] = *assignment
	}
	
	// Get forum posts
	posts, err := models.GetForumPostsByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching forum posts:", err)
		posts = []models.ForumPost{} // Continue with empty posts
	}
	
	// Get parents
	parents, err := models.GetParentsByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching parents:", err)
		parents = []models.User{} // Continue with empty parents
	}
	
	// Remove sensitive information from parents
	var parentData []gin.H
	for _, parent := range parents {
		parentData = append(parentData, gin.H{
			"id":         parent.ID,
			"first_name": parent.FirstName,
			"last_name":  parent.LastName,
			"email":      parent.Email,
		})
	}
	
	// Calculate attendance statistics
	attendanceStats := gin.H{
		"total":   len(attendance),
		"present": 0,
		"absent":  0,
		"tardy":   0,
		"excused": 0,
	}
	
	for _, record := range attendance {
		attendanceStats[string(record.Status)] = attendanceStats[string(record.Status)].(int) + 1
	}
	
	// Calculate grade statistics
	var totalScore, totalPossible float64
	var completedAssignments, missingAssignments int
	
	for _, grade := range grades {
		if grade.Status == models.AssignmentStatusCompleted || grade.Status == models.AssignmentStatusLate {
			totalScore += grade.Score
			totalPossible += grade.MaxScore
			completedAssignments++
		} else if grade.Status == models.AssignmentStatusMissing {
			missingAssignments++
		}
	}
	
	var averageGrade float64
	if totalPossible > 0 {
		averageGrade = (totalScore / totalPossible) * 100
	}
	
	gradeStats := gin.H{
		"total_assignments":    len(grades),
		"completed":            completedAssignments,
		"missing":              missingAssignments,
		"average_grade":        averageGrade,
		"total_score":          totalScore,
		"total_possible_score": totalPossible,
	}
	
	// Prepare grade details with assignment info
	var gradeDetails []gin.H
	for _, grade := range grades {
		assignment, exists := assignmentMap[grade.AssignmentID]
		if !exists {
			continue
		}
		
		gradeDetails = append(gradeDetails, gin.H{
			"assignment":  assignment.Title,
			"subject":     assignment.Subject,
			"due_date":    assignment.DueDate,
			"score":       grade.Score,
			"max_score":   grade.MaxScore,
			"percentage":  (grade.Score / grade.MaxScore) * 100,
			"status":      grade.Status,
			"feedback":    grade.Feedback,
			"graded_date": grade.UpdatedAt,
		})
	}
	
	c.JSON(http.StatusOK, gin.H{
		"student": gin.H{
			"id":    student.ID,
			"name":  student.Name,
			"age":   student.Age,
			"grade": student.Grade,
		},
		"parents":          parentData,
		"attendance_stats": attendanceStats,
		"grade_stats":      gradeStats,
		"grades":           gradeDetails,
		"recent_attendance": attendance,
		"forum_posts":      posts,
		"generated_at":     time.Now(),
	})
}
