package main

import (
	"example.com/sre-bootcamp-rest-api/db"
	"example.com/sre-bootcamp-rest-api/routes"
	"github.com/gin-gonic/gin"
)

func main() {
	db.InitDB()
	server := gin.Default()

	routes.RegisterRoutes(server)

	server.Run(":8080") // localhost:8080
}