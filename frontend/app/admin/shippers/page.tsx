export const dynamic = "force-dynamic";

import Link from "next/link";
import BatteryChargingFullRoundedIcon from "@mui/icons-material/BatteryChargingFullRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import MyLocationRoundedIcon from "@mui/icons-material/MyLocationRounded";
import PersonRoundedIcon from "@mui/icons-material/PersonRounded";
import PhoneRoundedIcon from "@mui/icons-material/PhoneRounded";
import { Box, Button, Card, CardContent, Grid, LinearProgress, Stack, Typography } from "@mui/material";

import StatCard from "../../../components/common/StatCard";
import StatusChip from "../../../components/common/StatusChip";
import AppShell from "../../../components/layout/AppShell";
import { cookies } from "next/headers";
import { API_SERVER_URL } from "../../../lib/api";
import { lastSeenLabel, shipperName } from "../../../lib/operations";
import type { Shipper } from "../../../types/delivery";

async function getShippers(): Promise<Shipper[]> {
  try {
    const token = (await cookies()).get("shipops_token")?.value;
    const headers = token ? { Authorization: `Bearer ${token}` } : undefined;
    const res = await fetch(`${API_SERVER_URL}/shippers`, { cache: "no-store", headers });
    if (!res.ok) return [];
    const data = await res.json();
    return Array.isArray(data.items) ? data.items : data;
  } catch {
    return [];
  }
}

function signalScore(shipper: Shipper) {
  if (!shipper.current_lat || !shipper.current_lng) return 0;
  if (!shipper.last_seen_at) return 55;
  const seconds = Math.max(0, Math.round((Date.now() - new Date(shipper.last_seen_at).getTime()) / 1000));
  if (seconds < 60) return 100;
  if (seconds < 300) return 78;
  if (seconds < 1200) return 48;
  return 24;
}

export default async function ShippersPage() {
  const shippers = await getShippers();
  const available = shippers.filter((shipper) => shipper.status === "AVAILABLE").length;
  const busy = shippers.filter((shipper) => shipper.status === "BUSY").length;
  const offline = shippers.filter((shipper) => shipper.status === "OFFLINE").length;
  const gpsReady = shippers.filter((shipper) => shipper.current_lat && shipper.current_lng).length;

  return (
    <AppShell
      title="Fleet Management"
      subtitle="Realistic shipper roster with vehicle details, current duty status, GPS readiness, and last-seen indicators."
      actions={
        <Stack direction="row" spacing={1}>
          <Button component={Link} href="/admin/map" variant="contained">Open Live Map</Button>
          <Button component={Link} href="/shipper/simulator" variant="outlined">Simulator</Button>
        </Stack>
      }
    >
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={6} md={3}><StatCard label="Total shippers" value={shippers.length} helper="Registered fleet" icon={<PersonRoundedIcon />} accent="#2563eb" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Available" value={available} helper={`${busy} busy now`} icon={<LocalShippingRoundedIcon />} accent="#16a34a" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="GPS ready" value={`${gpsReady}/${shippers.length}`} helper="Has latest location" icon={<MyLocationRoundedIcon />} accent="#f59e0b" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Offline" value={offline} helper="Need follow up" icon={<BatteryChargingFullRoundedIcon />} accent="#64748b" /></Grid>
      </Grid>

      <Grid container spacing={2}>
        {shippers.map((shipper) => {
          const signal = signalScore(shipper);
          return (
            <Grid item xs={12} md={6} xl={4} key={shipper.id}>
              <Card sx={{ borderRadius: 3.5, height: "100%", border: "1px solid #e2e8f0", boxShadow: "0 16px 38px rgba(15, 23, 42, 0.07)" }}>
                <CardContent sx={{ p: 2.4 }}>
                  <Stack direction="row" justifyContent="space-between" alignItems="flex-start" gap={2}>
                    <Box sx={{ minWidth: 0 }}>
                      <Typography variant="h6" fontWeight={950} noWrap>{shipperName(shipper)}</Typography>
                      <Stack direction="row" spacing={1} alignItems="center" sx={{ color: "text.secondary", mt: 0.4 }}>
                        <PhoneRoundedIcon fontSize="small" />
                        <Typography variant="body2">{shipper.user?.phone || "No phone"}</Typography>
                      </Stack>
                    </Box>
                    <StatusChip status={shipper.status} />
                  </Stack>

                  <Box sx={{ mt: 2, p: 1.5, borderRadius: 3, bgcolor: "#f8fafc", border: "1px solid #e2e8f0" }}>
                    <Grid container spacing={1.5}>
                      <Grid item xs={6}>
                        <Typography variant="caption" color="text.secondary">Vehicle</Typography>
                        <Typography fontWeight={900}>{shipper.vehicle_type || "—"}</Typography>
                      </Grid>
                      <Grid item xs={6}>
                        <Typography variant="caption" color="text.secondary">Plate</Typography>
                        <Typography fontWeight={900}>{shipper.vehicle_plate || "—"}</Typography>
                      </Grid>
                      <Grid item xs={12}>
                        <Typography variant="caption" color="text.secondary">GPS</Typography>
                        <Typography fontWeight={900}>
                          {shipper.current_lat && shipper.current_lng ? `${shipper.current_lat.toFixed(5)}, ${shipper.current_lng.toFixed(5)}` : "No location yet"}
                        </Typography>
                      </Grid>
                    </Grid>
                  </Box>

                  <Box sx={{ mt: 2 }}>
                    <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.7 }}>
                      <Typography fontWeight={850}>Signal freshness</Typography>
                      <Typography color="text.secondary">{lastSeenLabel(shipper.last_seen_at)}</Typography>
                    </Stack>
                    <LinearProgress variant="determinate" value={signal} color={signal > 70 ? "success" : signal > 40 ? "warning" : "error"} sx={{ height: 8, borderRadius: 999 }} />
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </AppShell>
  );
}
