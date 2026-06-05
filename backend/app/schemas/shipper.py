from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, model_validator

from app.models.enums import ShipperStatus
from app.schemas.user import UserRead


class ShipperLoginUserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    phone: str | None = Field(default=None, max_length=40)
    password: str = Field(min_length=8, max_length=72)


class ShipperLoginUserUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    phone: str | None = Field(default=None, max_length=40)


class ShipperCreate(BaseModel):
    user_id: int | None = None
    user: ShipperLoginUserCreate | None = None
    vehicle_type: str | None = Field(default=None, max_length=80)
    vehicle_plate: str | None = Field(default=None, max_length=40)
    status: ShipperStatus = ShipperStatus.OFFLINE

    @model_validator(mode="after")
    def has_login_account(self):
        if self.user_id is None and self.user is None:
            raise ValueError("Provide user_id or user details")
        if self.user_id is not None and self.user is not None:
            raise ValueError("Provide either user_id or user details, not both")
        return self


class ShipperUpdate(BaseModel):
    user_id: int | None = None
    user: ShipperLoginUserUpdate | None = None
    vehicle_type: str | None = Field(default=None, max_length=80)
    vehicle_plate: str | None = Field(default=None, max_length=40)
    status: ShipperStatus | None = None


class ShipperLinkAccount(BaseModel):
    user_id: int


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
    last_gps_update_at: datetime | None = None
    is_online: bool = False
    active_order_count: int = 0
    user: UserRead | None = None

    class Config:
        from_attributes = True
