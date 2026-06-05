export type ShipperStatus = "AVAILABLE" | "BUSY" | "OFFLINE" | "SUSPENDED";
export type DeliveryStatus = "PENDING" | "ASSIGNED" | "PICKED_UP" | "IN_TRANSIT" | "DELIVERED" | "FAILED" | "CANCELLED" | "RETURNED" | "PARTIALLY_DELIVERED";
export type DeliveryItemStatus = "PENDING" | "PICKED_UP" | "IN_TRANSIT" | "DELIVERED" | "FAILED" | "RETURNED";

export type Shipper = {
  id: number;
  user_id: number;
  vehicle_type?: string | null;
  vehicle_plate?: string | null;
  status: ShipperStatus;
  current_lat?: number | null;
  current_lng?: number | null;
  last_seen_at?: string | null;
  user?: {
    id: number;
    name: string;
    email: string;
    phone?: string | null;
    role: string;
  } | null;
};

export type LiveShipper = {
  shipper_id: number;
  user_id?: number;
  name: string;
  phone?: string | null;
  vehicle_type?: string | null;
  vehicle_plate?: string | null;
  status: ShipperStatus;
  lat?: number | null;
  lng?: number | null;
  last_seen_at?: string | null;
};

export type DeliveryOrderItem = {
  id: number;
  order_id: number;
  sku?: string | null;
  name: string;
  description?: string | null;
  quantity: number;
  delivered_quantity: number;
  unit_price: number;
  weight_kg?: number | null;
  status: DeliveryItemStatus;
  note?: string | null;
};

export type DeliveryOrder = {
  id: number;
  order_code: string;
  customer_name: string;
  customer_phone: string;
  pickup_address: string;
  pickup_lat?: number | null;
  pickup_lng?: number | null;
  delivery_address: string;
  delivery_lat?: number | null;
  delivery_lng?: number | null;
  cod_amount: number;
  delivery_fee: number;
  status: DeliveryStatus;
  shipper_id: number | null;
  proof_image_url?: string | null;
  delivery_note?: string | null;
  receiver_name?: string | null;
  failed_reason?: string | null;
  cod_collected?: boolean;
  cod_collected_amount?: number;
  payment_method?: "CASH" | "BANK_TRANSFER" | "WALLET" | "OTHER" | null;
  cod_settlement_status?: "PENDING" | "COLLECTED" | "SETTLED" | "DISCREPANCY";
  items: DeliveryOrderItem[];
};

export type RealtimeMessage = {
  type: string;
  shipper_id?: number;
  order_id?: number;
  order?: DeliveryOrder;
  item?: DeliveryOrderItem;
  status?: ShipperStatus;
  lat?: number;
  lng?: number;
};
