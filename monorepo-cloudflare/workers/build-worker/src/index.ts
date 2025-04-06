import { Hono } from 'hono';
import { auth } from './middleware/auth';

interface Env {
  BUILD_STATE: DurableObjectNamespace;
  API_TOKEN: string;
}

const app = new Hono<{ Bindings: Env }>();

// Apply auth middleware to all routes
app.use('*', auth);

// Helper to get build state DO
function getBuildStateId(env: Env) {
  return env.BUILD_STATE.idFromName('build-state');
}

// Helper to get build state DO stub
function getBuildState(env: Env) {
  const id = getBuildStateId(env);
  return env.BUILD_STATE.get(id);
}

// Routes for build management
app.post('/api/builds/start', async (c) => {
  const buildState = getBuildState(c.env);
  const data = await c.req.json();
  
  const response = await buildState.fetch(new Request('http://internal/start-build', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }));
  
  return c.json(await response.json());
});

app.post('/api/builds/complete', async (c) => {
  const buildState = getBuildState(c.env);
  const data = await c.req.json();
  
  const response = await buildState.fetch(new Request('http://internal/complete-build', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }));
  
  return c.json(await response.json());
});

app.get('/api/builds', async (c) => {
  const buildState = getBuildState(c.env);
  
  const response = await buildState.fetch(new Request('http://internal/builds', {
    method: 'GET'
  }));
  
  return c.json(await response.json());
});

app.get('/api/builds/:id', async (c) => {
  const buildState = getBuildState(c.env);
  const buildId = c.req.param('id');
  
  const response = await buildState.fetch(new Request(`http://internal/build/${buildId}`, {
    method: 'GET'
  }));
  
  return c.json(await response.json());
});

// Export for Cloudflare Workers
export default {
  fetch: app.fetch,
};

// Export the Durable Object
export { BuildState } from './durable-objects/build-state';
