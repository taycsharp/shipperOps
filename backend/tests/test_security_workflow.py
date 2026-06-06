"""Production smoke-test targets for the upgraded Shipper API.

Run with a test database configured in DATABASE_URL:
    ENVIRONMENT=test CREATE_ALL_ON_STARTUP=true pytest
"""
from uuid import uuid4

from fastapi.testclient import TestClient

from app.db.session import SessionLocal
from app.main import app
from app.models.enums import UserRole
from app.models.user import User
from app.services.security import create_access_token, hash_password

client = TestClient(app)


def create_admin_headers() -> dict[str, str]:
    email = f"admin-{uuid4().hex}@example.com"
    db = SessionLocal()
    try:
        admin = User(
            name="Test Admin",
            email=email,
            phone=None,
            password_hash=hash_password("AdminPass123"),
            role=UserRole.ADMIN,
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)
        token = create_access_token(str(admin.id), admin.role.value)
        return {"Authorization": f"Bearer {token}"}
    finally:
        db.close()


def test_health_is_public():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_orders_require_authentication():
    res = client.get("/orders")
    assert res.status_code in (401, 403)


def test_live_locations_require_authentication():
    res = client.get("/locations/live")
    assert res.status_code in (401, 403)


def test_admin_can_create_shipper_with_login_account():
    email = f"shipper-{uuid4().hex}@example.com"
    payload = {
        "user": {
            "name": "Test Shipper",
            "email": email,
            "phone": "+15551234567",
            "password": "ShipperPass123",
        },
        "vehicle_type": "Motorbike",
        "vehicle_plate": "TEST-123",
        "status": "OFFLINE",
    }

    res = client.post("/shippers", json=payload, headers=create_admin_headers())

    assert res.status_code == 201, res.text
    data = res.json()
    assert data["user"]["name"] == payload["user"]["name"]
    assert data["user"]["email"] == email
    assert data["user"]["role"] == "SHIPPER"
    assert data["vehicle_type"] == "Motorbike"
    assert data["vehicle_plate"] == "TEST-123"
    assert data["status"] == "OFFLINE"
    assert data["active_order_count"] == 0
    assert data["is_online"] is False
