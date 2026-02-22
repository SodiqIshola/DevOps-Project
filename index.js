// Start application using nodemon: npm run dev

const express = require('express');
const app = express();
const taskController = require('./taskController');

app.use(express.json());


// --- TASK ROUTES ---

// Listens for a GET request to /tasks and runs the getTasks function to show all data
app.get('/tasks', taskController.getTasks);
// Listens for a POST request to /tasks and runs addTask to save a new object from the body
app.post('/tasks', taskController.addTask);
// Listens for a DELETE request with an ID (e.g., /tasks/1) to remove that specific task
app.delete('/tasks/:id', taskController.deleteTask);
// Listens for a PUT request with an ID to find a task and update its title
app.put('/tasks/:id', taskController.updateTask);


// --- NAME ROUTES ---

// Listens for a GET request to /names to return the list of all name objects
app.get('/names', taskController.getNames);
// Listens for a POST request to /names to create and save a new name entry
app.post('/names', taskController.addName);
// Listens for a DELETE request with an ID (e.g., /names/2) to remove that name from the list
app.delete('/names/:id', taskController.deleteName);
// Listens for a PUT request with an ID to find a name object and change its text
app.put('/names/:id', taskController.updateName);




// Updated root route with clickable links
app.get('/', (req, res) => {
  res.send(`
    <h1>Welcome to the Task API!</h1>
    <p>Use the links below to view data:</p>
    <ul>
      <li><a href="/tasks">View Tasks (/tasks)</a></li>
      <li><a href="/names">View Names (/names)</a></li>
    </ul>
  `);
});

const port = 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
