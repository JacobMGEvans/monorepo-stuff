#!/bin/bash

# Create a bootstrap script for the TurboRepo monorepo with Cloudflare Workers
set -e

# Define text colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Creating TurboRepo with Cloudflare Workers Monorepo ===${NC}"

# Create the base directory
REPO_NAME=${1:-"monorepo-cloudflare"}
mkdir -p "$REPO_NAME"
cd "$REPO_NAME"

echo -e "${YELLOW}Creating directory structure...${NC}"

# Create directory structure
mkdir -p .github/workflows
mkdir -p apps/app1/src
mkdir -p apps/app2/src
mkdir -p packages/shared-ui/src
mkdir -p packages/utils/src
mkdir -p workers/build-worker/src/durable-objects
mkdir -p workers/ci-cd-worker/src/durable-objects

echo -e "${YELLOW}Creating root configuration files...${NC}"

# Create root package.json
cat > package.json << 'EOF'
{
  "name": "monorepo-cloudflare",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "lint": "turbo run lint",
    "test": "turbo run test",
    "clean": "turbo run clean"
  },
  "devDependencies": {
    "turbo": "^1.10.0"
  }
}
EOF

# Create turbo.json
cat > turbo.json << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "build/**"],
      "cache": true
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": [],
      "inputs": ["src/**/*.tsx", "src/**/*.ts", "test/**/*.ts", "test/**/*.tsx"]
    },
    "lint": {
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "clean": {
      "cache": false
    },
    "deploy": {
      "dependsOn": ["build", "test", "lint"],
      "outputs": []
    }
  }
}
EOF

# Create pnpm-workspace.yaml
cat > pnpm-workspace.yaml << 'EOF'
packages:
  - 'apps/*'
  - 'packages/*'
  - 'workers/*'
EOF

echo -e "${YELLOW}Creating GitHub Actions workflow...${NC}"

# Create GitHub Actions workflow file
cat > .github/workflows/ci-cd.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  API_TOKEN: ${{ secrets.API_TOKEN }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'pnpm'

      - name: Install PNPM
        uses: pnpm/action-setup@v2
        with:
          version: 8
          run_install: false

      - name: Get changed packages
        id: changed-packages
        run: |
          echo "::set-output name=packages::$(npx turbo-ignore)"

      - name: Install dependencies
        run: pnpm install

      - name: Build packages
        if: steps.changed-packages.outputs.packages != 'null'
        run: |
          pnpm turbo run build --filter="...[origin/main]"

      - name: Notify build worker
        if: success() && github.event_name == 'push'
        run: |
          curl -X POST "https://build-worker.yourdomain.workers.dev/api/builds/complete" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ env.API_TOKEN }}" \
            -d '{"buildId": "${{ github.run_id }}", "success": true, "artifacts": ["dist"]}'

  deploy:
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'pnpm'

      - name: Install PNPM
        uses: pnpm/action-setup@v2
        with:
          version: 8
          run_install: false

      - name: Install dependencies
        run: pnpm install

      - name: Start deployment
        id: start-deployment
        run: |
          response=$(curl -X POST "https://ci-cd-worker.yourdomain.workers.dev/api/deployments/start" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ env.API_TOKEN }}" \
            -d '{"environment": "production", "packages": ["app1", "app2"]}')
          echo "::set-output name=deploymentId::$(echo $response | jq -r '.deploymentId')"

      - name: Deploy Workers
        run: |
          cd workers/build-worker && pnpm run deploy
          cd ../ci-cd-worker && pnpm run deploy

      - name: Complete deployment
        if: always()
        run: |
          status="${{ job.status }}"
          success=false
          if [ "$status" == "success" ]; then
            success=true
          fi
          
          curl -X POST "https://ci-cd-worker.yourdomain.workers.dev/api/deployments/complete" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ env.API_TOKEN }}" \
            -d "{\"deploymentId\": \"${{ steps.start-deployment.outputs.deploymentId }}\", \"success\": $success, \"details\": {\"commit\": \"${{ github.sha }}\"}}"
EOF

echo -e "${YELLOW}Creating packages...${NC}"

# Create shared-ui package
cat > packages/shared-ui/package.json << 'EOF'
{
  "name": "shared-ui",
  "version": "0.0.1",
  "private": true,
  "main": "./src/index.js",
  "scripts": {
    "build": "echo 'Building shared-ui package'"
  }
}
EOF

cat > packages/shared-ui/src/index.js << 'EOF'
// Placeholder for shared UI components
export const Button = () => {
  return { type: 'button', text: 'Click me' };
};
EOF

# Create utils package
cat > packages/utils/package.json << 'EOF'
{
  "name": "utils",
  "version": "0.0.1",
  "private": true,
  "main": "./src/index.js",
  "scripts": {
    "build": "echo 'Building utils package'"
  }
}
EOF

cat > packages/utils/src/index.js << 'EOF'
// Placeholder for utility functions
export const formatDate = (date) => {
  return date.toISOString();
};
EOF

echo -e "${YELLOW}Creating sample applications...${NC}"

# Create App1
cat > apps/app1/package.json << 'EOF'
{
  "name": "app1",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "build": "echo 'Building app1'"
  },
  "dependencies": {
    "shared-ui": "workspace:*",
    "utils": "workspace:*"
  }
}
EOF

cat > apps/app1/src/index.js << 'EOF'
import { Button } from 'shared-ui';
import { formatDate } from 'utils';

console.log('App1 initialized with:', Button(), formatDate(new Date()));
EOF

# Create App2
cat > apps/app2/package.json << 'EOF'
{
  "name": "app2",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "build": "echo 'Building app2'"
  },
  "dependencies": {
    "shared-ui": "workspace:*",
    "utils": "workspace:*"
  }
}
EOF

cat > apps/app2/src/index.js << 'EOF'
import { Button } from 'shared-ui';
import { formatDate } from 'utils';

console.log('App2 initialized with:', Button(), formatDate(new Date()));
EOF

echo -e "${YELLOW}Creating Cloudflare Workers...${NC}"

# Create Build Worker
cat > workers/build-worker/package.json << 'EOF'
{
  "name": "build-worker",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  },
  "dependencies": {
    "hono": "^3.0.0"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.0.0",
    "wrangler": "^3.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

cat > workers/build-worker/wrangler.toml << 'EOF'
name = "build-worker"
main = "src/index.ts"
compatibility_date = "2023-10-10"

[durable_objects]
bindings = [
  { name = "BUILD_STATE", class_name = "BuildState" }
]

[[migrations]]
tag = "v1"
new_classes = ["BuildState"]

[vars]
API_TOKEN = "your-secure-token-here"
EOF

cat > workers/build-worker/src/durable-objects/build-state.ts << 'EOF'
export class BuildState implements DurableObject {
  private state: DurableObjectState;
  private buildInfo: any = {};

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "POST" && path === "/start-build") {
      const data = await request.json();
      const buildId = crypto.randomUUID();
      
      this.buildInfo[buildId] = {
        id: buildId,
        packageName: data.packageName,
        status: "running",
        startTime: Date.now(),
        dependencies: data.dependencies || []
      };
      
      await this.state.storage.put("builds", this.buildInfo);
      return new Response(JSON.stringify({ buildId }), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "POST" && path === "/complete-build") {
      const data = await request.json();
      const { buildId, success, artifacts } = data;
      
      if (this.buildInfo[buildId]) {
        this.buildInfo[buildId].status = success ? "success" : "failed";
        this.buildInfo[buildId].endTime = Date.now();
        this.buildInfo[buildId].artifacts = artifacts || [];
        
        await this.state.storage.put("builds", this.buildInfo);
        return new Response(JSON.stringify({ success: true }), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Build not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path === "/builds") {
      return new Response(JSON.stringify(this.buildInfo), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path.startsWith("/build/")) {
      const buildId = path.split("/").pop();
      
      if (this.buildInfo[buildId]) {
        return new Response(JSON.stringify(this.buildInfo[buildId]), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Build not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    return new Response("Not found", { status: 404 });
  }
}
EOF

cat > workers/build-worker/src/index.ts << 'EOF'
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
EOF

# Create CI/CD Worker
cat > workers/ci-cd-worker/package.json << 'EOF'
{
  "name": "ci-cd-worker",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  },
  "dependencies": {
    "hono": "^3.0.0"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.0.0",
    "wrangler": "^3.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

cat > workers/ci-cd-worker/wrangler.toml << 'EOF'
name = "ci-cd-worker"
main = "src/index.ts"
compatibility_date = "2023-10-10"

[durable_objects]
bindings = [
  { name = "DEPLOYMENT_STATE", class_name = "DeploymentState" }
]

[[migrations]]
tag = "v1"
new_classes = ["DeploymentState"]

[vars]
API_TOKEN = "your-secure-token-here"
EOF

cat > workers/ci-cd-worker/src/durable-objects/deployment-state.ts << 'EOF'
export class DeploymentState implements DurableObject {
  private state: DurableObjectState;
  private deployments: any = {};

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "POST" && path === "/start-deployment") {
      const data = await request.json();
      const deploymentId = crypto.randomUUID();
      
      this.deployments[deploymentId] = {
        id: deploymentId,
        environment: data.environment,
        packages: data.packages || [],
        status: "deploying",
        startTime: Date.now()
      };
      
      await this.state.storage.put("deployments", this.deployments);
      return new Response(JSON.stringify({ deploymentId }), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "POST" && path === "/complete-deployment") {
      const data = await request.json();
      const { deploymentId, success, details } = data;
      
      if (this.deployments[deploymentId]) {
        this.deployments[deploymentId].status = success ? "success" : "failed";
        this.deployments[deploymentId].endTime = Date.now();
        this.deployments[deploymentId].details = details || {};
        
        await this.state.storage.put("deployments", this.deployments);
        return new Response(JSON.stringify({ success: true }), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Deployment not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path === "/deployments") {
      return new Response(JSON.stringify(this.deployments), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path.startsWith("/deployment/")) {
      const deploymentId = path.split("/").pop();
      
      if (this.deployments[deploymentId]) {
        return new Response(JSON.stringify(this.deployments[deploymentId]), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Deployment not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    return new Response("Not found", { status: 404 });
  }
}
EOF

cat > workers/ci-cd-worker/src/index.ts << 'EOF'
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
EOF

# Create TypeScript configuration for workers
cat > workers/build-worker/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "lib": ["ES2020"],
    "types": ["@cloudflare/workers-types"],
    "moduleResolution": "node",
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
EOF

cat > workers/ci-cd-worker/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "lib": ["ES2020"],
    "types": ["@cloudflare/workers-types"],
    "moduleResolution": "node",
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
EOF

# Create environment template
cat > .env.template << 'EOF'
# Cloudflare Workers
CF_ACCOUNT_ID=your_account_id
CF_API_TOKEN=your_api_token

# Worker URLs
BUILD_WORKER_URL=build-worker.yourdomain.workers.dev
CI_CD_WORKER_URL=ci-cd-worker.yourdomain.workers.dev

# GitHub
GITHUB_TOKEN=your_github_token
EOF

# Create README.md
cat > README.md << 'EOF'
# Monorepo with Cloudflare Workers

This is a monorepo setup using TurboRepo and Cloudflare Workers.

## Setup

1. Copy `.env.template` to `.env` and fill in the required values
2. Install dependencies:
   ```bash
   pnpm install
   ```
3. Build the project:
   ```bash
   pnpm build
   ```

## Development

- Run development servers:
  ```bash
  pnpm dev
  ```

## Deployment

The project uses GitHub Actions for CI/CD. Make sure to set up the following secrets in your GitHub repository:
- CF_ACCOUNT_ID
- CF_API_TOKEN
- GITHUB_TOKEN

## Project Structure

- `apps/` - Contains the main applications
- `packages/` - Shared packages
- `workers/` - Cloudflare Workers
EOF

# Create a gitignore file
cat > .gitignore << 'EOF'
# Dependencies
node_modules
.pnp
.pnp.js

# Testing
coverage

# Build outputs
dist
build
.next
out

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Editor directories and files
.idea
.vscode
*.suo
*.ntvs*
*.njsproj
*.sln
*.sw?

# OS
.DS_Store
Thumbs.db

# Cloudflare
.wrangler/
.dev.vars