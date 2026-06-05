"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import AddRoadRoundedIcon from "@mui/icons-material/AddRoadRounded";
import AssignmentLateRoundedIcon from "@mui/icons-material/AssignmentLateRounded";
import Inventory2RoundedIcon from "@mui/icons-material/Inventory2Rounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import PaymentsRoundedIcon from "@mui/icons-material/PaymentsRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import { Alert, Box, Button, Card, CardContent, FormControl, Grid, InputAdornment, InputLabel, MenuItem, Select, Stack, Tab, Tabs, TextField, Typography } from "@mui/material";

import StatCard from "../../../components/common/StatCard";
import StatusChip from "../../../components/common/StatusChip";
import AppShell from "../../../components/layout/AppShell";
import OrderCard from "../../../components/orders/OrderCard";
import { formatMoney } from "../../../lib/format";
import { buildOrderLanes, isActiveOrder, orderProgress, shipperById, shipperName, totalCod, totalDeliveryFees, totalItems } from "../../../lib/operations";
import { apiGet, apiPost } from "../../../lib/api";
import type { DeliveryItemStatus, DeliveryOrder, DeliveryOrderItem, DeliveryStatus, Shipper } from "../../../types/delivery";
import { useRealtime } from "../../../hooks/useRealtime";

const statusOptions: (DeliveryStatus | "ALL")[] = ["ALL", "PENDING", "ASSIGNED", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "FAILED", "RETURNED", "CANCELLED"];

export default function OrdersPage() {
  const [orders, setOrders] = useState<DeliveryOrder[]>([]);
  const [shippers, setShippers] = useState<Shipper[]>([]);
  const [message, setMessage] = useState("Loading operations data...");
  const [status, setStatus] = useState<DeliveryStatus | "ALL">("ALL");
  const [query, setQuery] = useState("");
  const [laneIndex, setLaneIndex] = useState(0);

  const loadData = useCallback(async () => {
    try {
      const [orderData, shipperData] = await Promise.all([
        apiGet<DeliveryOrder[]>("/orders"),
        apiGet<Shipper[]>("/shippers"),
      ]);
      setOrders(orderData);
      setShippers(shipperData);
      setMessage(`Loaded ${orderData.length} orders and ${shipperData.length} shippers`);
    } catch (error) {
      setMessage(error instanceof Error ? `Could not load operations data: ${error.message}` : "Could not load operations data");
    }
  }, []);

  async function updateItem(orderId: number, item: DeliveryOrderItem, nextStatus: DeliveryItemStatus) {
    try {
      await apiPost(`/orders/${orderId}/items/${item.id}/status`, {
        status: nextStatus,
        delivered_quantity: nextStatus === "DELIVERED" ? item.quantity : item.delivered_quantity,
        note: `Updated by dispatch at ${new Date().toLocaleString()}`,
      });
      setMessage(`${item.name} updated to ${nextStatus}`);
      await loadData();
    } catch (error) {
      setMessage(error instanceof Error ? `Could not update item: ${error.message}` : "Could not update item");
    }
  }

  async function assignOrder(orderId: number, shipperId: number) {
    if (!shipperId) return;
    try {
      await apiPost(`/orders/${orderId}/assign`, { shipper_id: shipperId });
      setMessage(`Order assigned to shipper #${shipperId}`);
      await loadData();
    } catch (error) {
      setMessage(error instanceof Error ? `Could not assign order: ${error.message}` : "Could not assign order");
    }
  }

  useEffect(() => {
    void loadData();
  }, [loadData]);

  useRealtime((payload) => {
    if (["order_created", "order_assigned", "order_status", "order_item_status", "order_item_created", "shipper_status"].includes(payload.type)) {
      void loadData();
      if (payload.item) setMessage(`Realtime item update: ${payload.item.name} is ${payload.item.status}`);
      else if (payload.order) setMessage(`Realtime order update: ${payload.order.order_code} is ${payload.order.status}`);
      else setMessage("Realtime fleet status updated");
    }
  });

  const shipperMap = useMemo(() => shipperById(shippers), [shippers]);
  const lanes = useMemo(() => buildOrderLanes(orders), [orders]);
  const selectedLane = lanes[laneIndex] || lanes[0];

  const filteredOrders = useMemo(() => {
    const search = query.trim().toLowerCase();
    return orders.filter((order) => {
      const matchesStatus = status === "ALL" || order.status === status;
      const matchesLane = selectedLane.statuses.includes(order.status);
      const haystack = `${order.order_code} ${order.customer_name} ${order.customer_phone} ${order.pickup_address} ${order.delivery_address}`.toLowerCase();
      return matchesStatus && matchesLane && (!search || haystack.includes(search));
    });
  }, [orders, query, selectedLane, status]);

  const summary = useMemo(() => {
    const unassigned = orders.filter((order) => !order.shipper_id).length;
    const active = orders.filter((order) => isActiveOrder(order.status)).length;
    const delivered = orders.filter((order) => order.status === "DELIVERED").length;
    return {
      orders: orders.length,
      active,
      delivered,
      unassigned,
      cod: totalCod(orders),
      fee: totalDeliveryFees(orders),
      items: totalItems(orders),
    };
  }, [orders]);

  const availableShippers = shippers.filter((shipper) => ["AVAILABLE", "BUSY"].includes(shipper.status));

  return (
    <AppShell
      title="Dispatch Board"
      subtitle="A practical order-control room for assigning shippers, monitoring delivery lanes, collecting COD, and updating package status."
      actions={
        <Stack direction="row" spacing={1} flexWrap="wrap">
          <Button component={Link} href="/admin/map" variant="outlined">Live Map</Button>
          <Button component={Link} href="/shipper/simulator" variant="contained" startIcon={<AddRoadRoundedIcon />}>Run Simulator</Button>
        </Stack>
      }
    >
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={6} md={3}><StatCard label="Orders in system" value={summary.orders} helper={`${summary.active} active trips`} icon={<Inventory2RoundedIcon />} accent="#2563eb" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Unassigned" value={summary.unassigned} helper="Need dispatcher action" icon={<AssignmentLateRoundedIcon />} accent="#dc2626" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="COD exposure" value={formatMoney(summary.cod)} helper={`${formatMoney(summary.fee)} delivery fee`} icon={<PaymentsRoundedIcon />} accent="#16a34a" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Fleet candidates" value={availableShippers.length} helper={`${summary.items} packages in board`} icon={<LocalShippingRoundedIcon />} accent="#f59e0b" /></Grid>
      </Grid>

      <Card sx={{ borderRadius: 3.5, border: "1px solid #e2e8f0", mb: 3 }}>
        <CardContent>
          <Stack direction={{ xs: "column", lg: "row" }} spacing={2} justifyContent="space-between">
            <Tabs value={laneIndex} onChange={(_, value) => setLaneIndex(value)} variant="scrollable" scrollButtons="auto">
              {lanes.map((lane) => <Tab key={lane.label} label={`${lane.label} (${lane.orders.length})`} />)}
            </Tabs>
            <Stack direction={{ xs: "column", sm: "row" }} spacing={1.5} minWidth={{ lg: 560 }}>
              <TextField
                size="small"
                label="Search order, customer, phone, address"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                fullWidth
                InputProps={{ startAdornment: <InputAdornment position="start"><SearchRoundedIcon fontSize="small" /></InputAdornment> }}
              />
              <FormControl size="small" sx={{ minWidth: 170 }}>
                <InputLabel>Status</InputLabel>
                <Select label="Status" value={status} onChange={(event) => setStatus(event.target.value as DeliveryStatus | "ALL")}>
                  {statusOptions.map((item) => <MenuItem key={item} value={item}>{item === "ALL" ? "All statuses" : item.replaceAll("_", " ")}</MenuItem>)}
                </Select>
              </FormControl>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      <Alert severity={message.includes("Could not") ? "warning" : "info"} sx={{ mb: 3 }}>{message}</Alert>

      <Stack spacing={2.2}>
        {filteredOrders.map((order) => (
          <Box key={order.id}>
            {!order.shipper_id && (
              <Card sx={{ borderRadius: 3, border: "1px solid #dbeafe", bgcolor: "#eff6ff", mb: 1 }}>
                <CardContent sx={{ py: 1.5 }}>
                  <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" alignItems={{ xs: "stretch", md: "center" }} gap={1.5}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <StatusChip status="PENDING" />
                      <Typography fontWeight={850}>Assign this order to an available shipper</Typography>
                    </Stack>
                    <FormControl size="small" sx={{ minWidth: 260, bgcolor: "white" }}>
                      <InputLabel>Assign shipper</InputLabel>
                      <Select label="Assign shipper" value="" onChange={(event) => assignOrder(order.id, Number(event.target.value))}>
                        {availableShippers.map((shipper) => (
                          <MenuItem key={shipper.id} value={shipper.id}>
                            {shipperName(shipper)} · {shipper.vehicle_plate || "No plate"} · {shipper.status}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  </Stack>
                </CardContent>
              </Card>
            )}
            <OrderCard order={order} mode="admin" shipperName={shipperName(shipperMap[order.shipper_id || -1])} onItemStatus={updateItem} />
          </Box>
        ))}
      </Stack>

      {!filteredOrders.length && (
        <Box sx={{ mt: 4 }}>
          <Alert severity="info">No orders match this lane and filter. Try another lane or status.</Alert>
        </Box>
      )}
    </AppShell>
  );
}
