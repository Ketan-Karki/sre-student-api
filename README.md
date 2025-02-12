# Student API

A RESTful API for managing student records, built using Go and the Gin framework. This API provides endpoints for creating, retrieving, updating, and deleting student information, facilitating easy integration with front-end applications and supporting various operations related to student data management.

## Purpose of the Repository

This repository contains the source code for the Student API, a RESTful API designed to manage student records. The API is built using Go and the Gin framework, providing a robust and scalable solution for student data management.

## Local Setup Instructions

To set up the project locally, follow these steps:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ketan-karki/student-api.git
   cd student-api
   ```

2. **Install Go:**
   Ensure you have Go installed on your machine. You can download it from [the official Go website](https://golang.org/dl/).

3. **Install dependencies:**
   Navigate to the project directory and run the following command to install the necessary dependencies:
   ```bash
   go mod tidy
   ```

4. **Run the application:**
   To start the API server, use the following command:
   ```bash
   go run main.go
   ```

5. **Access the API:**
   The API will be running at `http://localhost:8080`. You can use tools like Postman or curl to interact with the endpoints.

## API Endpoints

- `GET /students`: Retrieve a list of students.
- `POST /students`: Create a new student record.
- `GET /students/:id`: Retrieve a specific student by ID.
- `PUT /students/:id`: Update a student's information.
- `DELETE /students/:id`: Delete a student record.

## Docker Instructions

## Prerequisites
- Ensure that you have Docker installed on your machine.

## Building the Docker Image
To build the Docker image, run the following command in the root of the project:
```bash
docker build -t ketan-karki/student-api .
```

## Running the Docker Container
To run the Docker container, use the following command:
```bash
docker run -d -p 8080:80 ketan-karki/student-api
```

### Contribution Guidelines
I welcome contributions to enhance the Student API. Please fork the repository and submit a pull request with your changes. Ensure your code adheres to the project's coding standards and includes appropriate tests.

## License

This project is licensed under the MIT License.

## Contact
For any questions or support, please contact the project maintainer at [ketankarki2626@gmail.com].