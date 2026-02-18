// Start application using nodemon: npm run dev

const express = require('express');
const app = express();
const taskController = require('./taskController');

app.use(express.json());

app.get('/tasks', taskController.getTasks);
app.post('/tasks', taskController.addTask);

app.get('/names', taskController.getNames);
app.post('/names', taskController.addName);

const port = 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
