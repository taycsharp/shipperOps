import type { DeliveryOrder, DeliveryOrderItem, DeliveryStatus, Shipper } from "../types/delivery";

export const activeOrderStatuses: DeliveryStatus[] = ["ASSIGNED", "PICKED_UP", "IN_TRANSIT", "PARTIALLY_DELIVERED"];
export const finalOrderStatuses: DeliveryStatus[] = ["DELIVERED", "FAILED", "CANCELLED", "RETURNED"];

export function isActiveOrder(status: string) {
  return activeOrderStatuses.includes(status as DeliveryStatus);
}

export function orderValue(order: DeliveryOrder) {
  const itemValue = (order.items || []).reduce((sum, item) => sum + Number(item.unit_price || 0) * Number(item.quantity || 0), 0);
  return itemValue || Number(order.cod_amount || 0);
}

export function totalCod(orders: DeliveryOrder[]) {
  return orders.reduce((sum, order) => sum + Number(order.cod_amount || 0), 0);
}

export function totalDeliveryFees(orders: DeliveryOrder[]) {
  return orders.reduce((sum, order) => sum + Number(order.delivery_fee || 0), 0);
}

export function totalItems(orders: DeliveryOrder[]) {
  return orders.reduce((sum, order) => sum + (order.items || []).reduce((inner, item) => inner + Number(item.quantity || 0), 0), 0);
}

export function deliveredItemQuantity(items: DeliveryOrderItem[]) {
  return items.reduce((sum, item) => sum + Number(item.delivered_quantity || 0), 0);
}

export function itemQuantity(items: DeliveryOrderItem[]) {
  return items.reduce((sum, item) => sum + Number(item.quantity || 0), 0);
}

export function orderProgress(order: DeliveryOrder) {
  const total = itemQuantity(order.items || []);
  if (!total) return 0;
  return Math.round((deliveredItemQuantity(order.items || []) / total) * 100);
}

export function statusLabel(status: string) {
  return status.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (char) => char.toUpperCase());
}

export function shortAddress(address?: string | null) {
  if (!address) return "—";
  return address.length > 56 ? `${address.slice(0, 56)}…` : address;
}

export function lastSeenLabel(value?: string | null) {
  if (!value) return "No signal";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Unknown";
  const diffSeconds = Math.max(0, Math.round((Date.now() - date.getTime()) / 1000));
  if (diffSeconds < 60) return `${diffSeconds}s ago`;
  const diffMinutes = Math.round(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.round(diffMinutes / 60);
  return `${diffHours}h ago`;
}

export function shipperName(shipper?: Shipper | null) {
  if (!shipper) return "Unassigned";
  return shipper.user?.name || `Shipper #${shipper.id}`;
}

export function shipperById(shippers: Shipper[]) {
  return Object.fromEntries(shippers.map((shipper) => [shipper.id, shipper]));
}

export function buildOrderLanes(orders: DeliveryOrder[]) {
  return [
    { label: "New", statuses: ["PENDING"], orders: orders.filter((order) => order.status === "PENDING") },
    { label: "Assigned", statuses: ["ASSIGNED", "PICKED_UP"], orders: orders.filter((order) => ["ASSIGNED", "PICKED_UP"].includes(order.status)) },
    { label: "In transit", statuses: ["IN_TRANSIT", "PARTIALLY_DELIVERED"], orders: orders.filter((order) => ["IN_TRANSIT", "PARTIALLY_DELIVERED"].includes(order.status)) },
    { label: "Closed", statuses: finalOrderStatuses, orders: orders.filter((order) => finalOrderStatuses.includes(order.status)) },
  ];
}
