"""Production smoke-test targets for the upgraded Shipper API.

Run with a test database configured in DATABASE_URL:
    ENVIRONMENT=test CREATE_ALL_ON_STARTUP=true pytest
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


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
