from datetime import datetime
from sqlalchemy import String, DateTime, Float, Enum, ForeignKey, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.models.enums import DeliveryItemStatus


class DeliveryOrderItem(Base):
    __tablename__ = "delivery_order_items"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("delivery_orders.id", ondelete="CASCADE"), index=True, nullable=False)
    sku: Mapped[str | None] = mapped_column(String(80), nullable=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    delivered_quantity: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    unit_price: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    status: Mapped[DeliveryItemStatus] = mapped_column(
        Enum(DeliveryItemStatus), default=DeliveryItemStatus.PENDING, nullable=False
    )
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    picked_up_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    failed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    order = relationship("DeliveryOrder", back_populates="items")
