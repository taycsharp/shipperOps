# Production Deployment: Linux + Docker + Cloudflare + Flutter

This project should run as three private Docker services on the Linux machine:

- `frontend`: Next.js dashboard/admin UI
- `backend`: FastAPI API + WebSocket GPS tracking
- `db`: PostgreSQL
- `cloudflared`: private Cloudflare Tunnel exposing only the public hostnames

Recommended public URLs:

```txt
Dashboard: https://dashboard.example.com
API:       https://api.example.com
WebSocket: wss://api.example.com/ws/locations
```

The Flutter app should connect only to the API URL:

```dart
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.example.com',
);

const wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'wss://api.example.com/ws/locations',
);
```

Run Flutter with production API:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_URL=wss://api.example.com/ws/locations
```

Build Android:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_URL=wss://api.example.com/ws/locations
```

Build iOS:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_URL=wss://api.example.com/ws/locations
```

## 1. Server preparation

Install Docker Engine and Docker Compose plugin on Linux. Then clone the project:

```bash
git clone <your-repo-url> shipper-management
cd shipper-management
```

Create production env:

```bash
cp .env.production.example .env.production
nano .env.production
```

Change at least:

```txt
POSTGRES_PASSWORD
JWT_SECRET
DASHBOARD_DOMAIN
API_DOMAIN
CORS_ORIGINS
NEXT_PUBLIC_API_URL
NEXT_PUBLIC_WS_URL
CLOUDFLARE_TUNNEL_TOKEN
```

Generate a strong JWT secret:

```bash
openssl rand -hex 32
```

## 2. Cloudflare Tunnel setup

In Cloudflare Zero Trust:

1. Go to `Networks` > `Tunnels`.
2. Create a tunnel.
3. Choose Docker environment.
4. Copy the tunnel token into `.env.production` as `CLOUDFLARE_TUNNEL_TOKEN`.
5. Add public hostnames:

```txt
dashboard.example.com -> http://frontend:3000
api.example.com       -> http://backend:8000
```

Cloudflare supports WebSocket traffic, so `wss://api.example.com/ws/locations` can use the same API hostname.

## 3. Start production

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build
```

Seed demo data once if needed:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec backend python -m app.seed
```

Check services:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml ps
```

Check logs:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml logs -f backend
```

## 4. API tests

Health check:

```bash
curl https://api.example.com/health
```

Login:

```bash
curl -X POST https://api.example.com/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@example.com","password":"admin123456"}'
```

Live locations:

```bash
curl https://api.example.com/locations/live
```

## 5. Important production notes

### Protect endpoints before real customers

The current MVP has useful business APIs, but several endpoints are still open. Before real deployment, add role-based authorization:

- Admin only: create/update shippers, assign orders, dashboard metrics
- Shipper only: update own GPS location, update own order/item status
- Authenticated users: read assigned data only

### Database migrations

The backend currently calls `Base.metadata.create_all()` on startup. This is okay for MVP, but production should use Alembic migrations instead.

Recommended next step:

```bash
docker compose exec backend alembic init alembic
```

Then generate migrations from SQLAlchemy models and run:

```bash
alembic upgrade head
```

### WebSocket scale

The WebSocket manager is in-memory. Run one backend instance first. If you scale the backend to multiple containers later, use Redis Pub/Sub or another message broker for broadcast synchronization.

### Backups

Create PostgreSQL backup:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec db \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup_$(date +%Y%m%d_%H%M%S).sql
```

Restore:

```bash
cat backup.sql | docker compose --env-file .env.production -f docker-compose.prod.yml exec -T db \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB"
```

## 6. Recommended professional architecture

```txt
Flutter App
   |
   | HTTPS + JWT
   v
Cloudflare -> api.example.com -> cloudflared -> FastAPI backend -> PostgreSQL

Admin Browser
   |
   | HTTPS
   v
Cloudflare -> dashboard.example.com -> cloudflared -> Next.js dashboard

Realtime GPS
   |
   | WSS
   v
Cloudflare -> api.example.com/ws/locations -> FastAPI WebSocket
```
