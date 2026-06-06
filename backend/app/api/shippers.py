from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.db.session import get_db
from app.models.enums import ShipperStatus, UserRole
from app.models.order import DeliveryOrder
from app.models.shipper import Shipper
from app.models.user import User
from app.schemas.shipper import ShipperCreate, ShipperLinkAccount, ShipperRead, ShipperStatusUpdate, ShipperUpdate
from app.services.order_workflow import ACTIVE_ORDER_STATUSES
from app.services.security import get_current_user, hash_password, require_admin_or_dispatcher
from app.services.serializers import serialize_shipper_status
from app.services.websocket_manager import manager

router = APIRouter(prefix="/shippers", tags=["shippers"])


def shipper_query(db: Session):
    return db.query(Shipper).options(joinedload(Shipper.user))


def get_managed_shipper_or_404(shipper_id: int, db: Session) -> Shipper:
    shipper = shipper_query(db).filter(Shipper.id == shipper_id).first()
    if not shipper:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipper not found")
    return shipper


@router.get("/me", response_model=ShipperRead)
def get_my_shipper_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.SHIPPER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only shipper users can access this profile",
        )

    shipper = shipper_query(db).filter(Shipper.user_id == current_user.id).first()
    if not shipper:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Shipper profile not found",
        )

    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))


def active_order_counts(db: Session, shipper_ids: list[int]) -> dict[int, int]:
    if not shipper_ids:
        return {}
    rows = (
        db.query(DeliveryOrder.shipper_id, func.count(DeliveryOrder.id))
        .filter(DeliveryOrder.shipper_id.in_(shipper_ids), DeliveryOrder.status.in_(ACTIVE_ORDER_STATUSES))
        .group_by(DeliveryOrder.shipper_id)
        .all()
    )
    return {shipper_id: count for shipper_id, count in rows if shipper_id is not None}


def enrich_shipper(shipper: Shipper, active_count: int = 0) -> Shipper:
    shipper.active_order_count = active_count
    shipper.is_online = shipper.status in {ShipperStatus.AVAILABLE, ShipperStatus.BUSY}
    shipper.last_gps_update_at = shipper.last_seen_at
    return shipper


def assert_shipper_login_user(db: Session, user_id: int, current_shipper_id: int | None = None) -> User:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Login account not found")
    if user.role != UserRole.SHIPPER:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Shipper profiles can only link to SHIPPER login accounts")
    existing = db.query(Shipper).filter(Shipper.user_id == user_id).first()
    if existing and existing.id != current_shipper_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Login account is already linked to another shipper")
    return user


def create_login_user(payload: ShipperCreate, db: Session) -> User:
    if not payload.user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Provide user_id or user details for the shipper login account")
    if db.query(User).filter(User.email == payload.user.email).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already exists")
    if payload.user.phone and db.query(User).filter(User.phone == payload.user.phone).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone already exists")
    user = User(
        name=payload.user.name,
        email=payload.user.email,
        phone=payload.user.phone,
        password_hash=hash_password(payload.user.password),
        role=UserRole.SHIPPER,
    )
    db.add(user)
    db.flush()
    return user


@router.get("", response_model=list[ShipperRead])
def list_shippers(
    status_filter: ShipperStatus | None = Query(default=None, alias="status"),
    search: str | None = None,
    active: bool | None = None,
    online: bool | None = None,
    live_only: bool = False,
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin_or_dispatcher),
):
    query = shipper_query(db)
    if status_filter:
        query = query.filter(Shipper.status == status_filter)
    if active is not None:
        query = query.filter(Shipper.status != ShipperStatus.SUSPENDED if active else Shipper.status == ShipperStatus.SUSPENDED)
    if online is not None:
        online_statuses = [ShipperStatus.AVAILABLE, ShipperStatus.BUSY]
        query = query.filter(Shipper.status.in_(online_statuses) if online else Shipper.status.notin_(online_statuses))
    if search:
        like = f"%{search.strip()}%"
        query = query.join(Shipper.user).filter(
            or_(User.name.ilike(like), User.email.ilike(like), User.phone.ilike(like), Shipper.vehicle_plate.ilike(like), Shipper.vehicle_type.ilike(like))
        )
    if live_only:
        stale_after = datetime.utcnow() - timedelta(minutes=5)
        query = query.filter(Shipper.current_lat.isnot(None), Shipper.current_lng.isnot(None), Shipper.last_seen_at >= stale_after)
    shippers = query.order_by(Shipper.id.asc()).offset(offset).limit(limit).all()
    counts = active_order_counts(db, [shipper.id for shipper in shippers])
    return [enrich_shipper(shipper, counts.get(shipper.id, 0)) for shipper in shippers]


@router.post("", response_model=ShipperRead, status_code=status.HTTP_201_CREATED)
def create_shipper(payload: ShipperCreate, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    user = assert_shipper_login_user(db, payload.user_id) if payload.user_id else create_login_user(payload, db)
    shipper = Shipper(
        user_id=user.id,
        vehicle_type=payload.vehicle_type,
        vehicle_plate=payload.vehicle_plate,
        status=payload.status,
    )
    db.add(shipper)
    db.commit()
    db.refresh(shipper)
    return enrich_shipper(shipper)


@router.get("/{shipper_id}", response_model=ShipperRead)
def get_shipper(shipper_id: int, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))


@router.put("/{shipper_id}", response_model=ShipperRead)
def update_shipper(shipper_id: int, payload: ShipperUpdate, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    data = payload.model_dump(exclude_unset=True)
    if "user_id" in data and data["user_id"] != shipper.user_id:
        assert_shipper_login_user(db, data["user_id"], current_shipper_id=shipper.id)
        shipper.user_id = data["user_id"]
    for field in ["vehicle_type", "vehicle_plate", "status"]:
        if field in data:
            setattr(shipper, field, data[field])
    if payload.user:
        if payload.user.email != shipper.user.email and db.query(User).filter(User.email == payload.user.email).first():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already exists")
        if payload.user.phone and payload.user.phone != shipper.user.phone and db.query(User).filter(User.phone == payload.user.phone).first():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone already exists")
        shipper.user.name = payload.user.name
        shipper.user.email = payload.user.email
        shipper.user.phone = payload.user.phone
    db.commit()
    db.refresh(shipper)
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))


@router.delete("/{shipper_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_shipper(shipper_id: int, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    active_count = active_order_counts(db, [shipper.id]).get(shipper.id, 0)
    if active_count:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cannot delete shipper with active orders")
    db.delete(shipper)
    db.commit()
    return None


@router.post("/{shipper_id}/activate", response_model=ShipperRead)
async def activate_shipper(shipper_id: int, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    if shipper.status == ShipperStatus.SUSPENDED:
        shipper.status = ShipperStatus.OFFLINE
    db.commit()
    db.refresh(shipper)
    await manager.broadcast(serialize_shipper_status(shipper))
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))


@router.post("/{shipper_id}/deactivate", response_model=ShipperRead)
async def deactivate_shipper(shipper_id: int, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    shipper.status = ShipperStatus.SUSPENDED
    db.commit()
    db.refresh(shipper)
    await manager.broadcast(serialize_shipper_status(shipper))
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))


@router.post("/{shipper_id}/link-account", response_model=ShipperRead)
def link_shipper_account(shipper_id: int, payload: ShipperLinkAccount, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    assert_shipper_login_user(db, payload.user_id, current_shipper_id=shipper.id)
    shipper.user_id = payload.user_id
    db.commit()
    db.refresh(shipper)
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))



@router.post("/me/status", response_model=ShipperRead)
async def update_my_shipper_status(
    payload: ShipperStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.SHIPPER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only shipper users can update their own status",
        )

    shipper = shipper_query(db).filter(Shipper.user_id == current_user.id).first()
    if not shipper:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Shipper profile not found",
        )

    shipper.status = payload.status
    shipper.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(shipper)

    await manager.broadcast(serialize_shipper_status(shipper))
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))


@router.post("/{shipper_id}/status", response_model=ShipperRead)
async def update_shipper_status(shipper_id: int, payload: ShipperStatusUpdate, db: Session = Depends(get_db), _: User = Depends(require_admin_or_dispatcher)):
    shipper = get_managed_shipper_or_404(shipper_id, db)
    shipper.status = payload.status
    shipper.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(shipper)

    await manager.broadcast(serialize_shipper_status(shipper))
    return enrich_shipper(shipper, active_order_counts(db, [shipper.id]).get(shipper.id, 0))
