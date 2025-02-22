package middleware

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type cacheEntry struct {
	data       []byte
	expiration time.Time
}

var (
	cache     = make(map[string]cacheEntry)
	cacheLock sync.RWMutex
)

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
		// Bypass cache for /api/v1/students
		if c.Request.URL.Path == "/api/v1/students" {
			c.Next()
			return
		}

		// For POST/PUT/DELETE requests, invalidate the list cache before processing
		if c.Request.Method == "POST" || c.Request.Method == "PUT" || c.Request.Method == "DELETE" {
			log.Println("Invalidating cache before mutation")
			cacheLock.Lock()
			for key := range cache {
				delete(cache, key)
			}
			cacheLock.Unlock()
			c.Next()
			return
		}

		// Only cache GET requests
		if c.Request.Method != "GET" {
			c.Next()
			return
		}

		key := c.Request.URL.String()

		// Try to get from cache
		cacheLock.RLock()
		if entry, exists := cache[key]; exists && time.Now().Before(entry.expiration) {
			cacheLock.RUnlock()
			var cached cachedResponse
			err := json.Unmarshal(entry.data, &cached)
			if err != nil {
				log.Printf("Failed to unmarshal cached response: %v", err)
			} else {
				c.Writer.WriteHeader(cached.Status)
				for k, v := range cached.Headers {
					for _, val := range v {
						c.Writer.Header().Add(k, val)
					}
				}
				if _, err := c.Writer.Write(cached.Body); err != nil {
					log.Printf("Error writing cached response: %v", err)
				}
				c.Abort()
				return
			}
		} else {
			cacheLock.RUnlock()
		}

		// Cache miss, capture the response
		writer := &responseWriter{
			ResponseWriter: c.Writer,
			body:          &bytes.Buffer{},
		}
		c.Writer = writer
		c.Next()

		// Store in cache
		if c.Writer.Status() == http.StatusOK {
			resp := cachedResponse{
				Status:  c.Writer.Status(),
				Headers: c.Writer.Header(),
				Body:    writer.body.Bytes(),
			}
			data, err := json.Marshal(resp)
			if err != nil {
				log.Printf("Error marshaling cached response: %v", err)
			} else {
				cacheLock.Lock()
				cache[key] = cacheEntry{
					data:       data,
					expiration: time.Now().Add(ttl),
				}
				cacheLock.Unlock()
			}
		}
	}
}
