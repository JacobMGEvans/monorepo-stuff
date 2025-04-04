#!/bin/bash
# Bootstrap script for TurboRepo monorepo with Cloudflare Workers

mkdir -p monorepo-cloudflare
cd monorepo-cloudflare

mkdir -p .github/workflows
mkdir -p apps/app1/src
mkdir -p apps/app2/src
mkdir -p packages/shared-ui/src
mkdir -p packages/utils/src
mkdir -p workers/build-worker/src/durable-objects
mkdir -p workers/ci-cd-worker/src/durable-objects

# Create root configuration files
touch package.json
touch turbo.json
touch pnpm-workspace.yaml

# Create GitHub Actions workflow
touch .github/workflows/ci-cd.yml

# Create app files
touch apps/app1/package.json
touch apps/app1/src/index.js
touch apps/app2/package.json
touch apps/app2/src/index.js

# Create package files
touch packages/shared-ui/package.json
touch packages/shared-ui/src/index.js
touch packages/utils/package.json
touch packages/utils/src/index.js

# Create build worker files
touch workers/build-worker/package.json
touch workers/build-worker/wrangler.toml
touch workers/build-worker/src/index.ts
touch workers/build-worker/src/durable-objects/build-state.ts

# Create CI/CD worker files
touch workers/ci-cd-worker/package.json
touch workers/ci-cd-worker/wrangler.toml
touch workers/ci-cd-worker/src/index.ts
touch workers/ci-cd-worker/src/durable-objects/deployment-state.ts

echo "Monorepo structure created successfully!"
echo "Please copy and paste the code into the appropriate files."
echo "Directory structure:"
find . -type f | sort

# Initialize git repository
git init
echo "node_modules" > .gitignore
echo "dist" >> .gitignore
echo ".turbo" >> .gitignore
echo ".env" >> .gitignore

echo "Git repository initialized with basic .gitignore"