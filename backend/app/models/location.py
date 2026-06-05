from datetime import datetime
from sqlalchemy import DateTime, Float, Integer, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base


class ShipperLocation(Base):
    __tablename__ = "shipper_locations"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    shipper_id: Mapped[int] = mapped_column(ForeignKey("shippers.id"), index=True, nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    speed: Mapped[float | None] = mapped_column(Float, nullable=True)
    heading: Mapped[float | None] = mapped_column(Float, nullable=True)
    battery: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    shipper = relationship("Shipper", back_populates="locations")


Index("ix_shipper_locations_shipper_created", ShipperLocation.shipper_id, ShipperLocation.created_at)
