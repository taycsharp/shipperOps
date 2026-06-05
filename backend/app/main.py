import logging
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.router import api_router
from app.core.config import settings
from app.db.session import Base, engine
from app.models import DeliveryOrder, DeliveryOrderItem, OrderEvent, Shipper, ShipperLocation, User  # noqa: F401

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("shipper-api")

if settings.create_all_on_startup and settings.environment != "production":
    Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Shipper Management API",
    version="0.3.0",
    description="Production-oriented FastAPI backend for GPS shipper tracking, dispatch, COD, proof-of-delivery, and item-level workflow.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

upload_root = Path(settings.upload_folder)
upload_root.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(upload_root)), name="uploads")


@app.middleware("http")
async def request_logging(request: Request, call_next):
    logger.info("%s %s", request.method, request.url.path)
    try:
        response = await call_next(request)
        logger.info("%s %s -> %s", request.method, request.url.path, response.status_code)
        return response
    except Exception:
        logger.exception("Unhandled API error at %s %s", request.method, request.url.path)
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})


app.include_router(api_router)


@app.get("/health", tags=["system"])
def health():
    return {"status": "ok", "environment": settings.environment}
