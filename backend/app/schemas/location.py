from datetime import datetime
from pydantic import BaseModel, Field


class LocationUpdate(BaseModel):
    shipper_id: int
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    speed: float | None = None
    heading: float | None = None
    battery: int | None = Field(default=None, ge=0, le=100)


class LocationRead(BaseModel):
    id: int
    shipper_id: int
    lat: float
    lng: float
    speed: float | None = None
    heading: float | None = None
    battery: int | None = None
    created_at: datetime

    class Config:
        from_attributes = True
