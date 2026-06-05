"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import GpsFixedRoundedIcon from "@mui/icons-material/GpsFixedRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import RouteRoundedIcon from "@mui/icons-material/RouteRounded";
import { Alert, Box, Button, Card, CardContent, Chip, FormControl, Grid, InputLabel, MenuItem, Select, Stack, Typography } from "@mui/material";

import StatCard from "../../../components/common/StatCard";
import AppShell from "../../../components/layout/AppShell";
import OrderCard from "../../../components/orders/OrderCard";
import { apiGet, apiPost } from "../../../lib/api";
import { formatMoney } from "../../../lib/format";
import { isActiveOrder, shipperName, totalCod } from "../../../lib/operations";
import type { DeliveryItemStatus, DeliveryOrder, DeliveryOrderItem, RealtimeMessage, Shipper, ShipperStatus } from "../../../types/delivery";
import { useRealtime } from "../../../hooks/useRealtime";

export default function ShipperHomePage() {
  const [shipperId, setShipperId] = useState<number>(0);
  const [shippers, setShippers] = useState<Shipper[]>([]);
  const [message, setMessage] = useState("Select a shipper to start the mobile delivery workflow.");
  const [isTracking, setIsTracking] = useState(false);
  const [lastGps, setLastGps] = useState<{ lat: number; lng: number; time: string } | null>(null);
  const [orders, setOrders] = useState<DeliveryOrder[]>([]);
  const [status, setStatus] = useState<ShipperStatus>("AVAILABLE");
  const watchIdRef = useRef<number | null>(null);

  const selectedShipper = useMemo(() => shippers.find((shipper) => shipper.id === shipperId) || null, [shipperId, shippers]);

  const loadShippers = useCallback(async () => {
    try {
      const data = await apiGet<Shipper[]>("/shippers");
      setShippers(data);
      const first = data[0];
      if (first && !shipperId) {
        setShipperId(first.id);
        setStatus(first.status);
      }
    } catch {
      setMessage("Could not load shippers. Run seed first and check API connection.");
    }
  }, [shipperId]);

  const loadOrders = useCallback(async () => {
    if (!shipperId) return;
    try {
      const data = await apiGet<DeliveryOrder[]>(`/orders/shipper/${shipperId}`);
      setOrders(data);
    } catch {
      setMessage("Could not load assigned orders");
    }
  }, [shipperId]);

  async function updateShipperStatus(nextStatus: ShipperStatus) {
    if (!shipperId) return;
    try {
      await apiPost(`/shippers/${shipperId}/status`, { status: nextStatus });
      setStatus(nextStatus);
      setMessage(`Status changed to ${nextStatus}`);
    } catch {
      setMessage("Could not update shipper status");
    }
  }

  async function sendPosition(position: GeolocationPosition) {
    const payload = {
      shipper_id: shipperId,
      lat: position.coords.latitude,
      lng: position.coords.longitude,
      speed: position.coords.speed,
      heading: position.coords.heading,
      battery: null,
    };

    await apiPost("/locations/update", payload);
    setLastGps({ lat: payload.lat, lng: payload.lng, time: new Date().toLocaleTimeString() });
    setMessage(`Live GPS sent: ${payload.lat.toFixed(5)}, ${payload.lng.toFixed(5)}`);
  }

  function sendOnce() {
    if (!shipperId) {
      setMessage("Please select a shipper first.");
      return;
    }
    if (!navigator.geolocation) {
      setMessage("Geolocation is not available in this browser");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        try {
          await sendPosition(position);
        } catch {
          setMessage("Failed to send GPS. Check backend, HTTPS, and shipper ID.");
        }
      },
      () => setMessage("Location permission denied. Allow browser location or use the simulator page."),
      { enableHighAccuracy: true, maximumAge: 5000, timeout: 12000 }
    );
  }

  async function startTracking() {
    if (!shipperId) {
      setMessage("Please select a shipper first.");
      return;
    }
    if (!navigator.geolocation) {
      setMessage("Geolocation is not available in this browser");
      return;
    }
    if (watchIdRef.current !== null) return;

    await updateShipperStatus("AVAILABLE");
    const watchId = navigator.geolocation.watchPosition(
      async (position) => {
        try {
          await sendPosition(position);
        } catch {
          setMessage("GPS update failed. Check FastAPI backend.");
        }
      },
      () => setMessage("Location permission denied or GPS unavailable. Use the simulator for laptop testing."),
      { enableHighAccuracy: true, maximumAge: 3000, timeout: 15000 }
    );
    watchIdRef.current = watchId;
    setIsTracking(true);
    setMessage("Realtime tracking started. Keep this page open.");
  }

  async function stopTracking() {
    if (watchIdRef.current !== null) {
      navigator.geolocation.clearWatch(watchIdRef.current);
      watchIdRef.current = null;
    }
    setIsTracking(false);
    await updateShipperStatus("OFFLINE");
    setMessage("Tracking stopped. Shipper is offline.");
  }

  async function updateOrder(orderId: number, nextStatus: string) {
    try {
      await apiPost(`/orders/${orderId}/status`, { status: nextStatus, delivery_note: `Updated by shipper at ${new Date().toLocaleString()}` });
      setMessage(`Order updated to ${nextStatus}`);
      await loadOrders();
      if (["PICKED_UP", "IN_TRANSIT"].includes(nextStatus)) setStatus("BUSY");
    } catch {
      setMessage("Could not update order status");
    }
  }

  async function updateItem(orderId: number, item: DeliveryOrderItem, nextStatus: DeliveryItemStatus) {
    try {
      await apiPost(`/orders/${orderId}/items/${item.id}/status`, {
        status: nextStatus,
        delivered_quantity: nextStatus === "DELIVERED" ? item.quantity : item.delivered_quantity,
        note: `Item ${nextStatus} by shipper at ${new Date().toLocaleString()}`,
      });
      setMessage(`Item ${item.name} updated to ${nextStatus}`);
      await loadOrders();
      if (["PICKED_UP", "IN_TRANSIT"].includes(nextStatus)) setStatus("BUSY");
    } catch {
      setMessage("Could not update item status");
    }
  }

  useEffect(() => {
    void loadShippers();
  }, [loadShippers]);

  useEffect(() => {
    void loadOrders();
  }, [loadOrders]);

  useRealtime((payload: RealtimeMessage) => {
    const isThisShipperOrder = payload.order?.shipper_id === shipperId || payload.shipper_id === shipperId;
    if (["order_assigned", "order_status", "order_item_status", "order_item_created"].includes(payload.type) && isThisShipperOrder) {
      void loadOrders();
      const label = payload.item ? `${payload.item.name} is ${payload.item.status}` : `${payload.order?.order_code || "Order"} updated`;
      setMessage(`Realtime delivery update: ${label}`);
    }
    if (payload.type === "shipper_status" && payload.shipper_id === shipperId && payload.status) {
      setStatus(payload.status);
    }
  });

  useEffect(() => {
    return () => {
      if (watchIdRef.current !== null) navigator.geolocation.clearWatch(watchIdRef.current);
    };
  }, []);

  const activeOrders = orders.filter((order) => isActiveOrder(order.status)).length;

  return (
    <AppShell
      title="Shipper Mobile Console"
      subtitle="Phone-style workflow for GPS, duty status, assigned jobs, package fulfillment, COD, and delivery confirmation."
      actions={
        <Stack direction="row" spacing={1} flexWrap="wrap">
          <Button component={Link} href="/shipper/simulator" variant="contained">Fake GPS Simulator</Button>
          <Button component={Link} href="/admin/map" variant="outlined">Live Map</Button>
        </Stack>
      }
    >
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={6} md={3}><StatCard label="Assigned jobs" value={orders.length} helper={`${activeOrders} active`} icon={<RouteRoundedIcon />} accent="#2563eb" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="COD to collect" value={formatMoney(totalCod(orders))} helper="Assigned orders" icon={<LocalShippingRoundedIcon />} accent="#16a34a" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="GPS state" value={isTracking ? "Live" : "Stopped"} helper={lastGps ? lastGps.time : "No GPS sent"} icon={<GpsFixedRoundedIcon />} accent={isTracking ? "#16a34a" : "#64748b"} /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Duty status" value={status} helper={selectedShipper ? shipperName(selectedShipper) : "No shipper"} accent="#f59e0b" /></Grid>
      </Grid>

      <Card sx={{ borderRadius: 3.5, mb: 3, border: "1px solid #e2e8f0", boxShadow: "0 16px 38px rgba(15, 23, 42, 0.07)" }}>
        <CardContent sx={{ p: 2.4 }}>
          <Stack direction={{ xs: "column", lg: "row" }} justifyContent="space-between" gap={2}>
            <Stack direction={{ xs: "column", md: "row" }} spacing={2} alignItems={{ xs: "stretch", md: "center" }} flexWrap="wrap">
              <FormControl size="small" sx={{ minWidth: 280 }}>
                <InputLabel>Active shipper</InputLabel>
                <Select
                  label="Active shipper"
                  value={shipperId || ""}
                  onChange={(event) => {
                    const nextId = Number(event.target.value);
                    const next = shippers.find((shipper) => shipper.id === nextId);
                    setShipperId(nextId);
                    setStatus(next?.status || "AVAILABLE");
                  }}
                >
                  {shippers.map((shipper) => (
                    <MenuItem key={shipper.id} value={shipper.id}>{shipperName(shipper)} · {shipper.vehicle_plate || "No plate"}</MenuItem>
                  ))}
                </Select>
              </FormControl>
              <Chip label={isTracking ? "TRACKING" : "STOPPED"} color={isTracking ? "success" : "default"} sx={{ fontWeight: 900 }} />
              <Chip label={status} color={status === "BUSY" ? "warning" : status === "AVAILABLE" ? "success" : "default"} sx={{ fontWeight: 900 }} />
            </Stack>
            <Stack direction="row" spacing={1} flexWrap="wrap">
              <Button variant="contained" color="success" disabled={isTracking} onClick={startTracking}>Start Realtime</Button>
              <Button variant="outlined" color="error" disabled={!isTracking} onClick={stopTracking}>Stop</Button>
              <Button variant="outlined" onClick={sendOnce}>Send GPS Once</Button>
              <Button variant="outlined" onClick={() => updateShipperStatus("AVAILABLE")}>Available</Button>
              <Button variant="outlined" onClick={() => updateShipperStatus("BUSY")}>Busy</Button>
              <Button variant="outlined" onClick={() => updateShipperStatus("OFFLINE")}>Offline</Button>
            </Stack>
          </Stack>
          <Alert severity={message.includes("Could not") || message.includes("denied") || message.includes("failed") ? "warning" : "info"} sx={{ mt: 2 }}>{message}</Alert>
          {lastGps && <Typography variant="body2" sx={{ mt: 1 }}>Last GPS: {lastGps.lat.toFixed(5)}, {lastGps.lng.toFixed(5)} at {lastGps.time}</Typography>}
        </CardContent>
      </Card>

      <Stack spacing={2}>
        {orders.map((order) => (
          <OrderCard key={order.id} order={order} mode="shipper" shipperName={selectedShipper ? shipperName(selectedShipper) : undefined} onOrderStatus={updateOrder} onItemStatus={updateItem} />
        ))}
      </Stack>

      {!orders.length && (
        <Box sx={{ mt: 3 }}>
          <Alert severity="info">No assigned orders for this shipper yet. Assign orders from the Dispatch Board.</Alert>
        </Box>
      )}
    </AppShell>
  );
}
