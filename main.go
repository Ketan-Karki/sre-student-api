package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"example.com/sre-bootcamp-rest-api/middleware"
	"example.com/sre-bootcamp-rest-api/routes"
	"github.com/gin-gonic/gin"
)

func main() {
	// Initialize Database
	if err := db.InitDB(); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	server := gin.Default()

	server.Use(middleware.CacheMiddleware(time.Minute))

	routes.RegisterRoutes(server)

	// Get port from environment variable, default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:    fmt.Sprintf(":%s", port),
		Handler: server,
	}

	go func() {
		log.Printf("Server starting on port %s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exiting")
}