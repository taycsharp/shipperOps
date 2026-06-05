from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session, joinedload

from app.db.session import SessionLocal, get_db
from app.models.enums import ShipperStatus, UserRole
from app.models.location import ShipperLocation
from app.models.shipper import Shipper
from app.models.user import User
from app.schemas.location import LocationRead, LocationUpdate
from app.services.security import ensure_shipper_scope, get_current_user, require_admin_or_dispatcher, user_from_ws_token
from app.services.serializers import serialize_shipper_live
from app.services.websocket_manager import manager

router = APIRouter(tags=["locations"])


@router.post("/locations/update", response_model=LocationRead)
async def update_location(payload: LocationUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    shipper = ensure_shipper_scope(payload.shipper_id, current_user, db)
    if shipper.status == ShipperStatus.SUSPENDED:
        raise HTTPException(status_code=403, detail="Suspended shipper cannot update location")

    location = ShipperLocation(**payload.model_dump())
    shipper.current_lat = payload.lat
    shipper.current_lng = payload.lng
    shipper.last_seen_at = datetime.utcnow()
    if shipper.status == ShipperStatus.OFFLINE:
        shipper.status = ShipperStatus.AVAILABLE

    db.add(location)
    db.commit()
    db.refresh(location)

    await manager.broadcast({
        "type": "shipper_location",
        **serialize_shipper_live(shipper),
        "speed": payload.speed,
        "heading": payload.heading,
        "battery": payload.battery,
        "timestamp": location.created_at.isoformat(),
    })
    return location


@router.get("/locations/live")
def live_locations(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    query = db.query(Shipper).options(joinedload(Shipper.user))
    if current_user.role == UserRole.SHIPPER:
        shipper = db.query(Shipper).filter(Shipper.user_id == current_user.id).first()
        query = query.filter(Shipper.id == shipper.id if shipper else -1)
    return [serialize_shipper_live(shipper) for shipper in query.all() if shipper.current_lat is not None and shipper.current_lng is not None]


@router.websocket("/ws/locations")
async def websocket_locations(websocket: WebSocket):
    db = SessionLocal()
    try:
        user_from_ws_token(websocket, db)
        await manager.connect(websocket)
        while True:
            await websocket.receive_text()
    except Exception:
        await websocket.close(code=1008)
    finally:
        manager.disconnect(websocket)
        db.close()
