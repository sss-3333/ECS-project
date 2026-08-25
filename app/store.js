// store.js
// Very small file-backed "database". Reads the whole file into memory,
// writes the whole file back on every change. Fine for a demo app with
// a handful of projects — not built for concurrent heavy writes.
//
// Note: on ECS/Fargate this file resets on every task restart/redeploy,
// since containers are ephemeral. That's an accepted tradeoff for this
// project (see plan notes) — not a bug.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DATA_FILE = path.join(__dirname, 'data.json');

function load() {
  if (!fs.existsSync(DATA_FILE)) {
    return [];
  }
  const raw = fs.readFileSync(DATA_FILE, 'utf-8');
  return JSON.parse(raw || '[]');
}

function save(projects) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(projects, null, 2));
}

function getAll() {
  return load();
}

function addProject({ name, client, status, nextAction }) {
  const projects = load();
  const project = {
    id: crypto.randomUUID(),
    name,
    client,
    status: status || 'Not Started',
    nextAction: nextAction || '',
    createdAt: new Date().toISOString(),
  };
  projects.push(project);
  save(projects);
  return project;
}

function updateProject(id, updates) {
  const projects = load();
  const project = projects.find((p) => p.id === id);
  if (!project) return null;

  if (updates.name !== undefined) project.name = updates.name;
  if (updates.client !== undefined) project.client = updates.client;
  if (updates.nextAction !== undefined) project.nextAction = updates.nextAction;
  if (updates.status !== undefined) project.status = updates.status;

  save(projects);
  return project;
}

function deleteProject(id) {
  const projects = load();
  const index = projects.findIndex((p) => p.id === id);
  if (index === -1) return false;
  projects.splice(index, 1);
  save(projects);
  return true;
}

module.exports = { getAll, addProject, updateProject, deleteProject };