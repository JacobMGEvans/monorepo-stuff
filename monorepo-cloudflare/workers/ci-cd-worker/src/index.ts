import { Hono } from 'hono';
import { auth } from './middleware/auth';

interface Env {
  DEPLOYMENT_STATE: DurableObjectNamespace;
  API_TOKEN: string;
}

const app = new Hono<{ Bindings: Env }>();

// Apply auth middleware to all routes
app.use('*', auth);

// Helper to get deployment state DO
function getDeploymentStateId(env: Env) {
  return env.DEPLOYMENT_STATE.idFromName('deployment-state');
}

// Helper to get deployment state DO stub
function getDeploymentState(env: Env) {
  const id = getDeploymentStateId(env);
  return env.DEPLOYMENT_STATE.get(id);
}

// Routes for deployment management
app.post('/api/deployments/start', async (c) => {
  const deploymentState = getDeploymentState(c.env);
  const data = await c.req.json();
  
  const response = await deploymentState.fetch(new Request('http://internal/start-deployment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }));
  
  return c.json(await response.json());
});

app.post('/api/deployments/complete', async (c) => {
  const deploymentState = getDeploymentState(c.env);
  const data = await c.req.json();
  
  const response = await deploymentState.fetch(new Request('http://internal/complete-deployment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }));
  
  return c.json(await response.json());
});

app.get('/api/deployments', async (c) => {
  const deploymentState = getDeploymentState(c.env);
  
  const response = await deploymentState.fetch(new Request('http://internal/deployments', {
    method: 'GET'
  }));
  
  return c.json(await response.json());
});

app.get('/api/deployments/:id', async (c) => {
  const deploymentState = getDeploymentState(c.env);
  const deploymentId = c.req.param('id');
  
  const response = await deploymentState.fetch(new Request(`http://internal/deployment/${deploymentId}`, {
    method: 'GET'
  }));
  
  return c.json(await response.json());
});

// Export for Cloudflare Workers
export default {
  fetch: app.fetch,
};

// Export the Durable Object
export { DeploymentState } from './durable-objects/deployment-state';
