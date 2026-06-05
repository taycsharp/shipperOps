#!/usr/bin/env bash
set -euo pipefail

COMPOSE="docker compose --env-file .env.production -f docker-compose.prod.yml"

case "${1:-}" in
  up)
    $COMPOSE up -d --build
    ;;
  down)
    $COMPOSE down
    ;;
  logs)
    $COMPOSE logs -f "${2:-}"
    ;;
  ps)
    $COMPOSE ps
    ;;
  migrate)
    $COMPOSE exec backend alembic upgrade head
    ;;
  seed)
    $COMPOSE exec backend python -m app.seed
    ;;
  backup)
    mkdir -p backups
    $COMPOSE exec -T db pg_dump -U "${POSTGRES_USER:-shipper}" "${POSTGRES_DB:-shipper_db}" > "backups/shipper_$(date +%Y%m%d_%H%M%S).sql"
    ;;
  restore)
    if [ -z "${2:-}" ]; then echo "Usage: ./scripts-prod.sh restore backups/file.sql"; exit 1; fi
    $COMPOSE exec -T db psql -U "${POSTGRES_USER:-shipper}" "${POSTGRES_DB:-shipper_db}" < "$2"
    ;;
  *)
    echo "Usage: ./scripts-prod.sh {up|down|logs [service]|ps|migrate|seed|backup|restore file.sql}"
    exit 1
    ;;
esac
