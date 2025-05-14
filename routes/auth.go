package routes

import (
	"log"
	"net/http"

	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// registerUser handles the creation of a new user
func registerUser(c *gin.Context) {
	log.Println("Registering a new user...")
	var user models.User
	err := c.ShouldBindJSON(&user)

	if err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}

	if err := user.Save(); err != nil {
		log.Println("Error saving user:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not create user. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	// Don't return the password in the response
	user.Password = ""
	user.PasswordHash = ""

	c.JSON(http.StatusCreated, gin.H{
		"message": "User created successfully!",
		"user":    user,
	})
}

// loginUser authenticates a user and returns a token
func loginUser(c *gin.Context) {
	var credentials struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}

	if err := c.ShouldBindJSON(&credentials); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid credentials format"})
		return
	}

	user, err := models.Authenticate(credentials.Username, credentials.Password)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	// In a real application, you would generate a JWT token here
	// For now, we'll just return the user ID as a token
	c.JSON(http.StatusOK, gin.H{
		"message": "Login successful",
		"token":   user.ID,
		"user": gin.H{
			"id":        user.ID,
			"username":  user.Username,
			"email":     user.Email,
			"firstName": user.FirstName,
			"lastName":  user.LastName,
			"role":      user.Role,
		},
	})
}

// getUsers returns all users (admin only)
func getUsers(c *gin.Context) {
	users, err := models.GetAllUsers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
		return
	}

	// Remove sensitive information
	for i := range users {
		users[i].Password = ""
		users[i].PasswordHash = ""
	}

	c.JSON(http.StatusOK, gin.H{
		"users": users,
		"count": len(users),
	})
}

// getUserByID returns a specific user by ID
func getUserByID(c *gin.Context) {
	id := c.Param("id")
	user, err := models.GetUserByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Remove sensitive information
	user.Password = ""
	user.PasswordHash = ""

	c.JSON(http.StatusOK, gin.H{"user": user})
}

// updateUser updates a user's information
func updateUser(c *gin.Context) {
	id := c.Param("id")
	
	// First check if user exists
	_, err := models.GetUserByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user data"})
		return
	}

	user.ID = id
	if err := user.Update(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
		return
	}

	// Remove sensitive information
	user.Password = ""
	user.PasswordHash = ""

	c.JSON(http.StatusOK, gin.H{
		"message": "User updated successfully",
		"user":    user,
	})
}

// deleteUser removes a user from the system
func deleteUser(c *gin.Context) {
	id := c.Param("id")
	
	user, err := models.GetUserByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if err := user.Delete(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User deleted successfully"})
}
