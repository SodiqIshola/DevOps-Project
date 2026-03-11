
// Jest: Checks your logic by actually running your code to see if it works 
// (e.g., tests/taskController.test.js).


// Import the 'supertest' library, which allows us to simulate HTTP requests 
// (GET, POST, etc.) without starting a real server
const request = require('supertest');

// Import 'express' so we can create a temporary "mock" application for our tests to run against
const express = require('express');

// Initialize the temporary express application
const app = express();

// Import our controller so we can test the actual logic (the "Chef") inside our functions
const taskController = require('../taskController');


// Middleware to allow the test app to read JSON data in POST/PUT requests
app.use(express.json());

// --- MOCK ROUTES FOR TESTING ---
// We define these here so Supertest knows which controller functions to trigger
app.get('/tasks', taskController.getTasks);
app.post('/tasks', taskController.addTask);
app.put('/tasks/:id', taskController.updateTask);
app.delete('/tasks/:id', taskController.deleteTask);

app.get('/names', taskController.getNames);
app.post('/names', taskController.addName);
app.put('/names/:id', taskController.updateName);
app.delete('/names/:id', taskController.deleteName);

describe('Task Controller - Full API Test Suite', () => {

  // --- SECTION: TASK TESTS ---
  describe('Tasks API', () => {
    
    // GET: Verify the initial list contains the default data
    it('should return the default list of tasks', async () => {
      const res = await request(app).get('/tasks');
      expect(res.statusCode).toBe(200);
      expect(res.body.length).toBeGreaterThanOrEqual(2);
    });

    // POST: Test adding a new task and check if it returns the new object
    it('should add a new task and return it with a unique ID', async () => {
      const res = await request(app).post('/tasks').send({ title: 'Finish testing' });
      expect(res.statusCode).toBe(201);
      expect(res.body.title).toBe('Finish testing');
      expect(res.body).toHaveProperty('id');
    });

    // PUT: Test updating an existing task title by its ID
    it('should update an existing task title', async () => {
      const res = await request(app).put('/tasks/1').send({ title: 'Updated Task Name' });
      expect(res.statusCode).toBe(200);
      expect(res.body.title).toBe('Updated Task Name');
    });

    // DELETE: Test removing a task and verify it is no longer in the list
    it('should remove a task by ID', async () => {
      const res = await request(app).delete('/tasks/2');
      expect(res.statusCode).toBe(200);
      const check = await request(app).get('/tasks');
      expect(check.body.some(t => t.id === 2)).toBe(false);
    });

    // SEARCH: Test the query parameter filtering logic
    it('should search tasks by title using ?search= query', async () => {
      const res = await request(app).get('/tasks?search=Updated');
      expect(res.statusCode).toBe(200);
      expect(res.body[0].title).toContain('Updated');
    });
  });

  // --- SECTION: NAME TESTS ---
  describe('Names API', () => {
    
    // GET: Verify default names like Alice or Bob are present
    it('should return default list of names', async () => {
      const res = await request(app).get('/names');
      expect(res.statusCode).toBe(200);
      expect(res.body.some(n => n.name === 'Alice')).toBe(true);
    });

    // POST: Test adding a name and ensure the ID generation logic works
    it('should add a new name and handle IDs correctly', async () => {
      const res = await request(app).post('/names').send({ name: 'Charlie' });
      expect(res.statusCode).toBe(201);
      expect(res.body.name).toBe('Charlie');
    });

    // PUT: Test updating a name entry
    it('should update a name entry by ID', async () => {
      const res = await request(app).put('/names/1').send({ name: 'New Alice' });
      expect(res.statusCode).toBe(200);
      expect(res.body.name).toBe('New Alice');
    });

    // DELETE: Test removing a name entry
    it('should remove a name entry by ID', async () => {
      const res = await request(app).delete('/names/2');
      expect(res.statusCode).toBe(200);
      const check = await request(app).get('/names');
      expect(check.body.find(n => n.id === 2)).toBeUndefined();
    });

    // SEARCH: Verify searching names works independently of tasks
    it('should filter names by search query', async () => {
      const res = await request(app).get('/names?search=New');
      expect(res.statusCode).toBe(200);
      expect(res.body[0].name).toBe('New Alice');
    });
  });

  // --- SECTION: ERROR HANDLING ---
  describe('Error Handling', () => {
    
    // VALIDATION: Ensure the server rejects empty data with a 400 error
    it('should return 400 for missing required fields', async () => {
      const res = await request(app).post('/tasks').send({});
      expect(res.statusCode).toBe(400);
      expect(res.body.error).toBeDefined();
    });

    // NOT FOUND: Ensure the server returns 404 for IDs that don't exist
    it('should return 404 for non-existent IDs on DELETE/PUT', async () => {
      const res = await request(app).delete('/tasks/999');
      expect(res.statusCode).toBe(404);
      expect(res.body.error).toContain('not found');
    });
  });



  describe('Sorting Functionality', () => {
    // SORT: Test if tasks come back in alphabetical order
    it('should return tasks in alphabetical order when ?sort=abc is used', async () => {
      const res = await request(app).get('/tasks?sort=abc');
      expect(res.statusCode).toBe(200);
      
      // Check if the first item's title comes before the second item's title alphabetically
      const firstTitle = res.body[0].title;
      const secondTitle = res.body[1].title;
      expect(firstTitle.localeCompare(secondTitle)).toBeLessThanOrEqual(0);
    });
  });

});
