package test_api

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"github.com/gin-gonic/gin"
)

// Simple test API to verify database connectivity
func main() {
	log.Println("Starting test API server...")

	// Initialize Database
	if err := db.InitDB(); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	server := gin.Default()

	// Basic health check
	server.GET("/healthcheck", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now().Format(time.RFC3339)})
	})

	// Test database connectivity
	server.GET("/db-test", func(c *gin.Context) {
		var testValue string
		err := db.DB.QueryRow("SELECT 'Database connection working!' AS test").Scan(&testValue)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status": "error",
				"error":  fmt.Sprintf("Database error: %v", err),
			})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": testValue,
		})
	})

	// Get port from environment variable, default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Test server starting on port %s", port)
	if err := server.Run(fmt.Sprintf(":%s", port)); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
