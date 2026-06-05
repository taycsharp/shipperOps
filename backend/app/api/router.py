from fastapi import APIRouter

from app.api import auth, dashboard, locations, orders, shippers

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(shippers.router)
api_router.include_router(orders.router)
api_router.include_router(locations.router)
api_router.include_router(dashboard.router)
