package routes

import (
	"github.com/gin-gonic/gin"
)

func RegisterRoutes(server *gin.Engine) {
	server.GET("/students", getStudents)
	server.GET("/students/:id", getStudent)
	server.POST("/students", createStudent)
	server.PUT("/students/:id", updateStudent)
	server.DELETE("/students/:id", deleteStudent)
}
