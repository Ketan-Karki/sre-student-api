package middleware

import (
	"bytes"
	"context"
	"encoding/json"
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

func InitRedis() {
	redisUrl := os.Getenv("REDIS_URL")
	rdb = redis.NewClient(&redis.Options{
		Addr:     redisUrl,  // Use Redis container hostname
		Password: "", // no password set
		DB:       0,  // use default DB
	})
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

		// Capture the response body
		responseBody := writer.body.Bytes()

		// Cache the response if status code is 200
		if c.Writer.Status() == http.StatusOK {
			resp := cachedResponse{
				Status:  c.Writer.Status(),
				Headers: c.Writer.Header(),
				Body:    responseBody,
			}

			data, err := json.Marshal(resp)
			if err == nil {
				err := rdb.Set(ctx, cacheKey, data, ttl).Err()
				if err == nil {
					log.Println("Cached response for key:", cacheKey)
				} else {
					log.Println("Failed to cache response for key:", cacheKey, "Error:", err)
				}
			} else {
				log.Println("Failed to marshal response for key:", cacheKey, "Error:", err)
			}
		} else {
			log.Println("Did not cache response for key:", cacheKey, "Status code:", c.Writer.Status())
		}
		log.Println("Finished processing request for key:", cacheKey)
	}
}
