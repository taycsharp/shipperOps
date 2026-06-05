from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.db.session import get_db
from app.models.enums import ShipperStatus, UserRole
from app.models.shipper import Shipper
from app.models.user import User
from app.schemas.shipper import ShipperCreate, ShipperRead, ShipperStatusUpdate
from app.services.security import ensure_shipper_scope, get_current_user, require_admin_or_dispatcher
from app.services.serializers import serialize_shipper_status
from app.services.websocket_manager import manager

router = APIRouter(prefix="/shippers", tags=["shippers"])


@router.get("", response_model=list[ShipperRead])
def list_shippers(
    status: ShipperStatus | None = None,
    search: str | None = None,
    live_only: bool = False,
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Shipper).options(joinedload(Shipper.user))
    if current_user.role == UserRole.SHIPPER:
        query = query.filter(Shipper.user_id == current_user.id)
    if status:
        query = query.filter(Shipper.status == status)
    if search:
        like = f"%{search}%"
        query = query.join(Shipper.user).filter(or_(User.name.ilike(like), User.phone.ilike(like), Shipper.vehicle_plate.ilike(like)))
    if live_only:
        stale_after = datetime.utcnow() - timedelta(minutes=5)
        query = query.filter(Shipper.current_lat.isnot(None), Shipper.current_lng.isnot(None), Shipper.last_seen_at >= stale_after)
    return query.order_by(Shipper.id.asc()).offset(offset).limit(limit).all()


@router.post("", response_model=ShipperRead)
def create_shipper(payload: ShipperCreate, db: Session = Depends(get_db), current_user: User = Depends(require_admin_or_dispatcher)):
    existing = db.query(Shipper).filter(Shipper.user_id == payload.user_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="User already has shipper profile")
    shipper = Shipper(**payload.model_dump())
    db.add(shipper)
    db.commit()
    db.refresh(shipper)
    return shipper


@router.get("/{shipper_id}", response_model=ShipperRead)
def get_shipper(shipper_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return ensure_shipper_scope(shipper_id, current_user, db)


@router.post("/{shipper_id}/status", response_model=ShipperRead)
async def update_shipper_status(shipper_id: int, payload: ShipperStatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    shipper = ensure_shipper_scope(shipper_id, current_user, db)
    if current_user.role == UserRole.SHIPPER and payload.status == ShipperStatus.SUSPENDED:
        raise HTTPException(status_code=403, detail="Only admin/dispatcher can suspend a shipper")

    shipper.status = payload.status
    shipper.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(shipper)

    await manager.broadcast(serialize_shipper_status(shipper))
    return shipper
