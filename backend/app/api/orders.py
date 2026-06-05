from datetime import datetime
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.db.session import get_db
from app.models.enums import CodSettlementStatus, DeliveryItemStatus, DeliveryStatus, OrderEventType, ShipperStatus, UserRole
from app.models.order import DeliveryOrder
from app.models.order_event import OrderEvent
from app.models.order_item import DeliveryOrderItem
from app.models.shipper import Shipper
from app.models.user import User
from app.schemas.order import (
    AssignOrderRequest,
    DeliveryOrderCreate,
    DeliveryOrderItemCreate,
    DeliveryOrderItemRead,
    DeliveryOrderItemStatusUpdate,
    DeliveryOrderRead,
    OrderEventRead,
    PaginatedOrders,
    ProofUploadResponse,
    UpdateOrderStatusRequest,
)
from app.services.audit import log_order_event
from app.services.order_workflow import (
    ACTIVE_ORDER_STATUSES,
    FINAL_ORDER_STATUSES,
    recompute_order_from_items,
    set_order_status_timestamps,
    set_shipper_available_if_no_active_orders,
    stamp_item_status,
    validate_order_transition,
)
from app.services.security import ensure_shipper_scope, get_current_user, require_admin_or_dispatcher
from app.services.serializers import serialize_item, serialize_order, serialize_shipper_status
from app.services.websocket_manager import manager

router = APIRouter(prefix="/orders", tags=["orders"])


def order_query(db: Session):
    return db.query(DeliveryOrder).options(selectinload(DeliveryOrder.items))


def scoped_order_query(db: Session, current_user: User):
    query = order_query(db)
    if current_user.role == UserRole.SHIPPER:
        shipper = db.query(Shipper).filter(Shipper.user_id == current_user.id).first()
        if not shipper:
            return query.filter(False)
        query = query.filter(DeliveryOrder.shipper_id == shipper.id)
    return query


def get_order_or_404(db: Session, order_id: int, current_user: User) -> DeliveryOrder:
    order = scoped_order_query(db, current_user).filter(DeliveryOrder.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.get("", response_model=PaginatedOrders)
def list_orders(
    status_filter: DeliveryStatus | None = Query(default=None, alias="status"),
    shipper_id: int | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    customer_name: str | None = None,
    customer_phone: str | None = None,
    order_code: str | None = None,
    unassigned_only: bool = False,
    active_only: bool = False,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = scoped_order_query(db, current_user)
    if status_filter:
        query = query.filter(DeliveryOrder.status == status_filter)
    if shipper_id is not None:
        if current_user.role == UserRole.SHIPPER:
            ensure_shipper_scope(shipper_id, current_user, db)
        query = query.filter(DeliveryOrder.shipper_id == shipper_id)
    if date_from:
        query = query.filter(DeliveryOrder.created_at >= date_from)
    if date_to:
        query = query.filter(DeliveryOrder.created_at <= date_to)
    if customer_name:
        query = query.filter(DeliveryOrder.customer_name.ilike(f"%{customer_name}%"))
    if customer_phone:
        query = query.filter(DeliveryOrder.customer_phone.ilike(f"%{customer_phone}%"))
    if order_code:
        query = query.filter(DeliveryOrder.order_code.ilike(f"%{order_code}%"))
    if unassigned_only:
        query = query.filter(DeliveryOrder.shipper_id.is_(None))
    if active_only:
        query = query.filter(DeliveryOrder.status.in_(ACTIVE_ORDER_STATUSES))

    total = query.count()
    items = query.order_by(DeliveryOrder.id.desc()).offset(offset).limit(limit).all()
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.post("", response_model=DeliveryOrderRead)
async def create_order(
    payload: DeliveryOrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_dispatcher),
):
    data = payload.model_dump()
    items_data = data.pop("items", [])
    if db.query(DeliveryOrder).filter(DeliveryOrder.order_code == payload.order_code).first():
        raise HTTPException(status_code=400, detail="Order code already exists")

    order = DeliveryOrder(**data)
    db.add(order)
    db.flush()

    for item_data in items_data:
        db.add(DeliveryOrderItem(order_id=order.id, **item_data))

    log_order_event(db, order_id=order.id, actor_user_id=current_user.id, event_type=OrderEventType.ORDER_CREATED, new_status=order.status)
    db.commit()
    order = order_query(db).filter(DeliveryOrder.id == order.id).first()
    await manager.broadcast({"type": "order_created", "order": serialize_order(order)})
    return order


@router.get("/shipper/{shipper_id}", response_model=list[DeliveryOrderRead])
def list_shipper_orders(shipper_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    ensure_shipper_scope(shipper_id, current_user, db)
    return (
        order_query(db)
        .filter(DeliveryOrder.shipper_id == shipper_id)
        .order_by(DeliveryOrder.id.desc())
        .all()
    )


@router.get("/{order_id}", response_model=DeliveryOrderRead)
def get_order(order_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return get_order_or_404(db, order_id, current_user)


@router.post("/{order_id}/assign", response_model=DeliveryOrderRead)
async def assign_order(
    order_id: int,
    payload: AssignOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_dispatcher),
):
    order = db.get(DeliveryOrder, order_id)
    shipper = db.get(Shipper, payload.shipper_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if not shipper:
        raise HTTPException(status_code=404, detail="Shipper not found")
    if shipper.status in {ShipperStatus.SUSPENDED, ShipperStatus.OFFLINE} and not payload.force:
        raise HTTPException(status_code=409, detail="Shipper is offline or suspended. Use force=true only after admin confirmation.")

    old_status = order.status
    validate_order_transition(order, DeliveryStatus.ASSIGNED, actor_role=current_user.role, admin_override=True)
    order.shipper_id = shipper.id
    order.status = DeliveryStatus.ASSIGNED
    order.assigned_at = datetime.utcnow()
    if shipper.status != ShipperStatus.SUSPENDED:
        shipper.status = ShipperStatus.BUSY
    log_order_event(
        db,
        order_id=order.id,
        actor_user_id=current_user.id,
        event_type=OrderEventType.ORDER_ASSIGNED,
        old_status=old_status,
        new_status=order.status,
        metadata={"shipper_id": shipper.id},
    )
    db.commit()

    order = order_query(db).filter(DeliveryOrder.id == order_id).first()
    await manager.broadcast({"type": "order_assigned", "order": serialize_order(order), "shipper_id": shipper.id, "shipper_status": shipper.status.value})
    await manager.broadcast(serialize_shipper_status(shipper))
    return order


@router.post("/{order_id}/status", response_model=DeliveryOrderRead)
async def update_order_status(
    order_id: int,
    payload: UpdateOrderStatusRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = get_order_or_404(db, order_id, current_user)
    old_status = order.status
    validate_order_transition(order, payload.status, actor_role=current_user.role, admin_override=payload.admin_override)

    order.status = payload.status
    order.delivery_note = payload.delivery_note or order.delivery_note
    order.failed_reason = payload.failed_reason or order.failed_reason
    order.receiver_name = payload.receiver_name or order.receiver_name
    if payload.cod_collected is not None:
        order.cod_collected = payload.cod_collected
        order.cod_settlement_status = CodSettlementStatus.COLLECTED if payload.cod_collected else CodSettlementStatus.PENDING
    if payload.cod_collected_amount is not None:
        order.cod_collected_amount = payload.cod_collected_amount
    if payload.payment_method:
        order.payment_method = payload.payment_method
    set_order_status_timestamps(order, payload.status)

    if payload.status == DeliveryStatus.DELIVERED:
        for item in order.items:
            if item.status not in [DeliveryItemStatus.DELIVERED, DeliveryItemStatus.FAILED, DeliveryItemStatus.RETURNED]:
                item.status = DeliveryItemStatus.DELIVERED
                item.delivered_quantity = item.quantity
                stamp_item_status(item, DeliveryItemStatus.DELIVERED)

    changed_shipper = None
    if order.shipper_id and payload.status in FINAL_ORDER_STATUSES:
        changed_shipper = set_shipper_available_if_no_active_orders(db, order.shipper_id)

    log_order_event(
        db,
        order_id=order.id,
        actor_user_id=current_user.id,
        event_type=OrderEventType.ORDER_STATUS_CHANGED,
        old_status=old_status,
        new_status=payload.status,
        note=payload.delivery_note or payload.failed_reason,
    )
    db.commit()
    order = order_query(db).filter(DeliveryOrder.id == order_id).first()
    await manager.broadcast({"type": "order_status", "order": serialize_order(order)})
    if changed_shipper:
        await manager.broadcast(serialize_shipper_status(changed_shipper))
    return order


@router.get("/{order_id}/timeline", response_model=list[OrderEventRead])
def order_timeline(order_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    get_order_or_404(db, order_id, current_user)
    return db.query(OrderEvent).filter(OrderEvent.order_id == order_id).order_by(OrderEvent.created_at.desc()).all()


@router.post("/{order_id}/proof", response_model=ProofUploadResponse)
async def upload_delivery_proof(
    order_id: int,
    file: UploadFile = File(...),
    receiver_name: str | None = Form(default=None),
    delivery_note: str | None = Form(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = get_order_or_404(db, order_id, current_user)
    if file.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, or WEBP proof images are allowed")

    contents = await file.read()
    if len(contents) > settings.upload_max_file_mb * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"Proof image must be <= {settings.upload_max_file_mb} MB")

    upload_dir = Path(settings.upload_folder) / "proofs"
    upload_dir.mkdir(parents=True, exist_ok=True)
    suffix = Path(file.filename or "proof.jpg").suffix.lower() or ".jpg"
    filename = f"order-{order.id}-{uuid4().hex}{suffix}"
    target = upload_dir / filename
    target.write_bytes(contents)

    order.proof_image_url = f"/uploads/proofs/{filename}"
    order.receiver_name = receiver_name or order.receiver_name
    order.delivery_note = delivery_note or order.delivery_note
    order.delivered_at = order.delivered_at or datetime.utcnow()
    log_order_event(db, order_id=order.id, actor_user_id=current_user.id, event_type=OrderEventType.PROOF_UPLOADED, note=delivery_note, metadata={"proof_image_url": order.proof_image_url})
    db.commit()
    await manager.broadcast({"type": "proof_uploaded", "order": serialize_order(order)})
    return {"proof_image_url": order.proof_image_url, "order_id": order.id}


@router.get("/{order_id}/items", response_model=list[DeliveryOrderItemRead])
def list_order_items(order_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    get_order_or_404(db, order_id, current_user)
    return db.query(DeliveryOrderItem).filter(DeliveryOrderItem.order_id == order_id).order_by(DeliveryOrderItem.id.asc()).all()


@router.post("/{order_id}/items", response_model=DeliveryOrderItemRead)
async def create_order_item(order_id: int, payload: DeliveryOrderItemCreate, db: Session = Depends(get_db), current_user: User = Depends(require_admin_or_dispatcher)):
    order = db.get(DeliveryOrder, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    item = DeliveryOrderItem(order_id=order.id, **payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    await manager.broadcast({"type": "order_item_created", "order_id": order.id, "item": serialize_item(item)})
    return item


@router.post("/{order_id}/items/{item_id}/status", response_model=DeliveryOrderItemRead)
async def update_order_item_status(order_id: int, item_id: int, payload: DeliveryOrderItemStatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    order = get_order_or_404(db, order_id, current_user)
    item = next((candidate for candidate in order.items if candidate.id == item_id), None)
    if not item:
        raise HTTPException(status_code=404, detail="Order item not found")

    old_status = order.status
    item.status = payload.status
    item.note = payload.note
    if payload.delivered_quantity is not None:
        item.delivered_quantity = max(0, min(payload.delivered_quantity, item.quantity))
    elif payload.status == DeliveryItemStatus.DELIVERED:
        item.delivered_quantity = item.quantity

    stamp_item_status(item, payload.status)
    recompute_order_from_items(order)

    changed_shipper = None
    if order.status in FINAL_ORDER_STATUSES:
        changed_shipper = set_shipper_available_if_no_active_orders(db, order.shipper_id)

    log_order_event(
        db,
        order_id=order.id,
        actor_user_id=current_user.id,
        event_type=OrderEventType.ITEM_STATUS_CHANGED,
        old_status=old_status,
        new_status=order.status,
        note=payload.note,
        metadata={"item_id": item.id, "item_status": payload.status.value},
    )
    db.commit()
    db.refresh(item)
    order = order_query(db).filter(DeliveryOrder.id == order_id).first()

    await manager.broadcast({"type": "order_item_status", "order_id": order.id, "order": serialize_order(order), "item": serialize_item(item), "shipper_id": order.shipper_id})
    await manager.broadcast({"type": "order_status", "order": serialize_order(order)})
    if changed_shipper:
        await manager.broadcast(serialize_shipper_status(changed_shipper))
    return item
