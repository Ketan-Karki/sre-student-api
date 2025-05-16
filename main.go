package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"example.com/sre-bootcamp-rest-api/middleware"
	"example.com/sre-bootcamp-rest-api/routes"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

func main() {
	// Initialize logger
	middleware.InitLogger()
	logger := middleware.GetLogger()

	// Set up database logger
	db.SetLogger(logger)

	// Initialize Database
	if err := db.InitDB(); err != nil {
		logger.Fatalf("Failed to initialize database: %v", err)
	}
	logger.Info("Database connection established")

	// Set Gin mode based on environment
	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	} else {
		gin.SetMode(gin.DebugMode)
	}

	// Set up Gin
	r := gin.New()

	// Add middleware
	r.Use(
		gin.Recovery(),
		middleware.RequestLogger(),
		middleware.ErrorLogger(),
	)

	// Basic health check endpoint
	r.GET("/health", func(c *gin.Context) {
		logger.Debug("Health check endpoint called")
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
			"time":   time.Now().Format(time.RFC3339),
		})
	})

	// Register API routes
	apiV1 := r.Group("/api/v1")
	routes.RegisterRoutes(apiV1)

	// Get port from environment variable, default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Create a server with graceful shutdown
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%s", port),
		Handler: r,
	}

	// Start the server in a goroutine
	go func() {
		logger.Infof("Starting server on port %s", port)
		logger.Infof("Environment: %s", os.Getenv("GIN_MODE"))
		logger.Infof("Log level: %s", logger.GetLevel().String())

		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatalf("Server error: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shut down the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("Shutting down server...")

	// The context is used to inform the server it has 5 seconds to finish
	// the request it is currently handling
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatalf("Server forced to shutdown: %v", err)
	}

	logger.Info("Server exited gracefully")
}
