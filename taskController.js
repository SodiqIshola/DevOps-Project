let tasks = [
  { id: 1, title: "Buy groceries" },
  { id: 2, title: "Finish Express tutorial" }
];

let names = [
  { id: 1, name: "Alice" },
  { id: 2, name: "Bob" }
];

// --- GET ALL TASKS ---
exports.getTasks = (req, res) => {
  res.status(200).json(tasks);
};

// --- ADD A NEW TASK ---
exports.addTask = (req, res) => {
  const { title } = req.body;
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }

  const maxId = tasks.length > 0 ? Math.max(...tasks.map(t => t.id)) : 0;
  const newTask = { id: maxId + 1, title };
  tasks.push(newTask);
  res.status(201).json(newTask);

};

/**
 * DELETE A TASK BY ID
 * Uses Number.parseInt to convert the URL string parameter to a number
 */
exports.deleteTask = (req, res) => {
  const { id } = req.params; 
  
  const initialLength = tasks.length;
  // Use Number.parseInt for better explicitness and to avoid global scope issues
  tasks = tasks.filter(task => task.id !== Number.parseInt(id, 10));

  if (tasks.length === initialLength) {
    return res.status(404).json({ error: `Task with ID ${id} not found` });
  }

  res.status(200).json({ message: `Task ${id} deleted successfully` });
};


/**
 * UPDATE A TASK
 * Finds a task by ID and updates its title.
 */
exports.updateTask = (req, res) => {
  const { id } = req.params;
  const { title } = req.body;

  // Find the specific task in the array
  const task = tasks.find(t => t.id === Number.parseInt(id, 10));

  // If the task doesn't exist, send an error
  if (!task) {
    return res.status(404).json({ error: `Task with ID ${id} not found` });
  }

  // Update the title (if provided in the request body)
  if (title) {
    task.title = title;
  }

  // Send back the updated task
  res.status(200).json(task);
};

// --- GET TASKS (With Search) ---
exports.getTasks = (req, res) => {
  const { search } = req.query; // Access ?search=term from URL
  
  if (search) {
    // Filter tasks where the title includes the search term (case-insensitive)
    const filteredTasks = tasks.filter(t => 
      t.title.toLowerCase().includes(search.toLowerCase())
    );
    return res.status(200).json(filteredTasks);
  }
  
  res.status(200).json(tasks);
};


// --- GET TASKS (With Search & Sort) ---
exports.getTasks = (req, res) => {
  let filteredTasks = [...tasks]; // Create a copy so we don't mess up the original order
  const { search, sort } = req.query;

  // 1. Handle Searching
  if (search) {
    filteredTasks = filteredTasks.filter(t => 
      t.title.toLowerCase().includes(search.toLowerCase())
    );
  }

  // 2. Handle Sorting (Alphabetical A-Z)
  if (sort === 'abc') {
    filteredTasks.sort((a, b) => a.title.localeCompare(b.title));
  }

  res.status(200).json(filteredTasks);
};













// --- GET ALL NAMES ---
exports.getNames = (req, res) => {
  res.status(200).json(names);
};

// --- ADD A NEW NAME ---
exports.addName = (req, res) => {
  const { name } = req.body;  
  if (!name) {
    return res.status(400).json({ error: 'Name is required' });
  }
  
  
  // Calculate the next ID number
  // If the names list isn't empty, find the highest existing ID; otherwise, start at 0.
  const maxId = names.length > 0 ? Math.max(...names.map(n => n.id)) : 0;

  // Create the new name object
  // We add 1 to the highest ID found to ensure the new ID is unique.
  const newName = { id: maxId + 1, name };

  // Save the data
  // Push the new object into our names array.
  names.push(newName);

  // Send the response
  // Respond with a 201 (Created) status and the new object.
  res.status(201).json(newName);

};

/**
 * DELETE A NAME BY ID
 */
exports.deleteName = (req, res) => {
  const { id } = req.params;

  const initialLength = names.length;
  // Filtering out the name object where the ID matches the URL parameter
  names = names.filter(nameObj => nameObj.id !== Number.parseInt(id, 10));

  if (names.length === initialLength) {
    return res.status(404).json({ error: `Name with ID ${id} not found` });
  }

  res.status(200).json({ message: `Name with ID ${id} deleted` });
};

/**
 * UPDATE A NAME
 * Finds a name entry by ID and updates the name string.
 */
exports.updateName = (req, res) => {
  const { id } = req.params;
  const { name } = req.body; 

  // Find the specific name object in the array using the ID from the URL
  const nameEntry = names.find(n => n.id === Number.parseInt(id, 10));

  // If the ID doesn't exist, return a 404 error
  if (!nameEntry) {
    return res.status(404).json({ error: `Name with ID ${id} not found` });
  }

  // Update the object's name property if a new name was provided
  if (name) {
    nameEntry.name = name;
  }

  // Return the updated object to the user
  res.status(200).json(nameEntry);
};


// --- GET NAMES (With Search) ---
exports.getNames = (req, res) => {
  const { search } = req.query;
  
  if (search) {
    // Filter names list based on the search query
    const filteredNames = names.filter(n => 
      n.name.toLowerCase().includes(search.toLowerCase())
    );
    return res.status(200).json(filteredNames);
  }
  
  res.status(200).json(names);
};


// --- GET NAMES (With Search & Sort) ---
exports.getNames = (req, res) => {
  let filteredNames = [...names];
  const { search, sort } = req.query;

  if (search) {
    filteredNames = filteredNames.filter(n => 
      n.name.toLowerCase().includes(search.toLowerCase())
    );
  }

  // Alphabetical Sort for names
  if (sort === 'abc') {
    filteredNames.sort((a, b) => a.name.localeCompare(b.name));
  }

  res.status(200).json(filteredNames);
};
