export const dynamic = "force-dynamic";

import Link from "next/link";
import AssignmentLateRoundedIcon from "@mui/icons-material/AssignmentLateRounded";
import Inventory2RoundedIcon from "@mui/icons-material/Inventory2Rounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import MapRoundedIcon from "@mui/icons-material/MapRounded";
import PaymentsRoundedIcon from "@mui/icons-material/PaymentsRounded";
import { Box, Button, Card, CardContent, Divider, Grid, LinearProgress, Stack, Typography } from "@mui/material";

import StatCard from "../../../components/common/StatCard";
import StatusChip from "../../../components/common/StatusChip";
import AppShell from "../../../components/layout/AppShell";
import OrderCard from "../../../components/orders/OrderCard";
import { cookies } from "next/headers";
import { API_SERVER_URL } from "../../../lib/api";
import { formatMoney } from "../../../lib/format";
import { buildOrderLanes, isActiveOrder, lastSeenLabel, orderProgress, shipperById, shipperName, totalCod, totalDeliveryFees, totalItems } from "../../../lib/operations";
import type { DeliveryOrder, Shipper } from "../../../types/delivery";

async function safeFetch<T>(path: string, fallback: T): Promise<T> {
  try {
    const token = (await cookies()).get("shipops_token")?.value;
    const headers = token ? { Authorization: `Bearer ${token}` } : undefined;
    const res = await fetch(`${API_SERVER_URL}${path}`, { cache: "no-store", headers });
    if (!res.ok) return fallback;
    const data = await res.json();
    return (data && Array.isArray(data.items) ? data.items : data) as T;
  } catch {
    return fallback;
  }
}

export default async function DashboardPage() {
  const [summary, orders, shippers] = await Promise.all([
    safeFetch("/dashboard/summary", {
      orders: 0,
      active_orders: 0,
      delivered_orders: 0,
      items: 0,
      delivered_items: 0,
      failed_items: 0,
      shippers: 0,
      live_shippers: 0,
      available_shippers: 0,
      busy_shippers: 0,
    }),
    safeFetch<DeliveryOrder[]>("/orders", []),
    safeFetch<Shipper[]>("/shippers", []),
  ]);

  const shipperMap = shipperById(shippers);
  const lanes = buildOrderLanes(orders);
  const activeOrders = orders.filter((order) => isActiveOrder(order.status));
  const unassignedOrders = orders.filter((order) => !order.shipper_id);
  const exceptionOrders = orders.filter((order) => ["FAILED", "RETURNED", "CANCELLED"].includes(order.status));
  const liveShippers = shippers.filter((shipper) => shipper.current_lat && shipper.current_lng);
  const deliveryRate = summary.orders ? Math.round((summary.delivered_orders / summary.orders) * 100) : 0;
  const packageRate = summary.items ? Math.round((summary.delivered_items / summary.items) * 100) : 0;

  return (
    <AppShell
      title="Command Center"
      subtitle="A real-time operating view for dispatchers: delivery lanes, fleet availability, COD exposure, and problem orders."
      actions={
        <Stack direction="row" spacing={1} flexWrap="wrap">
          <Button component={Link} href="/admin/orders" variant="contained" startIcon={<Inventory2RoundedIcon />}>Open Dispatch Board</Button>
          <Button component={Link} href="/admin/map" variant="outlined" startIcon={<MapRoundedIcon />}>Live Map</Button>
        </Stack>
      }
    >
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={6} md={3}><StatCard label="Active trips" value={summary.active_orders} helper={`${unassignedOrders.length} waiting assignment`} icon={<LocalShippingRoundedIcon />} accent="#2563eb" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Delivery success" value={`${deliveryRate}%`} helper={`${summary.delivered_orders}/${summary.orders} orders closed`} icon={<Inventory2RoundedIcon />} accent="#16a34a" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="COD exposure" value={formatMoney(totalCod(orders))} helper={`${formatMoney(totalDeliveryFees(orders))} delivery fee`} icon={<PaymentsRoundedIcon />} accent="#f59e0b" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Exceptions" value={exceptionOrders.length} helper={`${summary.failed_items} failed packages`} icon={<AssignmentLateRoundedIcon />} accent="#dc2626" /></Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} lg={8}>
          <Card sx={{ borderRadius: 3.5, border: "1px solid #e2e8f0", mb: 3 }}>
            <CardContent>
              <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" alignItems={{ xs: "stretch", md: "center" }} gap={2} sx={{ mb: 2 }}>
                <Box>
                  <Typography variant="h6" fontWeight={950}>Delivery Pipeline</Typography>
                  <Typography color="text.secondary">Orders grouped by operational stage.</Typography>
                </Box>
                <Box sx={{ minWidth: 220 }}>
                  <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.5 }}>
                    <Typography variant="body2" fontWeight={850}>Package completion</Typography>
                    <Typography variant="body2" color="text.secondary">{packageRate}%</Typography>
                  </Stack>
                  <LinearProgress variant="determinate" value={packageRate} sx={{ height: 9, borderRadius: 999 }} />
                </Box>
              </Stack>
              <Grid container spacing={1.5}>
                {lanes.map((lane) => (
                  <Grid item xs={6} md={3} key={lane.label}>
                    <Box sx={{ p: 2, borderRadius: 3, bgcolor: "#f8fafc", border: "1px solid #e2e8f0", height: "100%" }}>
                      <Typography fontWeight={950}>{lane.label}</Typography>
                      <Typography variant="h4" fontWeight={950} sx={{ mt: 0.5 }}>{lane.orders.length}</Typography>
                      <Typography variant="caption" color="text.secondary">{lane.statuses.join(" / ").replaceAll("_", " ")}</Typography>
                    </Box>
                  </Grid>
                ))}
              </Grid>
            </CardContent>
          </Card>

          <Stack spacing={2}>
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Box>
                <Typography variant="h6" fontWeight={950}>Priority Orders</Typography>
                <Typography color="text.secondary">Unassigned and active deliveries needing dispatcher attention.</Typography>
              </Box>
              <Button component={Link} href="/admin/orders">View all</Button>
            </Stack>
            {[...unassignedOrders, ...activeOrders].slice(0, 4).map((order) => (
              <OrderCard key={order.id} order={order} mode="admin" compact shipperName={shipperName(shipperMap[order.shipper_id || -1])} />
            ))}
            {![...unassignedOrders, ...activeOrders].length && (
              <Card sx={{ borderRadius: 3, border: "1px solid #e2e8f0" }}><CardContent><Typography color="text.secondary">No priority orders right now.</Typography></CardContent></Card>
            )}
          </Stack>
        </Grid>

        <Grid item xs={12} lg={4}>
          <Stack spacing={3}>
            <Card sx={{ borderRadius: 3.5, border: "1px solid #e2e8f0" }}>
              <CardContent>
                <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                  <Box>
                    <Typography variant="h6" fontWeight={950}>Fleet Now</Typography>
                    <Typography color="text.secondary">Live GPS and availability snapshot.</Typography>
                  </Box>
                  <Button component={Link} href="/admin/shippers" size="small">Fleet</Button>
                </Stack>
                <Divider sx={{ my: 1.5 }} />
                <Stack spacing={1.4}>
                  {shippers.slice(0, 7).map((shipper) => (
                    <Stack key={shipper.id} direction="row" justifyContent="space-between" alignItems="center" gap={1.5}>
                      <Box sx={{ minWidth: 0 }}>
                        <Typography fontWeight={900} noWrap>{shipperName(shipper)}</Typography>
                        <Typography variant="caption" color="text.secondary">{shipper.vehicle_plate || "No plate"} · {lastSeenLabel(shipper.last_seen_at)}</Typography>
                      </Box>
                      <StatusChip status={shipper.status} />
                    </Stack>
                  ))}
                </Stack>
              </CardContent>
            </Card>

            <Card sx={{ borderRadius: 3.5, border: "1px solid #e2e8f0" }}>
              <CardContent>
                <Typography variant="h6" fontWeight={950}>Operational Health</Typography>
                <Stack spacing={2} sx={{ mt: 2 }}>
                  <Box>
                    <Stack direction="row" justifyContent="space-between"><Typography fontWeight={850}>Live shippers</Typography><Typography>{liveShippers.length}/{shippers.length}</Typography></Stack>
                    <LinearProgress variant="determinate" value={shippers.length ? Math.round((liveShippers.length / shippers.length) * 100) : 0} sx={{ mt: 0.8, height: 8, borderRadius: 999 }} />
                  </Box>
                  <Box>
                    <Stack direction="row" justifyContent="space-between"><Typography fontWeight={850}>Package delivery</Typography><Typography>{summary.delivered_items}/{summary.items}</Typography></Stack>
                    <LinearProgress variant="determinate" value={packageRate} color="success" sx={{ mt: 0.8, height: 8, borderRadius: 999 }} />
                  </Box>
                  <Box>
                    <Typography fontWeight={850}>Total packages</Typography>
                    <Typography variant="h5" fontWeight={950}>{totalItems(orders)}</Typography>
                  </Box>
                </Stack>
              </CardContent>
            </Card>
          </Stack>
        </Grid>
      </Grid>
    </AppShell>
  );
}
