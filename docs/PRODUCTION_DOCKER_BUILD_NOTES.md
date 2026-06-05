# Production Docker build notes

The frontend production Dockerfile uses Next.js `output: 'standalone'` to avoid copying the full `node_modules` folder into the final runtime image. This keeps the image smaller and makes builds much faster on lightweight Linux machines.

Important files:

- `frontend/next.config.js` enables `output: 'standalone'`.
- `frontend/Dockerfile.prod` copies `.next/standalone` and `.next/static` instead of full `node_modules`.
- `docker-compose.prod.yml` passes `NEXT_PUBLIC_*` values as build args because Next.js public environment variables are compiled into the browser bundle during `npm run build`.
- `.dockerignore` prevents local `node_modules`, `.next`, virtualenvs, logs, and `.env.production` from being sent into the Docker build context.

Recommended rebuild:

```bash
docker builder prune
docker compose --env-file .env.production -f docker-compose.prod.yml build frontend --progress=plain
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```
