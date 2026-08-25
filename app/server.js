// server.js
const express = require('express');
const path = require('path');
const store = require('./store');

const app = express();
app.use(express.json());

// Serves public/index.html (and any future CSS/JS/assets) — the app's
// frontend. index: 'index.html' means a request to "/" resolves to
// public/index.html automatically.
app.use(express.static(path.join(__dirname, 'public')));

// Internally the app listens on PORT (default 3000). It gets exposed
// externally as port 80 via Docker's port mapping (-p 80:3000) and later
// via the ALB — this lets the container run as a non-root user (Step 2
// requirement), since non-root processes generally can't bind to ports
// below 1024 directly. See plan notes for the full reasoning.
const PORT = process.env.PORT || 3000;

const VALID_STATUSES = [
  'Not Started',
  'In Progress',
  'Waiting on Client',
  'Done',
];

// Required health check — infrastructure (Docker/ECS/ALB) pings this to
// confirm the app is alive. Must return exactly this shape.
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

// Update a project (any of: name, client, nextAction, status)
app.patch('/projects/:id', (req, res) => {
  const { name, client, nextAction, status } = req.body;

  if (status !== undefined && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
  }
  if (name !== undefined && !name.trim()) {
    return res.status(400).json({ error: 'name cannot be empty' });
  }
  if (client !== undefined && !client.trim()) {
    return res.status(400).json({ error: 'client cannot be empty' });
  }

  const updated = store.updateProject(req.params.id, { name, client, nextAction, status });
  if (!updated) {
    return res.status(404).json({ error: 'project not found' });
  }
  res.json(updated);
});

// Delete a project
app.delete('/projects/:id', (req, res) => {
  const deleted = store.deleteProject(req.params.id);
  if (!deleted) {
    return res.status(404).json({ error: 'project not found' });
  }
  res.status(204).send();
});

app.listen(PORT, () => {
  console.log(`tracker-app listening on port ${PORT}`);
});