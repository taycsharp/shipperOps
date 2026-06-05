"""initial production schema

Revision ID: 20260604_0001
Revises: 
Create Date: 2026-06-04
"""
from alembic import op
import sqlalchemy as sa

revision = "20260604_0001"
down_revision = None
branch_labels = None
depends_on = None

userrole = sa.Enum("ADMIN", "DISPATCHER", "SHIPPER", name="userrole", create_type=False)
shipperstatus = sa.Enum("AVAILABLE", "BUSY", "OFFLINE", "SUSPENDED", name="shipperstatus", create_type=False)
deliverystatus = sa.Enum("PENDING", "ASSIGNED", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "FAILED", "CANCELLED", "RETURNED", "PARTIALLY_DELIVERED", name="deliverystatus", create_type=False)
deliveryitemstatus = sa.Enum("PENDING", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "FAILED", "RETURNED", name="deliveryitemstatus", create_type=False)
ordereventtype = sa.Enum("ORDER_CREATED", "ORDER_ASSIGNED", "ORDER_STATUS_CHANGED", "ITEM_STATUS_CHANGED", "DELIVERY_FAILED", "ORDER_RETURNED", "PROOF_UPLOADED", name="ordereventtype", create_type=False)
paymentmethod = sa.Enum("CASH", "BANK_TRANSFER", "WALLET", "OTHER", name="paymentmethod", create_type=False)
codsettlementstatus = sa.Enum("PENDING", "COLLECTED", "SETTLED", "DISCREPANCY", name="codsettlementstatus", create_type=False)


def upgrade() -> None:
    userrole.create(op.get_bind(), checkfirst=True)
    shipperstatus.create(op.get_bind(), checkfirst=True)
    deliverystatus.create(op.get_bind(), checkfirst=True)
    deliveryitemstatus.create(op.get_bind(), checkfirst=True)
    ordereventtype.create(op.get_bind(), checkfirst=True)
    paymentmethod.create(op.get_bind(), checkfirst=True)
    codsettlementstatus.create(op.get_bind(), checkfirst=True)

    op.create_table("users", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("name", sa.String(120), nullable=False), sa.Column("email", sa.String(160), nullable=False), sa.Column("phone", sa.String(40)), sa.Column("password_hash", sa.String(255), nullable=False), sa.Column("role", userrole, nullable=False), sa.Column("created_at", sa.DateTime()), sa.Column("updated_at", sa.DateTime()))
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_phone", "users", ["phone"], unique=True)

    op.create_table("shippers", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False), sa.Column("vehicle_type", sa.String(80)), sa.Column("vehicle_plate", sa.String(40)), sa.Column("status", shipperstatus, nullable=False), sa.Column("current_lat", sa.Float()), sa.Column("current_lng", sa.Float()), sa.Column("last_seen_at", sa.DateTime()), sa.Column("created_at", sa.DateTime()), sa.Column("updated_at", sa.DateTime()))
    op.create_index("ix_shippers_user_id", "shippers", ["user_id"], unique=True)
    op.create_index("ix_shippers_status", "shippers", ["status"])
    op.create_index("ix_shippers_vehicle_plate", "shippers", ["vehicle_plate"])

    op.create_table("delivery_orders", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("order_code", sa.String(40), nullable=False), sa.Column("customer_name", sa.String(120), nullable=False), sa.Column("customer_phone", sa.String(40), nullable=False), sa.Column("pickup_address", sa.Text(), nullable=False), sa.Column("pickup_lat", sa.Float()), sa.Column("pickup_lng", sa.Float()), sa.Column("delivery_address", sa.Text(), nullable=False), sa.Column("delivery_lat", sa.Float()), sa.Column("delivery_lng", sa.Float()), sa.Column("cod_amount", sa.Float()), sa.Column("delivery_fee", sa.Float()), sa.Column("status", deliverystatus, nullable=False), sa.Column("shipper_id", sa.Integer(), sa.ForeignKey("shippers.id")), sa.Column("proof_image_url", sa.String(500)), sa.Column("delivery_note", sa.Text()), sa.Column("receiver_name", sa.String(120)), sa.Column("failed_reason", sa.String(120)), sa.Column("cod_collected", sa.Boolean(), nullable=False, server_default=sa.false()), sa.Column("cod_collected_amount", sa.Float(), nullable=False, server_default="0"), sa.Column("payment_method", paymentmethod), sa.Column("cod_settlement_status", codsettlementstatus, nullable=False), sa.Column("assigned_at", sa.DateTime()), sa.Column("picked_up_at", sa.DateTime()), sa.Column("delivered_at", sa.DateTime()), sa.Column("failed_at", sa.DateTime()), sa.Column("created_at", sa.DateTime()), sa.Column("updated_at", sa.DateTime()))
    op.create_index("ix_delivery_orders_order_code", "delivery_orders", ["order_code"], unique=True)
    op.create_index("ix_delivery_orders_status", "delivery_orders", ["status"])
    op.create_index("ix_delivery_orders_status_shipper", "delivery_orders", ["status", "shipper_id"])
    op.create_index("ix_delivery_orders_shipper_id", "delivery_orders", ["shipper_id"])
    op.create_index("ix_delivery_orders_customer_phone", "delivery_orders", ["customer_phone"])

    op.create_table("delivery_order_items", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("order_id", sa.Integer(), sa.ForeignKey("delivery_orders.id", ondelete="CASCADE"), nullable=False), sa.Column("sku", sa.String(80)), sa.Column("name", sa.String(200), nullable=False), sa.Column("description", sa.Text()), sa.Column("quantity", sa.Integer(), nullable=False), sa.Column("delivered_quantity", sa.Integer(), nullable=False), sa.Column("unit_price", sa.Float(), nullable=False), sa.Column("weight_kg", sa.Float()), sa.Column("status", deliveryitemstatus, nullable=False), sa.Column("note", sa.Text()), sa.Column("picked_up_at", sa.DateTime()), sa.Column("delivered_at", sa.DateTime()), sa.Column("failed_at", sa.DateTime()), sa.Column("created_at", sa.DateTime()), sa.Column("updated_at", sa.DateTime()))
    op.create_index("ix_delivery_order_items_order_id", "delivery_order_items", ["order_id"])

    op.create_table("shipper_locations", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("shipper_id", sa.Integer(), sa.ForeignKey("shippers.id"), nullable=False), sa.Column("lat", sa.Float(), nullable=False), sa.Column("lng", sa.Float(), nullable=False), sa.Column("speed", sa.Float()), sa.Column("heading", sa.Float()), sa.Column("battery", sa.Integer()), sa.Column("created_at", sa.DateTime()))
    op.create_index("ix_shipper_locations_shipper_id", "shipper_locations", ["shipper_id"])
    op.create_index("ix_shipper_locations_created_at", "shipper_locations", ["created_at"])
    op.create_index("ix_shipper_locations_shipper_created", "shipper_locations", ["shipper_id", "created_at"])

    op.create_table("order_events", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("order_id", sa.Integer(), sa.ForeignKey("delivery_orders.id", ondelete="CASCADE"), nullable=False), sa.Column("actor_user_id", sa.Integer(), sa.ForeignKey("users.id")), sa.Column("event_type", ordereventtype, nullable=False), sa.Column("old_status", deliverystatus), sa.Column("new_status", deliverystatus), sa.Column("note", sa.Text()), sa.Column("event_metadata", sa.JSON()), sa.Column("created_at", sa.DateTime()))
    op.create_index("ix_order_events_order_id", "order_events", ["order_id"])
    op.create_index("ix_order_events_actor_user_id", "order_events", ["actor_user_id"])
    op.create_index("ix_order_events_created_at", "order_events", ["created_at"])


def downgrade() -> None:
    op.drop_table("order_events")
    op.drop_table("shipper_locations")
    op.drop_table("delivery_order_items")
    op.drop_table("delivery_orders")
    op.drop_table("shippers")
    op.drop_table("users")
    for enum in [codsettlementstatus, paymentmethod, ordereventtype, deliveryitemstatus, deliverystatus, shipperstatus, userrole]:
        enum.drop(op.get_bind(), checkfirst=True)
