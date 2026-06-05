from collections.abc import Callable
from datetime import datetime, timedelta, timezone

import bcrypt
from fastapi import Depends, HTTPException, Query, WebSocket, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.shipper import Shipper
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def hash_password(password: str) -> str:
    password_bytes = password.encode("utf-8")
    if len(password_bytes) > 72:
        raise ValueError("Password is too long. Please use 72 bytes or fewer.")
    return bcrypt.hashpw(password_bytes, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(subject: str, role: str) -> str:
    expires = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {"sub": subject, "role": role, "exp": expires}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    payload = decode_token(token)
    try:
        user_id = int(payload.get("sub"))
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject") from exc

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


def require_roles(*roles: UserRole) -> Callable[[User], User]:
    allowed = set(roles)

    def dependency(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
        return current_user

    return dependency


def require_admin_or_dispatcher(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role not in {UserRole.ADMIN, UserRole.DISPATCHER}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin or dispatcher access required")
    return current_user


def get_current_shipper(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Shipper:
    shipper = (
        db.query(Shipper)
        .options(joinedload(Shipper.user))
        .filter(Shipper.user_id == current_user.id)
        .first()
    )
    if not shipper:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Current user has no shipper profile")
    return shipper


def ensure_shipper_scope(target_shipper_id: int, current_user: User, db: Session) -> Shipper:
    shipper = db.query(Shipper).options(joinedload(Shipper.user)).filter(Shipper.id == target_shipper_id).first()
    if not shipper:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipper not found")
    if current_user.role == UserRole.SHIPPER and shipper.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot access another shipper")
    return shipper


def user_from_ws_token(websocket: WebSocket, db: Session) -> User:
    token = websocket.query_params.get("token")
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing websocket token")
    payload = decode_token(token)
    user = db.get(User, int(payload.get("sub")))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
