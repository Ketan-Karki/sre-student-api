package middleware

import (
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/sirupsen/logrus"
)

var logger *logrus.Logger

// InitLogger initializes the logger with the specified log level
func InitLogger() {
	logger = logrus.New()
	logger.SetOutput(os.Stdout)
	logger.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339,
	})

	// Set log level from environment variable, default to info
	switch os.Getenv("LOG_LEVEL") {
	case "debug":
		logger.SetLevel(logrus.DebugLevel)
	case "warn":
		logger.SetLevel(logrus.WarnLevel)
	case "error":
		logger.SetLevel(logrus.ErrorLevel)
	default:
		logger.SetLevel(logrus.InfoLevel)
	}
}

// GetLogger returns the logger instance
func GetLogger() *logrus.Logger {
	if logger == nil {
		InitLogger()
	}
	return logger
}

// RequestLogger returns a middleware that logs HTTP requests
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip logging for health check endpoint
		if c.Request.URL.Path == "/health" {
			c.Next()
			return
		}

		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// Generate a request ID if not present
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.New().String()
			c.Header("X-Request-ID", requestID)
		}

		// Add request ID to context
		c.Set("request_id", requestID)

		// Create a logger with request context
		requestLogger := logger.WithFields(logrus.Fields{
			"request_id": requestID,
			"method":     c.Request.Method,
			"path":       path,
			"query":      query,
			"ip":         c.ClientIP(),
			"user_agent": c.Request.UserAgent(),
		})


		// Log request start
		requestLogger.Debug("Request started")


		// Process request
		c.Next()


		end := time.Now()
		latency := end.Sub(start)


		// Get response status
		status := c.Writer.Status()

		// Add response fields
		fields := logrus.Fields{
			"status":          status,
			"latency":         latency,
			"response_length": c.Writer.Size(),
		}


		// Add error details if any
		if len(c.Errors) > 0 {
			fields["errors"] = c.Errors.Errors()
		}

		// Add user info if available
		if user, exists := c.Get("user"); exists {
			fields["user"] = user
		}

		// Log at appropriate level based on status code
		switch {
		case status >= 500:
			requestLogger.WithFields(fields).Error("Server error")
		case status >= 400:
			requestLogger.WithFields(fields).Warn("Client error")
		default:
			requestLogger.WithFields(fields).Info("Request completed")
		}
	}
}

// ErrorLogger logs errors using the structured logger
func ErrorLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if len(c.Errors) > 0 {
			// Get the request ID from context if available
			requestID, exists := c.Get("request_id")
			var requestLogger *logrus.Entry
			
			if exists && requestID != nil {
				requestLogger = logger.WithField("request_id", requestID)
			} else {
				requestLogger = logrus.NewEntry(logger)
			}

			for _, e := range c.Errors {
				requestLogger.WithFields(logrus.Fields{
					"method": c.Request.Method,
					"path":   c.Request.URL.Path,
					"error":  e.Error(),
				}).Error("Request error")
			}
		}
	}
}
