"use client";

import AssignmentTurnedInRoundedIcon from "@mui/icons-material/AssignmentTurnedInRounded";
import CallRoundedIcon from "@mui/icons-material/CallRounded";
import Inventory2RoundedIcon from "@mui/icons-material/Inventory2Rounded";
import LocationOnRoundedIcon from "@mui/icons-material/LocationOnRounded";
import PaymentsRoundedIcon from "@mui/icons-material/PaymentsRounded";
import { Box, Button, Card, CardContent, Divider, Grid, LinearProgress, Stack, Tooltip, Typography } from "@mui/material";

import StatusChip from "../common/StatusChip";
import { formatMoney } from "../../lib/format";
import { orderProgress, shortAddress } from "../../lib/operations";
import type { DeliveryOrder, DeliveryOrderItem, DeliveryItemStatus } from "../../types/delivery";

type Props = {
  order: DeliveryOrder;
  mode: "admin" | "shipper";
  shipperName?: string;
  compact?: boolean;
  onItemStatus?: (orderId: number, item: DeliveryOrderItem, status: DeliveryItemStatus) => void;
  onOrderStatus?: (orderId: number, status: string) => void;
};

function MetricLine({ icon, label, value }: { icon: React.ReactNode; label: string; value: React.ReactNode }) {
  return (
    <Stack direction="row" spacing={1} alignItems="center" sx={{ color: "text.secondary" }}>
      <Box sx={{ display: "grid", placeItems: "center", color: "#475569" }}>{icon}</Box>
      <Typography variant="body2"><strong>{label}:</strong> {value}</Typography>
    </Stack>
  );
}

export default function OrderCard({ order, mode, shipperName, compact = false, onItemStatus, onOrderStatus }: Props) {
  const percent = orderProgress(order);
  const itemCount = (order.items || []).reduce((sum, item) => sum + item.quantity, 0);
  const deliveredCount = (order.items || []).reduce((sum, item) => sum + item.delivered_quantity, 0);

  return (
    <Card sx={{ borderRadius: 3.5, border: "1px solid #e2e8f0", boxShadow: "0 16px 38px rgba(15, 23, 42, 0.07)", overflow: "hidden" }}>
      <Box sx={{ height: 5, bgcolor: order.status === "PENDING" ? "#2563eb" : order.status === "DELIVERED" ? "#16a34a" : ["FAILED", "RETURNED", "CANCELLED"].includes(order.status) ? "#dc2626" : "#f59e0b" }} />
      <CardContent sx={{ p: compact ? 2 : 3 }}>
        <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" gap={2}>
          <Box sx={{ minWidth: 0 }}>
            <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
              <Typography variant="h6" fontWeight={950}>{order.order_code}</Typography>
              <StatusChip status={order.status} size="small" />
            </Stack>
            <Typography color="text.secondary" sx={{ mt: 0.4 }}>{order.customer_name} · {order.customer_phone}</Typography>
            <Stack spacing={0.7} sx={{ mt: 1.4 }}>
              <MetricLine icon={<LocationOnRoundedIcon fontSize="small" />} label="Pickup" value={shortAddress(order.pickup_address)} />
              <MetricLine icon={<AssignmentTurnedInRoundedIcon fontSize="small" />} label="Drop-off" value={shortAddress(order.delivery_address)} />
            </Stack>
          </Box>

          <Stack alignItems={{ xs: "stretch", md: "flex-end" }} spacing={1.1} minWidth={{ md: 255 }}>
            <MetricLine icon={<PaymentsRoundedIcon fontSize="small" />} label="COD" value={formatMoney(order.cod_amount)} />
            <MetricLine icon={<Inventory2RoundedIcon fontSize="small" />} label="Items" value={`${deliveredCount}/${itemCount} delivered`} />
            <MetricLine icon={<CallRoundedIcon fontSize="small" />} label="Shipper" value={shipperName || (order.shipper_id ? `#${order.shipper_id}` : "Unassigned")} />
            {mode === "shipper" && onOrderStatus && (
              <Stack direction="row" spacing={1} justifyContent={{ xs: "flex-start", md: "flex-end" }} flexWrap="wrap" sx={{ pt: 0.4 }}>
                <Button size="small" variant="outlined" onClick={() => onOrderStatus(order.id, "PICKED_UP")}>Picked up</Button>
                <Button size="small" variant="outlined" onClick={() => onOrderStatus(order.id, "IN_TRANSIT")}>On route</Button>
                <Button size="small" variant="contained" color="success" onClick={() => onOrderStatus(order.id, "DELIVERED")}>Complete</Button>
                <Button size="small" color="error" onClick={() => onOrderStatus(order.id, "FAILED")}>Fail</Button>
              </Stack>
            )}
          </Stack>
        </Stack>

        <Box sx={{ mt: 2.2 }}>
          <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 0.7 }}>
            <Typography fontWeight={900}>Fulfillment progress</Typography>
            <Typography color="text.secondary" fontWeight={800}>{percent}%</Typography>
          </Stack>
          <LinearProgress variant="determinate" value={percent} sx={{ height: 9, borderRadius: 999, bgcolor: "#e2e8f0" }} />
        </Box>

        {!compact && (
          <>
            <Divider sx={{ my: 2 }} />
            <Grid container spacing={1.5}>
              {(order.items || []).map((item) => (
                <Grid item xs={12} md={6} key={item.id}>
                  <Box sx={{ border: "1px solid #e2e8f0", borderRadius: 3, p: 1.7, bgcolor: "#ffffff" }}>
                    <Stack direction="row" justifyContent="space-between" gap={1}>
                      <Box sx={{ minWidth: 0 }}>
                        <Tooltip title={item.name}>
                          <Typography fontWeight={950} noWrap>{item.name}</Typography>
                        </Tooltip>
                        <Typography variant="caption" color="text.secondary">
                          {item.sku || "No SKU"} · Qty {item.quantity} · {formatMoney(item.unit_price)} · {item.weight_kg || 0} kg
                        </Typography>
                      </Box>
                      <StatusChip status={item.status} />
                    </Stack>
                    {item.note && <Typography variant="caption" color="text.secondary" sx={{ display: "block", mt: 1 }}>Note: {item.note}</Typography>}
                    {onItemStatus && (
                      <Stack direction="row" spacing={1} flexWrap="wrap" sx={{ mt: 1.5 }}>
                        <Button size="small" variant="outlined" onClick={() => onItemStatus(order.id, item, "PICKED_UP")}>Picked</Button>
                        <Button size="small" variant="outlined" onClick={() => onItemStatus(order.id, item, "IN_TRANSIT")}>Transit</Button>
                        <Button size="small" variant="contained" color="success" onClick={() => onItemStatus(order.id, item, "DELIVERED")}>Delivered</Button>
                        <Button size="small" variant="outlined" color="error" onClick={() => onItemStatus(order.id, item, "FAILED")}>Failed</Button>
                      </Stack>
                    )}
                  </Box>
                </Grid>
              ))}
            </Grid>
          </>
        )}
      </CardContent>
    </Card>
  );
}
