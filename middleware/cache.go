package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
)

var (
	ctx = context.Background()
	rdb *redis.Client
)

func InitRedis() error {
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		redisHost = "localhost"
	}
	redisAddr := fmt.Sprintf("%s:6379", redisHost)
	log.Printf("Connecting to Redis at %s", redisAddr)
	
	rdb = redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "",
		DB:       0,
	})

	// Test the connection
	_, err := rdb.Ping(ctx).Result()
	if err != nil {
		return fmt.Errorf("failed to connect to Redis: %w", err)
	}
	
	log.Printf("Successfully connected to Redis at %s", redisAddr)
	return nil
}

type cachedResponse struct {
	Status  int         `json:"status"`
	Headers http.Header `json:"headers"`
	Body    []byte      `json:"body"`
}

type responseWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w *responseWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

func CacheMiddleware(ttl time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip caching for non-GET requests
		if c.Request.Method != "GET" {
			// For POST/PUT/DELETE requests, invalidate the list cache
			if c.Request.Method == "POST" || c.Request.Method == "PUT" || c.Request.Method == "DELETE" {
				log.Println("Invalidating cache for /api/v1/students")
				rdb.Del(ctx, "/api/v1/students")
			}
			c.Next()
			return
		}

		// Generate cache key
		cacheKey := c.Request.URL.String()
		log.Println("Cache key:", cacheKey)

		// Check if cached response exists
		cached, err := rdb.Get(ctx, cacheKey).Result()
		if err == nil {
			log.Println("Cache hit for key:", cacheKey)
			var resp cachedResponse
			if err := json.Unmarshal([]byte(cached), &resp); err == nil {
				// Return cached response
				for key, values := range resp.Headers {
					for _, value := range values {
						c.Writer.Header().Add(key, value)
					}
				}
				c.Writer.WriteHeader(resp.Status)
				c.Writer.Write(resp.Body)
				log.Println("Returned cached response for key:", cacheKey)
				c.Abort()
				return
			} else {
				log.Println("Failed to unmarshal cached response for key:", cacheKey, "Error:", err)
			}
		} else {
			log.Println("Cache miss for key:", cacheKey, "Error:", err)
		}

		// Create a custom response writer
		writer := &responseWriter{
			ResponseWriter: c.Writer,
			body:          bytes.NewBuffer(nil),
		}
		c.Writer = writer

		// Continue processing the request
		c.Next()

		// Cache the response
		if c.Writer.Status() == http.StatusOK {
			resp := cachedResponse{
				Status:  c.Writer.Status(),
				Headers: c.Writer.Header(),
				Body:    writer.body.Bytes(),
			}
			if data, err := json.Marshal(resp); err == nil {
				if err := rdb.Set(ctx, cacheKey, data, ttl).Err(); err != nil {
					log.Println("Failed to cache response for key:", cacheKey, "Error:", err)
				} else {
					log.Println("Cached response for key:", cacheKey)
				}
			}
		}
	}
}
