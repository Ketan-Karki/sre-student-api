package routes

import (
	"log"
	"net/http"

	"example.com/sre-bootcamp-rest-api/middleware"
	"example.com/sre-bootcamp-rest-api/models"
	"github.com/gin-gonic/gin"
)

// createForumPost creates a new forum post
func createForumPost(c *gin.Context) {
	log.Println("Creating a new forum post...")
	var post models.ForumPost
	if err := c.ShouldBindJSON(&post); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}
	
	// Set the user who created this post
	user := middleware.GetUserFromContext(c)
	post.AuthorID = user.ID

	if err := post.Save(); err != nil {
		log.Println("Error saving forum post:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not create forum post. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Forum post created successfully!",
		"post":    post,
	})
}

// getForumPostByID retrieves a forum post by ID
func getForumPostByID(c *gin.Context) {
	id := c.Param("id")
	
	post, err := models.GetForumPostByID(id)
	if err != nil {
		log.Println("Error fetching forum post:", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "Forum post not found."})
		return
	}

	// Get the comments for this post
	comments, err := models.GetCommentsByPostID(id)
	if err != nil {
		log.Println("Error fetching comments:", err)
		comments = []models.ForumComment{} // Return empty array instead of error
	}

	c.JSON(http.StatusOK, gin.H{
		"post":     post,
		"comments": comments,
	})
}

// updateForumPost updates an existing forum post
func updateForumPost(c *gin.Context) {
	id := c.Param("id")
	
	// Check if post exists
	existingPost, err := models.GetForumPostByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Forum post not found."})
		return
	}

	var post models.ForumPost
	if err := c.ShouldBindJSON(&post); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}

	// Get current user
	user := middleware.GetUserFromContext(c)

	// Check if the user is the author of the post
	if existingPost.AuthorID != user.ID {
		c.JSON(http.StatusForbidden, gin.H{"message": "You can only update your own posts."})
		return
	}

	// Preserve post ID, author ID, and student ID
	post.ID = existingPost.ID
	post.AuthorID = existingPost.AuthorID
	post.StudentID = existingPost.StudentID

	if err := post.Update(); err != nil {
		log.Println("Error updating forum post:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not update forum post. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Forum post updated successfully!",
		"post":    post,
	})
}

// deleteForumPost deletes a forum post
func deleteForumPost(c *gin.Context) {
	id := c.Param("id")
	
	// Check if post exists
	post, err := models.GetForumPostByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Forum post not found."})
		return
	}

	// Get current user
	user := middleware.GetUserFromContext(c)

	// Check if the user is the author of the post or a staff member
	if post.AuthorID != user.ID && user.Role != models.RoleStaff && user.Role != models.RoleFaculty {
		c.JSON(http.StatusForbidden, gin.H{"message": "You can only delete your own posts."})
		return
	}

	// Set author ID for permission check if user is the author
	if post.AuthorID == user.ID {
		post.AuthorID = user.ID
	} else {
		// For staff/faculty, don't set author ID to allow deletion of any post
		post.AuthorID = ""
	}

	if err := post.Delete(); err != nil {
		log.Println("Error deleting forum post:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not delete forum post. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Forum post deleted successfully!",
	})
}

// getForumPostsByStudentID retrieves all forum posts for a student
func getForumPostsByStudentID(c *gin.Context) {
	studentID := c.Param("studentId")
	
	posts, err := models.GetForumPostsByStudentID(studentID)
	if err != nil {
		log.Println("Error fetching forum posts:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch forum posts. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if posts == nil {
		posts = []models.ForumPost{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"posts": posts,
		"count": len(posts),
	})
}

// createForumComment creates a new comment on a forum post
func createForumComment(c *gin.Context) {
	log.Println("Creating a new forum comment...")
	var comment models.ForumComment
	if err := c.ShouldBindJSON(&comment); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}
	
	// Check if the post exists
	_, err := models.GetForumPostByID(comment.PostID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Forum post not found."})
		return
	}
	
	// Set the user who created this comment
	user := middleware.GetUserFromContext(c)
	comment.AuthorID = user.ID

	if err := comment.Save(); err != nil {
		log.Println("Error saving forum comment:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not create forum comment. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Comment added successfully!",
		"comment": comment,
	})
}

// updateForumComment updates an existing comment
func updateForumComment(c *gin.Context) {
	id := c.Param("id")
	
	var comment models.ForumComment
	if err := c.ShouldBindJSON(&comment); err != nil {
		log.Println("Error binding JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Could not parse request data.",
			"error":   err.Error(),
		})
		return
	}
	
	comment.ID = id
	
	// Get current user
	user := middleware.GetUserFromContext(c)
	comment.AuthorID = user.ID

	if err := comment.Update(); err != nil {
		log.Println("Error updating forum comment:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not update forum comment. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Comment updated successfully!",
		"comment": comment,
	})
}

// getCommentsByPostID retrieves all comments for a forum post
func getCommentsByPostID(c *gin.Context) {
	postID := c.Param("postId")
	
	comments, err := models.GetCommentsByPostID(postID)
	if err != nil {
		log.Println("Error fetching comments:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Could not fetch comments. Try again later.",
			"error":   err.Error(),
		})
		return
	}

	if comments == nil {
		comments = []models.ForumComment{} // Return empty array instead of null
	}

	c.JSON(http.StatusOK, gin.H{
		"comments": comments,
		"count":    len(comments),
	})
}
