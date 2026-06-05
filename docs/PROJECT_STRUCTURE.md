# Project Organization

This version is organized for GitHub and future production work.

## Backend

```txt
backend/app/
├── api/              # FastAPI route modules only
├── core/             # settings/config
├── db/               # SQLAlchemy session/base
├── models/           # database models
├── schemas/          # Pydantic request/response schemas
└── services/         # workflow, serialization, websocket logic
```

### Backend rule

Keep API files thin. Business rules should go to `services/`.

Examples:

- `services/order_workflow.py`: delivery state transitions and shipper availability logic
- `services/serializers.py`: WebSocket event payload formatting
- `services/websocket_manager.py`: connected client management

## Frontend

```txt
frontend/
├── app/              # Next.js pages/routes
├── components/       # reusable UI blocks
│   ├── common/       # small reusable components
│   ├── layout/       # page shell/navigation
│   └── orders/       # order-specific UI
├── hooks/            # reusable browser logic
├── lib/              # API and formatting helpers
└── types/            # shared TypeScript types
```

### Frontend rule

Pages should orchestrate data and actions. Reusable UI belongs in `components/`.

## Realtime events

All realtime messages go through `/ws/locations`.

Supported event types:

```txt
shipper_location
shipper_status
order_created
order_assigned
order_status
order_item_created
order_item_status
```

## Local map

The local map file is intentionally ignored by Git because it can be large:

```txt
frontend/public/maps/hcm.pmtiles
```

Keep `frontend/public/maps/README.md` in Git, but do not commit PMTiles files.
