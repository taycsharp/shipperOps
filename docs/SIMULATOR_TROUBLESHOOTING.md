# Simulator Troubleshooting

The simulator does not use real laptop GPS. It sends fake moving GPS points to the backend.

## Important production notes

1. The simulator now loads existing shippers from the API (`GET /shippers`) instead of assuming shipper IDs are always `1..6`.
2. If there are no shippers, seed the database:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec backend python -m app.seed
```

3. Rebuild the frontend after changing `NEXT_PUBLIC_API_URL` or `NEXT_PUBLIC_WS_URL`:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml build frontend --no-cache
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate frontend
docker compose --env-file .env.production -f docker-compose.prod.yml restart cloudflared
```

4. Test the simulator API manually:

```bash
curl -X POST https://ship-api.dolasol.com/locations/update \
  -H 'Content-Type: application/json' \
  -d '{"shipper_id":1,"lat":10.7769,"lng":106.7009,"speed":20,"heading":90,"battery":90}'
```

If this returns `404`, your database does not have shipper ID `1`; run seed or use an actual ID from:

```bash
curl https://ship-api.dolasol.com/shippers
```
