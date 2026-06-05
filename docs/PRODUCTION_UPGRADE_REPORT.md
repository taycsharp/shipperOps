# Production Upgrade Report — ShipOps Pro

This upgrade keeps the original FastAPI + Next.js architecture and hardens the MVP into a more practical delivery operations platform.

## Implemented

### Security and authentication
- Functional `/login` page connected to `/auth/login`.
- JWT saved in localStorage and a SameSite cookie for browser and server-rendered dashboard calls.
- `/auth/me` is used to hydrate the current user.
- Logout clears token and cookie.
- Frontend route guard protects admin and shipper pages.
- Backend route guards added to dashboard, orders, shippers, and locations APIs.
- Role helpers added: `get_current_user`, `require_roles`, `get_current_shipper`, `require_admin_or_dispatcher`.
- Shipper scope enforcement prevents a shipper from updating another shipper’s location/order.
- WebSocket now requires a token query parameter.

### Backend production quality
- Added Alembic configuration and an initial production migration.
- Startup `Base.metadata.create_all()` is disabled by default and only available for development with `CREATE_ALL_ON_STARTUP=true`.
- Added indexes for order status/shipper, customer phone, shipper status, vehicle plate, and location shipper/time.
- Orders API now supports pagination and filters: status, shipper_id, date range, customer name/phone, order_code, unassigned_only, active_only.
- Shippers API now supports filtering by status, search, and live_only.
- Added order timeline table `order_events` and audit logging for created, assigned, status changed, item status changed, proof uploaded.
- Added proof-of-delivery upload endpoint with MIME/type and max-size validation.
- Added COD fields: collected flag, collected amount, payment method, settlement status.
- Added request logging and safe internal error response.
- Added smoke tests for public health and protected API access.

### Dispatch workflow
- Added valid order transition rules.
- Admin override exists for exceptional manual corrections.
- Assignment blocks offline/suspended shippers unless `force=true` is passed.
- Added `PARTIALLY_DELIVERED` order status for mixed item outcomes.
- Shipper is returned to AVAILABLE when no active orders remain.

### Frontend UI/UX
- Professional login form with validation, loading, error display, and role-based redirect.
- App shell displays signed-in user and logout.
- API helper sends JWT automatically and redirects to login on 401.
- Live map and WebSocket use token validation.
- Existing dashboard, dispatch board, fleet page, live map, simulator, and shipper mobile console are preserved.

### Deployment
- Docker production setup keeps backend, frontend, db, and cloudflared.
- Backend runs as non-root user and includes health check.
- PostgreSQL remains unexposed to public ports in production compose.
- Upload volume added for proof images.
- `.env.production.example` expanded with environment, upload folder, max upload size, and migration-friendly settings.
- Production helper script now supports `migrate`, `backup`, and `restore`.

## Demo credentials after seeding

- Admin: `admin@dolasol.com` / `admin123`
- Dispatcher: `dispatcher@dolasol.com` / `dispatcher123`
- Shippers: `shipper1@example.com` ... `shipper6@example.com` / `shipper123`

## Run locally

```bash
# from project root
docker compose up --build

# or backend only
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export CREATE_ALL_ON_STARTUP=true
export ENVIRONMENT=development
uvicorn app.main:app --reload

# frontend
cd frontend
npm install
npm run dev
```

## Production deploy

```bash
cp .env.production.example .env.production
# edit every secret and domain
./scripts-prod.sh up
./scripts-prod.sh migrate
./scripts-prod.sh seed
```

## Backup and restore

```bash
./scripts-prod.sh backup
./scripts-prod.sh restore backups/shipper_YYYYMMDD_HHMMSS.sql
```

## Test commands

```bash
cd backend
pytest
python -m compileall app tests
```

## Remaining limitations

- Nearest-shipper suggestion is prepared conceptually but not fully visualized in the assign dialog.
- Charts are still lightweight dashboard summaries; a chart library can be added later if needed.
- Proof upload stores files on local Docker volume; for larger production usage, consider S3/R2-compatible object storage.
- The simulator remains for development/testing and should be hidden or disabled for real production users.
