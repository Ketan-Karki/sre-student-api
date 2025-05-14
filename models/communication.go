package models

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"time"

	"example.com/sre-bootcamp-rest-api/db"
	"github.com/google/uuid"
)

// ForumPost represents a post in the parent-teacher forum
type ForumPost struct {
	ID        string    `json:"id,omitempty"`
	Title     string    `json:"title" binding:"required"`
	Content   string    `json:"content" binding:"required"`
	AuthorID  string    `json:"author_id" binding:"required"` // ID of the user who created the post
	StudentID string    `json:"student_id" binding:"required"`
	CreatedAt time.Time `json:"created_at,omitempty"`
	UpdatedAt time.Time `json:"updated_at,omitempty"`
}

// ForumComment represents a comment on a forum post
type ForumComment struct {
	ID        string    `json:"id,omitempty"`
	PostID    string    `json:"post_id" binding:"required"`
	Content   string    `json:"content" binding:"required"`
	AuthorID  string    `json:"author_id" binding:"required"` // ID of the user who created the comment
	CreatedAt time.Time `json:"created_at,omitempty"`
	UpdatedAt time.Time `json:"updated_at,omitempty"`
}

// Save persists a new forum post to the database
func (fp *ForumPost) Save() error {
	if fp.Title == "" || fp.Content == "" || fp.AuthorID == "" || fp.StudentID == "" {
		return errors.New("invalid forum post data")
	}

	// Generate UUID if ID is empty
	if fp.ID == "" {
		fp.ID = uuid.New().String()
	}

	// Set timestamps
	now := time.Now()
	fp.CreatedAt = now
	fp.UpdatedAt = now

	query := `INSERT INTO forum_posts 
			(id, title, content, author_id, student_id, created_at, updated_at) 
			VALUES ($1, $2, $3, $4, $5, $6, $7)`
	log.Printf("Executing INSERT query: %s", query)

	result, err := db.DB.Exec(query, fp.ID, fp.Title, fp.Content, fp.AuthorID, fp.StudentID, fp.CreatedAt, fp.UpdatedAt)
	if err != nil {
		log.Printf("Error executing INSERT: %v", err)
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("failed to create forum post: no rows affected")
	}

	log.Printf("Successfully created forum post with ID: %s", fp.ID)
	return nil
}

// Update updates an existing forum post in the database
func (fp *ForumPost) Update() error {
	if fp.ID == "" || fp.Title == "" || fp.Content == "" || fp.AuthorID == "" || fp.StudentID == "" {
		return errors.New("invalid forum post data")
	}

	// Update timestamp
	fp.UpdatedAt = time.Now()

	query := `UPDATE forum_posts SET 
			title = $1, content = $2, updated_at = $3 
			WHERE id = $4 AND author_id = $5`
	log.Printf("Executing UPDATE query: %s", query)

	result, err := db.DB.Exec(query, fp.Title, fp.Content, fp.UpdatedAt, fp.ID, fp.AuthorID)
	if err != nil {
		log.Printf("Error executing UPDATE: %v", err)
		return fmt.Errorf("failed to execute update query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("forum post not found or you are not authorized to update it")
	}

	log.Printf("Successfully updated forum post with ID: %s", fp.ID)
	return nil
}

// Delete removes a forum post from the database
func (fp *ForumPost) Delete() error {
	if fp.ID == "" {
		return errors.New("forum post ID is required")
	}

	// First delete all comments associated with this post
	_, err := db.DB.Exec("DELETE FROM forum_comments WHERE post_id = $1", fp.ID)
	if err != nil {
		log.Printf("Error deleting comments for post: %v", err)
		return fmt.Errorf("failed to delete comments: %w", err)
	}

	// Then delete the post
	query := "DELETE FROM forum_posts WHERE id = $1"
	if fp.AuthorID != "" {
		query += " AND author_id = $2" // Only allow deletion by the author
	}
	
	log.Printf("Executing DELETE query: %s", query)

	var result sql.Result
	if fp.AuthorID != "" {
		result, err = db.DB.Exec(query, fp.ID, fp.AuthorID)
	} else {
		result, err = db.DB.Exec(query, fp.ID)
	}

	if err != nil {
		log.Printf("Error executing DELETE: %v", err)
		return fmt.Errorf("failed to execute delete query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("forum post not found or you are not authorized to delete it")
	}

	log.Printf("Successfully deleted forum post with ID: %s", fp.ID)
	return nil
}

// GetForumPostByID retrieves a forum post by its ID
func GetForumPostByID(id string) (*ForumPost, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, title, content, author_id, student_id, created_at, updated_at 
			FROM forum_posts WHERE id = $1`
	log.Printf("Executing SELECT query: %s", query)

	var post ForumPost
	err := db.DB.QueryRow(query, id).Scan(
		&post.ID,
		&post.Title,
		&post.Content,
		&post.AuthorID,
		&post.StudentID,
		&post.CreatedAt,
		&post.UpdatedAt,
	)
	if err != nil {
		log.Printf("Error scanning row: %v", err)
		return nil, fmt.Errorf("failed to scan forum post row: %w", err)
	}

	log.Printf("Successfully retrieved forum post with ID: %s", post.ID)
	return &post, nil
}

// GetForumPostsByStudentID retrieves all forum posts related to a student
func GetForumPostsByStudentID(studentID string) ([]ForumPost, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, title, content, author_id, student_id, created_at, updated_at 
			FROM forum_posts WHERE student_id = $1 ORDER BY created_at DESC`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, studentID)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var posts []ForumPost
	for rows.Next() {
		var post ForumPost
		err := rows.Scan(
			&post.ID,
			&post.Title,
			&post.Content,
			&post.AuthorID,
			&post.StudentID,
			&post.CreatedAt,
			&post.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan forum post row: %w", err)
		}
		posts = append(posts, post)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating forum post rows: %w", err)
	}

	return posts, nil
}

// Save persists a new forum comment to the database
func (fc *ForumComment) Save() error {
	if fc.PostID == "" || fc.Content == "" || fc.AuthorID == "" {
		return errors.New("invalid forum comment data")
	}

	// Generate UUID if ID is empty
	if fc.ID == "" {
		fc.ID = uuid.New().String()
	}

	// Set timestamps
	now := time.Now()
	fc.CreatedAt = now
	fc.UpdatedAt = now

	query := `INSERT INTO forum_comments 
			(id, post_id, content, author_id, created_at, updated_at) 
			VALUES ($1, $2, $3, $4, $5, $6)`
	log.Printf("Executing INSERT query: %s", query)

	result, err := db.DB.Exec(query, fc.ID, fc.PostID, fc.Content, fc.AuthorID, fc.CreatedAt, fc.UpdatedAt)
	if err != nil {
		log.Printf("Error executing INSERT: %v", err)
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("failed to create forum comment: no rows affected")
	}

	log.Printf("Successfully created forum comment with ID: %s", fc.ID)
	return nil
}

// Update updates an existing forum comment in the database
func (fc *ForumComment) Update() error {
	if fc.ID == "" || fc.Content == "" || fc.AuthorID == "" {
		return errors.New("invalid forum comment data")
	}

	// Update timestamp
	fc.UpdatedAt = time.Now()

	query := `UPDATE forum_comments SET 
			content = $1, updated_at = $2 
			WHERE id = $3 AND author_id = $4`
	log.Printf("Executing UPDATE query: %s", query)

	result, err := db.DB.Exec(query, fc.Content, fc.UpdatedAt, fc.ID, fc.AuthorID)
	if err != nil {
		log.Printf("Error executing UPDATE: %v", err)
		return fmt.Errorf("failed to execute update query: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		log.Printf("Error getting affected rows: %v", err)
		return fmt.Errorf("failed to get affected rows: %w", err)
	}
	if rows == 0 {
		return errors.New("forum comment not found or you are not authorized to update it")
	}

	log.Printf("Successfully updated forum comment with ID: %s", fc.ID)
	return nil
}

// GetCommentsByPostID retrieves all comments for a forum post
func GetCommentsByPostID(postID string) ([]ForumComment, error) {
	if db.DB == nil {
		return nil, errors.New("database connection not initialized")
	}

	query := `SELECT id, post_id, content, author_id, created_at, updated_at 
			FROM forum_comments WHERE post_id = $1 ORDER BY created_at ASC`
	log.Printf("Executing SELECT query: %s", query)

	rows, err := db.DB.Query(query, postID)
	if err != nil {
		log.Printf("Error executing SELECT: %v", err)
		return nil, fmt.Errorf("failed to execute select query: %w", err)
	}
	defer rows.Close()

	var comments []ForumComment
	for rows.Next() {
		var comment ForumComment
		err := rows.Scan(
			&comment.ID,
			&comment.PostID,
			&comment.Content,
			&comment.AuthorID,
			&comment.CreatedAt,
			&comment.UpdatedAt,
		)
		if err != nil {
			log.Printf("Error scanning row: %v", err)
			return nil, fmt.Errorf("failed to scan forum comment row: %w", err)
		}
		comments = append(comments, comment)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating rows: %v", err)
		return nil, fmt.Errorf("error iterating forum comment rows: %w", err)
	}

	return comments, nil
}
