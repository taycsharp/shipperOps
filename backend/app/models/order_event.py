from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import DeliveryStatus, OrderEventType


class OrderEvent(Base):
    __tablename__ = "order_events"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("delivery_orders.id", ondelete="CASCADE"), index=True, nullable=False)
    actor_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    event_type: Mapped[OrderEventType] = mapped_column(Enum(OrderEventType), nullable=False)
    old_status: Mapped[DeliveryStatus | None] = mapped_column(Enum(DeliveryStatus), nullable=True)
    new_status: Mapped[DeliveryStatus | None] = mapped_column(Enum(DeliveryStatus), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    event_metadata: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    order = relationship("DeliveryOrder", back_populates="events")
