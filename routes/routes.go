package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// HealthCheckHandler responds with a simple message indicating the service is healthy.
func HealthCheckHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func RegisterRoutes(server *gin.Engine) {
	v1 := server.Group("/api/v1")
	{
		v1.GET("/students", getStudents)
		v1.GET("/students/:id", getStudent)
		v1.POST("/students", createStudent)
		v1.PUT("/students/:id", updateStudent)
		v1.DELETE("/students/:id", deleteStudent)
		v1.GET("/healthcheck", HealthCheckHandler)
	}
}
