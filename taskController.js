
let tasks = [];
let names = [];

exports.getTasks = (req, res) => {
  res.status(200).json(tasks);
};

exports.addTask = (req, res) => {
  const { title } = req.body;
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }
  const newTask = { id: tasks.length + 1, title };
  tasks.push(newTask);
  res.status(201).json(newTask);
};



exports.getNames = (req, res) => {
  res.status(200).json(names);
};

exports.addName = (req, res) => {
  const { name } = req.body;  
  if (!name) {
    return res.status(400).json({ error: 'Name is required' });
  } 
  const newName = { id: names.length + 1, name };
  names.push(newName);
  console.log('Added name:', newName);
  res.status(201).json(newName);
};  