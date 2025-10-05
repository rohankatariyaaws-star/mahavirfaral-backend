# AWS ECS Modular Deployment Scripts

This folder contains a modular rewrite of `deploy-ecs-fargate.sh` split into focused scripts.

Files:

- `config.sh` - Central configuration and .env loader
- `utils.sh` - Logging, platform detection, helpers
- `dependencies.sh` - Dependency checks
- `rds.sh` - Find or create RDS instance
- `db_schema.sh` - Initialize DB schema
- `security.sh` - Fix security groups and mixed-content proxy
- `docker_build.sh` - Build backend JAR, Docker image, push to ECR (hash-cached)
- `ecs_cluster.sh` - Ensure ECS cluster
- `task_def.sh` - Create task definition
- `ecs_service.sh` - Create/update ECS service
- `scaling.sh` - Scheduled scaling
- `lambda.sh` - Lambda IP updater and Netlify wiring
- `netlify.sh` - Frontend build and Netlify deploy
- `test.sh` - Test deployment and retrieve service URL
- `main.sh` - Orchestrator and menu

Quick start:

1. Copy `.env.example` to `.env` and edit values.
2. Make scripts executable: `chmod +x *.sh`
3. Run `./main.sh` and choose options.

Notes:

- Supports dry-run mode with `DRY_RUN=true` in `.env`.
- Handles Windows by using PowerShell for zip when needed.
- Uses hashing to skip unnecessary builds.

Proxying API through Netlify (avoid mixed-content):

- Set `NETLIFY_PROXY_API=true` in your `.env` and ensure `NETLIFY_TOKEN` and `NETLIFY_SITE_ID` are set.
- The deploy will add a `build/_redirects` file mapping `/api/*` to your backend (example: `/api/*  http://13.203.73.207:8080/:splat 200`).
- Frontend will be built with `REACT_APP_API_URL=/api` so browser requests are proxied by Netlify over HTTPS, avoiding mixed-content.
