const express = require('express');
const path = require('path');
const store = require('./store');

const app = express();
app.use(express.json());

app.use(express.static(path.join(__dirname, 'public')));

const PORT = process.env.PORT || 3000;

const VALID_STATUSES = [
  'Not Started',
  'In Progress',
  'Waiting on Client',
  'Done',
];

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// List all projects
app.get('/projects', (req, res) => {
  res.json(store.getAll());
});

// Add a new project
app.post('/projects', (req, res) => {
  const { name, client, status, nextAction } = req.body;

  if (!name || !client) {
    return res.status(400).json({ error: 'name and client are required' });
  }
  if (status && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
  }

  const project = store.addProject({ name, client, status, nextAction });
  res.status(201).json(project);
});

// Update a project's status
app.patch('/projects/:id', (req, res) => {
  const { status } = req.body;

  if (!status || !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
  }

  const updated = store.updateStatus(req.params.id, status);
  if (!updated) {
    return res.status(404).json({ error: 'project not found' });
  }
  res.json(updated);
});

app.listen(PORT, () => {
  console.log(`tracker-app listening on port ${PORT}`);
});
