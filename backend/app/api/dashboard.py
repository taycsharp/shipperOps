from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.enums import DeliveryItemStatus, DeliveryStatus, ShipperStatus
from app.models.order import DeliveryOrder
from app.models.order_item import DeliveryOrderItem
from app.models.shipper import Shipper
from app.models.user import User
from app.services.security import require_admin_or_dispatcher

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/summary")
def summary(db: Session = Depends(get_db), current_user: User = Depends(require_admin_or_dispatcher)):
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    stale_after = datetime.utcnow() - timedelta(minutes=5)
    active_order_statuses = [DeliveryStatus.ASSIGNED, DeliveryStatus.PICKED_UP, DeliveryStatus.IN_TRANSIT, DeliveryStatus.PARTIALLY_DELIVERED]
    return {
        "orders": db.query(DeliveryOrder).count(),
        "today_orders": db.query(DeliveryOrder).filter(DeliveryOrder.created_at >= today_start).count(),
        "active_orders": db.query(DeliveryOrder).filter(DeliveryOrder.status.in_(active_order_statuses)).count(),
        "pending_assignment": db.query(DeliveryOrder).filter(DeliveryOrder.status == DeliveryStatus.PENDING, DeliveryOrder.shipper_id.is_(None)).count(),
        "delivered_orders": db.query(DeliveryOrder).filter(DeliveryOrder.status == DeliveryStatus.DELIVERED).count(),
        "delivered_today": db.query(DeliveryOrder).filter(DeliveryOrder.status == DeliveryStatus.DELIVERED, DeliveryOrder.delivered_at >= today_start).count(),
        "failed_today": db.query(DeliveryOrder).filter(DeliveryOrder.status == DeliveryStatus.FAILED, DeliveryOrder.failed_at >= today_start).count(),
        "cod_to_collect": sum(row.cod_amount or 0 for row in db.query(DeliveryOrder).filter(DeliveryOrder.cod_collected.is_(False)).all()),
        "cod_collected": sum(row.cod_collected_amount or 0 for row in db.query(DeliveryOrder).filter(DeliveryOrder.cod_collected.is_(True)).all()),
        "items": db.query(DeliveryOrderItem).count(),
        "delivered_items": db.query(DeliveryOrderItem).filter(DeliveryOrderItem.status == DeliveryItemStatus.DELIVERED).count(),
        "failed_items": db.query(DeliveryOrderItem).filter(DeliveryOrderItem.status == DeliveryItemStatus.FAILED).count(),
        "shippers": db.query(Shipper).count(),
        "live_shippers": db.query(Shipper).filter(Shipper.current_lat.isnot(None)).count(),
        "online_shippers": db.query(Shipper).filter(Shipper.status.in_([ShipperStatus.AVAILABLE, ShipperStatus.BUSY])).count(),
        "stale_gps_shippers": db.query(Shipper).filter(Shipper.last_seen_at.isnot(None), Shipper.last_seen_at < stale_after).count(),
        "available_shippers": db.query(Shipper).filter(Shipper.status == ShipperStatus.AVAILABLE).count(),
        "busy_shippers": db.query(Shipper).filter(Shipper.status == ShipperStatus.BUSY).count(),
    }
