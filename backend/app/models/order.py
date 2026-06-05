from datetime import datetime
from sqlalchemy import String, DateTime, Float, Enum, ForeignKey, Text, Index, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.models.enums import DeliveryStatus, CodSettlementStatus, PaymentMethod


class DeliveryOrder(Base):
    __tablename__ = "delivery_orders"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    order_code: Mapped[str] = mapped_column(String(40), unique=True, index=True, nullable=False)
    customer_name: Mapped[str] = mapped_column(String(120), nullable=False)
    customer_phone: Mapped[str] = mapped_column(String(40), nullable=False)
    pickup_address: Mapped[str] = mapped_column(Text, nullable=False)
    pickup_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    delivery_address: Mapped[str] = mapped_column(Text, nullable=False)
    delivery_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    delivery_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    cod_amount: Mapped[float] = mapped_column(Float, default=0)
    delivery_fee: Mapped[float] = mapped_column(Float, default=0)
    status: Mapped[DeliveryStatus] = mapped_column(Enum(DeliveryStatus), default=DeliveryStatus.PENDING, nullable=False)
    shipper_id: Mapped[int | None] = mapped_column(ForeignKey("shippers.id"), nullable=True)
    proof_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    delivery_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    receiver_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    failed_reason: Mapped[str | None] = mapped_column(String(120), nullable=True)
    cod_collected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    cod_collected_amount: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    payment_method: Mapped[PaymentMethod | None] = mapped_column(Enum(PaymentMethod), nullable=True)
    cod_settlement_status: Mapped[CodSettlementStatus] = mapped_column(Enum(CodSettlementStatus), default=CodSettlementStatus.PENDING, nullable=False)
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    picked_up_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    failed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    shipper = relationship("Shipper", back_populates="orders")
    items = relationship("DeliveryOrderItem", back_populates="order", cascade="all, delete-orphan")
    events = relationship("OrderEvent", back_populates="order", cascade="all, delete-orphan", order_by="OrderEvent.created_at.desc()")


Index("ix_delivery_orders_status_shipper", DeliveryOrder.status, DeliveryOrder.shipper_id)
Index("ix_delivery_orders_customer_phone", DeliveryOrder.customer_phone)
