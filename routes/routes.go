package routes

import (
	"github.com/gin-gonic/gin"
)

func RegisterRoutes(server *gin.Engine) {
	v1 := server.Group("/api/v1")
	{
		v1.GET("/students", getStudents)
		v1.GET("/students/:id", getStudent)
		v1.POST("/students", createStudent)
		v1.PUT("/students/:id", updateStudent)
		v1.DELETE("/students/:id", deleteStudent)
	}
}
