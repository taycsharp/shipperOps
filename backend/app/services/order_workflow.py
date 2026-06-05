from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.enums import DeliveryItemStatus, DeliveryStatus, ShipperStatus, UserRole
from app.models.order import DeliveryOrder
from app.models.order_item import DeliveryOrderItem
from app.models.shipper import Shipper
from app.services.serializers import enum_value

ACTIVE_ORDER_STATUSES = [
    DeliveryStatus.ASSIGNED,
    DeliveryStatus.PICKED_UP,
    DeliveryStatus.IN_TRANSIT,
    DeliveryStatus.PARTIALLY_DELIVERED,
]

FINAL_ORDER_STATUSES = [
    DeliveryStatus.DELIVERED,
    DeliveryStatus.FAILED,
    DeliveryStatus.CANCELLED,
    DeliveryStatus.RETURNED,
]

VALID_STATUS_TRANSITIONS: dict[DeliveryStatus, set[DeliveryStatus]] = {
    DeliveryStatus.PENDING: {DeliveryStatus.ASSIGNED, DeliveryStatus.CANCELLED},
    DeliveryStatus.ASSIGNED: {DeliveryStatus.PICKED_UP, DeliveryStatus.CANCELLED},
    DeliveryStatus.PICKED_UP: {DeliveryStatus.IN_TRANSIT},
    DeliveryStatus.IN_TRANSIT: {DeliveryStatus.DELIVERED, DeliveryStatus.FAILED, DeliveryStatus.RETURNED, DeliveryStatus.PARTIALLY_DELIVERED},
    DeliveryStatus.PARTIALLY_DELIVERED: {DeliveryStatus.DELIVERED, DeliveryStatus.FAILED, DeliveryStatus.RETURNED},
    DeliveryStatus.DELIVERED: set(),
    DeliveryStatus.FAILED: set(),
    DeliveryStatus.RETURNED: set(),
    DeliveryStatus.CANCELLED: set(),
}


def validate_order_transition(order: DeliveryOrder, next_status: DeliveryStatus, *, actor_role: UserRole, admin_override: bool = False) -> None:
    current = order.status
    if current == next_status:
        return
    if actor_role == UserRole.ADMIN and admin_override:
        return
    if next_status not in VALID_STATUS_TRANSITIONS.get(current, set()):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Invalid order status transition: {enum_value(current)} -> {enum_value(next_status)}",
        )


def stamp_item_status(item: DeliveryOrderItem, status: DeliveryItemStatus) -> None:
    now = datetime.utcnow()
    if status == DeliveryItemStatus.PICKED_UP:
        item.picked_up_at = item.picked_up_at or now
    elif status == DeliveryItemStatus.IN_TRANSIT:
        item.picked_up_at = item.picked_up_at or now
    elif status == DeliveryItemStatus.DELIVERED:
        item.delivered_at = item.delivered_at or now
        item.delivered_quantity = item.delivered_quantity or item.quantity
    elif status in [DeliveryItemStatus.FAILED, DeliveryItemStatus.RETURNED]:
        item.failed_at = item.failed_at or now


def recompute_order_from_items(order: DeliveryOrder) -> None:
    items = list(order.items or [])
    if not items:
        return

    statuses = {enum_value(item.status) for item in items}
    now = datetime.utcnow()

    delivered_or_returned = {DeliveryItemStatus.DELIVERED.value, DeliveryItemStatus.FAILED.value, DeliveryItemStatus.RETURNED.value}
    delivered_count = sum(1 for item in items if enum_value(item.status) == DeliveryItemStatus.DELIVERED.value)

    if statuses.issubset({DeliveryItemStatus.DELIVERED.value}):
        order.status = DeliveryStatus.DELIVERED
        order.delivered_at = order.delivered_at or now
    elif statuses.issubset(delivered_or_returned) and delivered_count > 0:
        order.status = DeliveryStatus.PARTIALLY_DELIVERED
        order.delivered_at = order.delivered_at or now
    elif DeliveryItemStatus.FAILED.value in statuses or DeliveryItemStatus.RETURNED.value in statuses:
        order.status = DeliveryStatus.FAILED
        order.failed_at = order.failed_at or now
    elif DeliveryItemStatus.IN_TRANSIT.value in statuses:
        order.status = DeliveryStatus.IN_TRANSIT
    elif DeliveryItemStatus.PICKED_UP.value in statuses:
        order.status = DeliveryStatus.PICKED_UP
        order.picked_up_at = order.picked_up_at or now


def set_order_status_timestamps(order: DeliveryOrder, status: DeliveryStatus) -> None:
    now = datetime.utcnow()
    if status == DeliveryStatus.ASSIGNED:
        order.assigned_at = order.assigned_at or now
    elif status == DeliveryStatus.PICKED_UP:
        order.picked_up_at = order.picked_up_at or now
    elif status in [DeliveryStatus.DELIVERED, DeliveryStatus.PARTIALLY_DELIVERED]:
        order.delivered_at = order.delivered_at or now
    elif status in [DeliveryStatus.FAILED, DeliveryStatus.RETURNED]:
        order.failed_at = order.failed_at or now


def set_shipper_available_if_no_active_orders(db: Session, shipper_id: int | None) -> Shipper | None:
    if not shipper_id:
        return None

    active_count = (
        db.query(DeliveryOrder)
        .filter(
            DeliveryOrder.shipper_id == shipper_id,
            DeliveryOrder.status.in_(ACTIVE_ORDER_STATUSES),
        )
        .count()
    )
    shipper = db.get(Shipper, shipper_id)
    if shipper and active_count == 0 and shipper.status != ShipperStatus.SUSPENDED:
        shipper.status = ShipperStatus.AVAILABLE
        return shipper
    return None
