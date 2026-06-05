# ShipOps Pro — Shipper / Delivery Order Management

Production-oriented shipper management system using FastAPI, PostgreSQL, SQLAlchemy, JWT, WebSocket live GPS, Next.js App Router, React, Material UI, MapLibre/PMTiles, Docker, and Cloudflare Tunnel.

## Core features

- Secure login and JWT auth
- Role-based access: ADMIN, DISPATCHER, SHIPPER
- Admin dashboard
- Dispatch board
- Shipper management
- Live GPS map with token-protected WebSocket
- Mobile-first shipper console
- Order and item-level tracking
- COD fields and settlement status
- Proof-of-delivery upload
- Order audit timeline
- Docker production deployment
- Cloudflare Tunnel support

## Demo credentials after seed

- Admin: `admin@dolasol.com` / `admin123`
- Dispatcher: `dispatcher@dolasol.com` / `dispatcher123`
- Shipper: `shipper1@example.com` / `shipper123`

## Local development

```bash
docker compose up --build
```

Backend: http://localhost:8000  
Frontend: http://localhost:3000

For backend-only development:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export ENVIRONMENT=development
export CREATE_ALL_ON_STARTUP=true
uvicorn app.main:app --reload
```

For frontend-only development:

```bash
cd frontend
npm install
npm run dev
```

## Database migration

Production should use Alembic instead of runtime `create_all`.

```bash
cd backend
alembic upgrade head
```

For Docker production:

```bash
./scripts-prod.sh migrate
```

## Seed demo data

```bash
cd backend
python -m app.seed
```

For Docker production:

```bash
./scripts-prod.sh seed
```

## Production deployment

```bash
cp .env.production.example .env.production
# edit secrets/domains carefully
./scripts-prod.sh up
./scripts-prod.sh migrate
./scripts-prod.sh seed
```

Production compose keeps PostgreSQL private inside the Docker network. Public access should go through Cloudflare Tunnel for the API and dashboard domains.

## Backup and restore

```bash
./scripts-prod.sh backup
./scripts-prod.sh restore backups/shipper_YYYYMMDD_HHMMSS.sql
```

## GPS troubleshooting

- Mobile browser must allow location permission.
- iPhone/Safari often requires HTTPS for geolocation.
- Confirm `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_WS_URL` point to the Cloudflare API domain.
- Login is required before GPS update and WebSocket live map can work.
- Check stale GPS shippers in dashboard/fleet page.

## Tests

```bash
cd backend
pytest
python -m compileall app tests
```

## More details

See `docs/PRODUCTION_UPGRADE_REPORT.md`.
