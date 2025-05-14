package routes

import (
	"net/http"

	"example.com/sre-bootcamp-rest-api/middleware"
	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// HealthCheckHandler responds with a simple message indicating the service is healthy.
func HealthCheckHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func RegisterRoutes(router *gin.RouterGroup) {
	// Use router directly since it's already grouped with '/api/v1' in main.go

	// Public routes (no authentication required)
	{
		// Health check endpoint
		router.GET("/healthcheck", HealthCheckHandler)

		// Authentication routes
		router.POST("/auth/register", registerUser)
		router.POST("/auth/login", loginUser)
	}

	// Student routes (authentication required)
	studentRoutes := router.Group("/students")
	studentRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff, models.RoleParent))
	{
		studentRoutes.GET("", getStudents)
		studentRoutes.GET("/:id", getStudent)
	}

	// Additional student routes with restricted access
	facultyStaffStudentRoutes := router.Group("/students")
	facultyStaffStudentRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff))
	{
		facultyStaffStudentRoutes.POST("", createStudent)
		facultyStaffStudentRoutes.PUT("/:id", updateStudent)
		facultyStaffStudentRoutes.DELETE("/:id", deleteStudent)
	}

	// User routes (staff and faculty only)
	userRoutes := router.Group("/users")
	userRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff))
	{
		userRoutes.GET("", getUsers)
		userRoutes.GET("/:id", getUserByID)
		userRoutes.PUT("/:id", updateUser)
	}

	// User deletion route (staff only)
	staffUserRoutes := router.Group("/users")
	staffUserRoutes.Use(middleware.AuthMiddleware(models.RoleStaff))
	{
		staffUserRoutes.DELETE("/:id", deleteUser)
	}

	// Attendance routes
	attendanceRoutes := router.Group("/attendance")
	attendanceRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff))
	{
		attendanceRoutes.POST("", createAttendanceRecord)
		attendanceRoutes.GET("/:id", getAttendanceByID)
		attendanceRoutes.PUT("/:id", updateAttendanceRecord)
		attendanceRoutes.GET("/student/:studentId", getAttendanceByStudentID)
		attendanceRoutes.GET("/date-range", getAttendanceByDateRange)
	}

	// Assignment routes with read access for all roles
	assignmentRoutes := router.Group("/assignments")
	assignmentRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff, models.RoleParent))
	{
		assignmentRoutes.GET("", getAssignments)
		assignmentRoutes.GET("/:id", getAssignmentByID)
	}

	// Assignment routes with write access for faculty only
	facultyAssignmentRoutes := router.Group("/assignments")
	facultyAssignmentRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty))
	{
		facultyAssignmentRoutes.POST("", createAssignment)
		facultyAssignmentRoutes.PUT("/:id", updateAssignment)
		facultyAssignmentRoutes.DELETE("/:id", deleteAssignment)
	}

	// Grade routes with read access for all roles
	gradeRoutes := router.Group("/grades")
	gradeRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff, models.RoleParent))
	{
		gradeRoutes.GET("/:id", getGradeByID)
		gradeRoutes.GET("/student/:studentId", getGradesByStudentID)
	}

	// Grade routes with write access for faculty only
	facultyGradeRoutes := router.Group("/grades")
	facultyGradeRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty))
	{
		facultyGradeRoutes.POST("", createGrade)
		facultyGradeRoutes.PUT("/:id", updateGrade)
		facultyGradeRoutes.GET("/assignment/:assignmentId", getGradesByAssignmentID)
	}

	// Forum routes for parent-teacher communication
	forumRoutes := router.Group("/forum")
	forumRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff, models.RoleParent))
	{
		forumRoutes.POST("/posts", createForumPost)
		
		// This specific route must come before the general /:id routes
		forumRoutes.GET("/posts/student/:studentId", getForumPostsByStudentID)
		forumRoutes.GET("/posts/comments/:postId", getCommentsByPostID) // Changed path to avoid conflict
		
		// General post routes with :id parameter
		forumRoutes.GET("/posts/:id", getForumPostByID)
		forumRoutes.PUT("/posts/:id", updateForumPost) // Auth check is done in the handler
		forumRoutes.DELETE("/posts/:id", deleteForumPost) // Auth check is done in the handler

		// Comment routes
		forumRoutes.POST("/comments", createForumComment)
		forumRoutes.PUT("/comments/:id", updateForumComment) // Auth check is done in the handler
	}

	// Report routes for faculty and staff
	reportRoutes := router.Group("/reports")
	reportRoutes.Use(middleware.AuthMiddleware(models.RoleFaculty, models.RoleStaff))
	{
		reportRoutes.GET("/attendance", generateAttendanceReport)
		reportRoutes.GET("/grades", generateGradesReport)
		reportRoutes.GET("/student/:studentId", generateStudentActivityReport)
	}

	// Special route for parents to view their children's reports
	parentReportRoutes := router.Group("/reports")
	parentReportRoutes.Use(middleware.AuthMiddleware(models.RoleParent))
	{
		parentReportRoutes.GET("/student/:studentId/parent", generateStudentActivityReport)
	}
}
