package middleware

import (
	"net/http"
	"strings"

	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// Role-based access control middleware
func AuthMiddleware(allowedRoles ...models.UserRole) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get token from Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		// Check if the Authorization header has the Bearer prefix
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header format must be Bearer {token}"})
			c.Abort()
			return
		}

		token := parts[1]
		// In a real application, this would validate a JWT or session token
		// For simplicity, we'll just check if the token is a valid user ID
		user, err := models.GetUserByID(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		// Check if user has an allowed role
		if len(allowedRoles) > 0 {
			roleAllowed := false
			for _, role := range allowedRoles {
				if user.Role == role {
					roleAllowed = true
					break
				}
			}

			if !roleAllowed {
				c.JSON(http.StatusForbidden, gin.H{"error": "You do not have permission to access this resource"})
				c.Abort()
				return
			}
		}

		// Set the user in the context for later use
		c.Set("user", user)
		c.Next()
	}
}

// GetUserFromContext retrieves the authenticated user from the Gin context
func GetUserFromContext(c *gin.Context) *models.User {
	user, exists := c.Get("user")
	if !exists {
		return nil
	}
	return user.(*models.User)
}
