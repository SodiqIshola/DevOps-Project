
// Jest: Checks your logic by actually running your code to see if it works 
// (e.g., tests/taskController.test.js).


const request = require('supertest');
const express = require('express');
const app = express();
const taskController = require('../taskController');

app.use(express.json());
app.get('/tasks', taskController.getTasks);
app.post('/tasks', taskController.addTask);

describe('Task Controller', () => {
  it('should return an empty list of tasks initially', async () => {
    const res = await request(app).get('/tasks');
    expect(res.statusCode).toEqual(200);
    expect(res.body).toEqual([]);
  });

  it('should add a task', async () => {
    const res = await request(app)
      .post('/tasks')
      .send({ title: 'Test Task' });
    expect(res.statusCode).toEqual(201);
    expect(res.body.title).toBe('Test Task');
  });

  it('should return 400 for missing title', async () => {
    const res = await request(app).post('/tasks').send({});
    expect(res.statusCode).toEqual(400);
    expect(res.body.error).toBe('Title is required');
  });
});
