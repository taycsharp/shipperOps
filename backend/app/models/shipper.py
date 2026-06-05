from datetime import datetime
from sqlalchemy import String, DateTime, Float, Enum, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.models.enums import ShipperStatus


class Shipper(Base):
    __tablename__ = "shippers"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, nullable=False)
    vehicle_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    vehicle_plate: Mapped[str | None] = mapped_column(String(40), nullable=True)
    status: Mapped[ShipperStatus] = mapped_column(Enum(ShipperStatus), default=ShipperStatus.OFFLINE, nullable=False)
    current_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    current_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="shipper")
    orders = relationship("DeliveryOrder", back_populates="shipper")
    locations = relationship("ShipperLocation", back_populates="shipper")


Index("ix_shippers_status", Shipper.status)
Index("ix_shippers_vehicle_plate", Shipper.vehicle_plate)
