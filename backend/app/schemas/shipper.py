from datetime import datetime
from pydantic import BaseModel
from app.models.enums import ShipperStatus
from app.schemas.user import UserRead


class ShipperCreate(BaseModel):
    user_id: int
    vehicle_type: str | None = None
    vehicle_plate: str | None = None
    status: ShipperStatus = ShipperStatus.OFFLINE


class ShipperStatusUpdate(BaseModel):
    status: ShipperStatus


class ShipperRead(BaseModel):
    id: int
    user_id: int
    vehicle_type: str | None = None
    vehicle_plate: str | None = None
    status: ShipperStatus
    current_lat: float | None = None
    current_lng: float | None = None
    last_seen_at: datetime | None = None
    user: UserRead | None = None

    class Config:
        from_attributes = True
