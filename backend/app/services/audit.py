from typing import Any

from sqlalchemy.orm import Session

from app.models.enums import DeliveryStatus, OrderEventType
from app.models.order_event import OrderEvent


def log_order_event(
    db: Session,
    *,
    order_id: int,
    actor_user_id: int | None,
    event_type: OrderEventType,
    old_status: DeliveryStatus | None = None,
    new_status: DeliveryStatus | None = None,
    note: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> OrderEvent:
    event = OrderEvent(
        order_id=order_id,
        actor_user_id=actor_user_id,
        event_type=event_type,
        old_status=old_status,
        new_status=new_status,
        note=note,
        event_metadata=metadata,
    )
    db.add(event)
    return event
