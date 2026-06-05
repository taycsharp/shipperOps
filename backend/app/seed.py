from app.db.session import Base, engine, SessionLocal
from app.models import User, Shipper, DeliveryOrder, DeliveryOrderItem
from app.models.enums import UserRole, ShipperStatus, DeliveryStatus, DeliveryItemStatus
from app.services.security import hash_password

Base.metadata.create_all(bind=engine)

SHIPPER_DEMOS = [
    {
        "name": "Shipper One",
        "email": "shipper1@example.com",
        "phone": "0911111111",
        "plate": "59-A1 12345",
        "status": ShipperStatus.AVAILABLE,
        "lat": 10.69971,
        "lng": 106.73121,
    },
    {
        "name": "Shipper Two",
        "email": "shipper2@example.com",
        "phone": "0922222222",
        "plate": "59-B2 23456",
        "status": ShipperStatus.BUSY,
        "lat": 10.77690,
        "lng": 106.70090,
    },
    {
        "name": "Shipper Three",
        "email": "shipper3@example.com",
        "phone": "0933333333",
        "plate": "59-C3 34567",
        "status": ShipperStatus.AVAILABLE,
        "lat": 10.79520,
        "lng": 106.72180,
    },
    {
        "name": "Shipper Four",
        "email": "shipper4@example.com",
        "phone": "0944444444",
        "plate": "59-D4 45678",
        "status": ShipperStatus.BUSY,
        "lat": 10.85000,
        "lng": 106.77000,
    },
    {
        "name": "Shipper Five",
        "email": "shipper5@example.com",
        "phone": "0955555555",
        "plate": "59-E5 56789",
        "status": ShipperStatus.AVAILABLE,
        "lat": 10.76260,
        "lng": 106.68220,
    },
    {
        "name": "Shipper Six",
        "email": "shipper6@example.com",
        "phone": "0966666666",
        "plate": "59-F6 67890",
        "status": ShipperStatus.OFFLINE,
        "lat": 10.84600,
        "lng": 106.64200,
    },
]

ORDERS = [
    {
        "order_code": "HCM-0001",
        "customer_name": "Mr. Nam",
        "customer_phone": "0909000001",
        "pickup_address": "Ben Thanh Market, District 1, HCMC",
        "pickup_lat": 10.7721,
        "pickup_lng": 106.6983,
        "delivery_address": "Nguyen Hue Walking Street, District 1, HCMC",
        "delivery_lat": 10.7736,
        "delivery_lng": 106.7044,
        "cod_amount": 350000,
        "delivery_fee": 25000,
        "status": DeliveryStatus.ASSIGNED,
        "shipper_index": 0,
        "items": [
            {"sku": "PHO-001", "name": "Pho bo dac biet", "quantity": 2, "unit_price": 85000, "weight_kg": 1.2},
            {"sku": "DRK-001", "name": "Tra tac mat ong", "quantity": 2, "unit_price": 25000, "weight_kg": 0.8},
        ],
    },
    {
        "order_code": "HCM-0002",
        "customer_name": "Ms. Lan",
        "customer_phone": "0909000002",
        "pickup_address": "Tan Dinh Market, District 1, HCMC",
        "pickup_lat": 10.7928,
        "pickup_lng": 106.6907,
        "delivery_address": "Landmark 81, Binh Thanh, HCMC",
        "delivery_lat": 10.7952,
        "delivery_lng": 106.7218,
        "cod_amount": 520000,
        "delivery_fee": 32000,
        "status": DeliveryStatus.ASSIGNED,
        "shipper_index": 1,
        "items": [
            {"sku": "RICE-SET", "name": "Com ga set", "quantity": 3, "unit_price": 95000, "weight_kg": 2.1},
            {"sku": "SOUP-01", "name": "Canh rong bien", "quantity": 1, "unit_price": 45000, "weight_kg": 0.6},
            {"sku": "DRK-002", "name": "Nuoc sam", "quantity": 3, "unit_price": 20000, "weight_kg": 1.0},
        ],
    },
    {
        "order_code": "HCM-0003",
        "customer_name": "Mr. Quan",
        "customer_phone": "0909000003",
        "pickup_address": "Crescent Mall, District 7, HCMC",
        "pickup_lat": 10.7295,
        "pickup_lng": 106.7218,
        "delivery_address": "Nha Be, HCMC",
        "delivery_lat": 10.6997,
        "delivery_lng": 106.7312,
        "cod_amount": 280000,
        "delivery_fee": 30000,
        "status": DeliveryStatus.ASSIGNED,
        "shipper_index": 2,
        "items": [
            {"sku": "BREAD-01", "name": "Banh mi thit", "quantity": 4, "unit_price": 35000, "weight_kg": 0.8},
            {"sku": "COFFEE-01", "name": "Ca phe sua da", "quantity": 2, "unit_price": 30000, "weight_kg": 0.7},
        ],
    },
    {
        "order_code": "HCM-0004",
        "customer_name": "Ms. Phuong",
        "customer_phone": "0909000004",
        "pickup_address": "Thu Duc City, HCMC",
        "pickup_lat": 10.8500,
        "pickup_lng": 106.7700,
        "delivery_address": "Binh Thanh, HCMC",
        "delivery_lat": 10.8012,
        "delivery_lng": 106.7118,
        "cod_amount": 760000,
        "delivery_fee": 45000,
        "status": DeliveryStatus.ASSIGNED,
        "shipper_index": 3,
        "items": [
            {"sku": "DUCK-01", "name": "Vit xiem ham chao khoai mon", "quantity": 1, "unit_price": 420000, "weight_kg": 2.5},
            {"sku": "NOODLE-01", "name": "Bun tuoi", "quantity": 3, "unit_price": 25000, "weight_kg": 1.2},
            {"sku": "VEG-01", "name": "Rau song combo", "quantity": 2, "unit_price": 30000, "weight_kg": 0.6},
        ],
    },
    {
        "order_code": "HCM-0005",
        "customer_name": "Mr. Minh",
        "customer_phone": "0909000005",
        "pickup_address": "District 5, HCMC",
        "pickup_lat": 10.7626,
        "pickup_lng": 106.6822,
        "delivery_address": "District 7, HCMC",
        "delivery_lat": 10.7428,
        "delivery_lng": 106.7135,
        "cod_amount": 410000,
        "delivery_fee": 36000,
        "status": DeliveryStatus.PENDING,
        "shipper_index": None,
        "items": [
            {"sku": "XOI-01", "name": "Xoi ga", "quantity": 2, "unit_price": 55000, "weight_kg": 1.0},
            {"sku": "JUICE-01", "name": "Nuoc ep cam", "quantity": 2, "unit_price": 35000, "weight_kg": 0.9},
        ],
    },
]

ORDERS.extend([
    {
        "order_code": "HCM-0006",
        "customer_name": "Ms. Trang",
        "customer_phone": "0909000006",
        "pickup_address": "Saigon Centre, District 1, HCMC",
        "pickup_lat": 10.7731,
        "pickup_lng": 106.7008,
        "delivery_address": "Phu Nhuan District, HCMC",
        "delivery_lat": 10.7998,
        "delivery_lng": 106.6805,
        "cod_amount": 635000,
        "delivery_fee": 39000,
        "status": DeliveryStatus.IN_TRANSIT,
        "shipper_index": 1,
        "items": [
            {"sku": "ELEC-01", "name": "Bluetooth keyboard", "quantity": 1, "unit_price": 420000, "weight_kg": 0.8, "status": DeliveryItemStatus.IN_TRANSIT},
            {"sku": "ELEC-02", "name": "Laptop stand", "quantity": 1, "unit_price": 215000, "weight_kg": 1.1, "status": DeliveryItemStatus.IN_TRANSIT},
        ],
    },
    {
        "order_code": "HCM-0007",
        "customer_name": "Mr. Khoa",
        "customer_phone": "0909000007",
        "pickup_address": "An Dong Market, District 5, HCMC",
        "pickup_lat": 10.7568,
        "pickup_lng": 106.6721,
        "delivery_address": "Go Vap District, HCMC",
        "delivery_lat": 10.8382,
        "delivery_lng": 106.6657,
        "cod_amount": 980000,
        "delivery_fee": 52000,
        "status": DeliveryStatus.PICKED_UP,
        "shipper_index": 3,
        "items": [
            {"sku": "FASH-01", "name": "Fashion parcel large", "quantity": 2, "unit_price": 350000, "weight_kg": 1.6, "status": DeliveryItemStatus.PICKED_UP},
            {"sku": "FASH-02", "name": "Accessory pack", "quantity": 1, "unit_price": 280000, "weight_kg": 0.4, "status": DeliveryItemStatus.PICKED_UP},
        ],
    },
    {
        "order_code": "HCM-0008",
        "customer_name": "Ms. Hanh",
        "customer_phone": "0909000008",
        "pickup_address": "Binh Tay Market, District 6, HCMC",
        "pickup_lat": 10.7492,
        "pickup_lng": 106.6518,
        "delivery_address": "Tan Binh District, HCMC",
        "delivery_lat": 10.8017,
        "delivery_lng": 106.6520,
        "cod_amount": 245000,
        "delivery_fee": 28000,
        "status": DeliveryStatus.DELIVERED,
        "shipper_index": 4,
        "items": [
            {"sku": "GROC-01", "name": "Grocery dry box", "quantity": 1, "unit_price": 145000, "weight_kg": 2.2, "status": DeliveryItemStatus.DELIVERED, "delivered_quantity": 1, "note": "Delivered to reception"},
            {"sku": "GROC-02", "name": "Fruit pack", "quantity": 2, "unit_price": 50000, "weight_kg": 1.8, "status": DeliveryItemStatus.DELIVERED, "delivered_quantity": 2},
        ],
    },
    {
        "order_code": "HCM-0009",
        "customer_name": "Mr. Duc",
        "customer_phone": "0909000009",
        "pickup_address": "District 10 Warehouse, HCMC",
        "pickup_lat": 10.7749,
        "pickup_lng": 106.6671,
        "delivery_address": "District 3 Office Tower, HCMC",
        "delivery_lat": 10.7829,
        "delivery_lng": 106.6901,
        "cod_amount": 1120000,
        "delivery_fee": 60000,
        "status": DeliveryStatus.FAILED,
        "shipper_index": 0,
        "items": [
            {"sku": "DOC-01", "name": "Signed contract envelope", "quantity": 1, "unit_price": 1120000, "weight_kg": 0.2, "status": DeliveryItemStatus.FAILED, "note": "Customer unavailable"},
        ],
    },
    {
        "order_code": "HCM-0010",
        "customer_name": "Ms. Mai",
        "customer_phone": "0909000010",
        "pickup_address": "District 2 Kitchen Hub, HCMC",
        "pickup_lat": 10.7871,
        "pickup_lng": 106.7498,
        "delivery_address": "Thao Dien, HCMC",
        "delivery_lat": 10.8045,
        "delivery_lng": 106.7417,
        "cod_amount": 385000,
        "delivery_fee": 26000,
        "status": DeliveryStatus.PENDING,
        "shipper_index": None,
        "items": [
            {"sku": "MEAL-10", "name": "Lunch combo premium", "quantity": 5, "unit_price": 77000, "weight_kg": 2.4},
        ],
    },
])


db = SessionLocal()
try:
    admin = db.query(User).filter(User.email == "admin@dolasol.com").first()
    if not admin:
        admin = User(
            name="System Admin",
            email="admin@dolasol.com",
            phone="0900000000",
            password_hash=hash_password("admin123"),
            role=UserRole.ADMIN,
        )
        db.add(admin)

    dispatcher = db.query(User).filter(User.email == "dispatcher@dolasol.com").first()
    if not dispatcher:
        dispatcher = User(
            name="Main Dispatcher",
            email="dispatcher@dolasol.com",
            phone="0900000001",
            password_hash=hash_password("dispatcher123"),
            role=UserRole.DISPATCHER,
        )
        db.add(dispatcher)

    shippers: list[Shipper] = []
    for demo in SHIPPER_DEMOS:
        user = db.query(User).filter(User.email == demo["email"]).first()
        if not user:
            user = User(
                name=demo["name"],
                email=demo["email"],
                phone=demo["phone"],
                password_hash=hash_password("shipper123"),
                role=UserRole.SHIPPER,
            )
            db.add(user)
            db.flush()

        shipper = db.query(Shipper).filter(Shipper.user_id == user.id).first()
        if not shipper:
            shipper = Shipper(
                user_id=user.id,
                vehicle_type="Motorbike",
                vehicle_plate=demo["plate"],
                status=demo["status"],
                current_lat=demo["lat"],
                current_lng=demo["lng"],
            )
            db.add(shipper)
            db.flush()
        else:
            shipper.vehicle_type = "Motorbike"
            shipper.vehicle_plate = demo["plate"]
            shipper.status = demo["status"]
            shipper.current_lat = demo["lat"]
            shipper.current_lng = demo["lng"]

        shippers.append(shipper)

    for item in ORDERS:
        existing = db.query(DeliveryOrder).filter(DeliveryOrder.order_code == item["order_code"]).first()
        shipper_index = item["shipper_index"]
        shipper_id = shippers[shipper_index].id if shipper_index is not None else None
        items_data = item.get("items", [])
        order_data = {key: value for key, value in item.items() if key not in ["shipper_index", "items"]}
        if not existing:
            existing = DeliveryOrder(**order_data, shipper_id=shipper_id)
            db.add(existing)
            db.flush()
        else:
            existing.customer_name = order_data["customer_name"]
            existing.customer_phone = order_data["customer_phone"]
            existing.pickup_address = order_data["pickup_address"]
            existing.pickup_lat = order_data["pickup_lat"]
            existing.pickup_lng = order_data["pickup_lng"]
            existing.delivery_address = order_data["delivery_address"]
            existing.delivery_lat = order_data["delivery_lat"]
            existing.delivery_lng = order_data["delivery_lng"]
            existing.cod_amount = order_data["cod_amount"]
            existing.delivery_fee = order_data["delivery_fee"]
            existing.status = order_data["status"]
            existing.shipper_id = shipper_id

        for item_data in items_data:
            order_item = (
                db.query(DeliveryOrderItem)
                .filter(
                    DeliveryOrderItem.order_id == existing.id,
                    DeliveryOrderItem.sku == item_data["sku"],
                )
                .first()
            )
            if not order_item:
                db.add(DeliveryOrderItem(order_id=existing.id, **item_data))
            else:
                order_item.name = item_data["name"]
                order_item.quantity = item_data["quantity"]
                order_item.unit_price = item_data["unit_price"]
                order_item.weight_kg = item_data.get("weight_kg")
                order_item.status = item_data.get("status", order_item.status)
                order_item.delivered_quantity = item_data.get("delivered_quantity", order_item.delivered_quantity)
                order_item.note = item_data.get("note", order_item.note)

    db.commit()
    print(f"Seed completed: {len(SHIPPER_DEMOS)} shippers, {len(ORDERS)} orders")
finally:
    db.close()
