from app.models.order import DeliveryOrder
from app.models.order_item import DeliveryOrderItem
from app.models.shipper import Shipper


def enum_value(value):
    return value.value if hasattr(value, "value") else value


def serialize_item(item: DeliveryOrderItem) -> dict:
    return {
        "id": item.id,
        "order_id": item.order_id,
        "sku": item.sku,
        "name": item.name,
        "description": item.description,
        "quantity": item.quantity,
        "delivered_quantity": item.delivered_quantity,
        "unit_price": item.unit_price,
        "weight_kg": item.weight_kg,
        "status": enum_value(item.status),
        "note": item.note,
    }


def serialize_order(order: DeliveryOrder) -> dict:
    return {
        "id": order.id,
        "order_code": order.order_code,
        "customer_name": order.customer_name,
        "customer_phone": order.customer_phone,
        "pickup_address": order.pickup_address,
        "pickup_lat": order.pickup_lat,
        "pickup_lng": order.pickup_lng,
        "delivery_address": order.delivery_address,
        "delivery_lat": order.delivery_lat,
        "delivery_lng": order.delivery_lng,
        "cod_amount": order.cod_amount,
        "delivery_fee": order.delivery_fee,
        "status": enum_value(order.status),
        "shipper_id": order.shipper_id,
        "delivery_note": order.delivery_note,
        "proof_image_url": order.proof_image_url,
        "receiver_name": order.receiver_name,
        "failed_reason": order.failed_reason,
        "cod_collected": order.cod_collected,
        "cod_collected_amount": order.cod_collected_amount,
        "payment_method": enum_value(order.payment_method) if order.payment_method else None,
        "cod_settlement_status": enum_value(order.cod_settlement_status),
        "items": [serialize_item(item) for item in getattr(order, "items", [])],
    }


def serialize_shipper_live(shipper: Shipper) -> dict:
    return {
        "shipper_id": shipper.id,
        "user_id": shipper.user_id,
        "name": shipper.user.name if getattr(shipper, "user", None) else f"Shipper #{shipper.id}",
        "phone": shipper.user.phone if getattr(shipper, "user", None) else None,
        "vehicle_type": shipper.vehicle_type,
        "vehicle_plate": shipper.vehicle_plate,
        "status": enum_value(shipper.status),
        "lat": shipper.current_lat,
        "lng": shipper.current_lng,
        "last_seen_at": shipper.last_seen_at.isoformat() if shipper.last_seen_at else None,
    }


def serialize_shipper_status(shipper: Shipper) -> dict:
    return {
        "type": "shipper_status",
        **serialize_shipper_live(shipper),
    }
