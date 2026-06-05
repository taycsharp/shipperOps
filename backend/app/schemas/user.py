from pydantic import BaseModel, EmailStr
from app.models.enums import UserRole


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    phone: str | None = None
    password: str
    role: UserRole = UserRole.SHIPPER


class UserRead(BaseModel):
    id: int
    name: str
    email: EmailStr
    phone: str | None = None
    role: UserRole

    class Config:
        from_attributes = True
