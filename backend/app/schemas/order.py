from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import CodSettlementStatus, DeliveryItemStatus, DeliveryStatus, OrderEventType, PaymentMethod


class DeliveryOrderItemCreate(BaseModel):
    sku: str | None = None
    name: str
    description: str | None = None
    quantity: int = Field(default=1, ge=1)
    unit_price: float = Field(default=0, ge=0)
    weight_kg: float | None = None


class DeliveryOrderItemStatusUpdate(BaseModel):
    status: DeliveryItemStatus
    delivered_quantity: int | None = None
    note: str | None = None


class DeliveryOrderItemRead(BaseModel):
    id: int
    order_id: int
    sku: str | None = None
    name: str
    description: str | None = None
    quantity: int
    delivered_quantity: int
    unit_price: float
    weight_kg: float | None = None
    status: DeliveryItemStatus
    note: str | None = None

    class Config:
        from_attributes = True


class DeliveryOrderCreate(BaseModel):
    order_code: str
    customer_name: str
    customer_phone: str
    pickup_address: str
    pickup_lat: float | None = None
    pickup_lng: float | None = None
    delivery_address: str
    delivery_lat: float | None = None
    delivery_lng: float | None = None
    cod_amount: float = Field(default=0, ge=0)
    delivery_fee: float = Field(default=0, ge=0)
    items: list[DeliveryOrderItemCreate] = Field(default_factory=list)


class AssignOrderRequest(BaseModel):
    shipper_id: int
    force: bool = False


class UpdateOrderStatusRequest(BaseModel):
    status: DeliveryStatus
    delivery_note: str | None = None
    failed_reason: str | None = None
    receiver_name: str | None = None
    cod_collected: bool | None = None
    cod_collected_amount: float | None = None
    payment_method: PaymentMethod | None = None
    admin_override: bool = False


class ProofUploadResponse(BaseModel):
    proof_image_url: str
    order_id: int


class OrderEventRead(BaseModel):
    id: int
    order_id: int
    actor_user_id: int | None = None
    event_type: OrderEventType
    old_status: DeliveryStatus | None = None
    new_status: DeliveryStatus | None = None
    note: str | None = None
    event_metadata: dict | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class PaginatedOrders(BaseModel):
    items: list["DeliveryOrderRead"]
    total: int
    limit: int
    offset: int


class DeliveryOrderRead(BaseModel):
    id: int
    order_code: str
    customer_name: str
    customer_phone: str
    pickup_address: str
    pickup_lat: float | None = None
    pickup_lng: float | None = None
    delivery_address: str
    delivery_lat: float | None = None
    delivery_lng: float | None = None
    cod_amount: float
    delivery_fee: float
    status: DeliveryStatus
    shipper_id: int | None = None
    proof_image_url: str | None = None
    delivery_note: str | None = None
    receiver_name: str | None = None
    failed_reason: str | None = None
    cod_collected: bool = False
    cod_collected_amount: float = 0
    payment_method: PaymentMethod | None = None
    cod_settlement_status: CodSettlementStatus = CodSettlementStatus.PENDING
    delivered_at: datetime | None = None
    items: list[DeliveryOrderItemRead] = Field(default_factory=list)

    class Config:
        from_attributes = True
