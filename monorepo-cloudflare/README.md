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
