"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import AddRoundedIcon from "@mui/icons-material/AddRounded";
import BatteryChargingFullRoundedIcon from "@mui/icons-material/BatteryChargingFullRounded";
import DeleteRoundedIcon from "@mui/icons-material/DeleteRounded";
import EditRoundedIcon from "@mui/icons-material/EditRounded";
import LinkRoundedIcon from "@mui/icons-material/LinkRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import MyLocationRoundedIcon from "@mui/icons-material/MyLocationRounded";
import PersonRoundedIcon from "@mui/icons-material/PersonRounded";
import PhoneRoundedIcon from "@mui/icons-material/PhoneRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  LinearProgress,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from "@mui/material";

import StatCard from "../../../components/common/StatCard";
import StatusChip from "../../../components/common/StatusChip";
import AppShell from "../../../components/layout/AppShell";
import { apiDelete, apiGet, apiPost, apiPut, type AuthUser } from "../../../lib/api";
import { lastSeenLabel, shipperName } from "../../../lib/operations";
import type { Shipper, ShipperStatus } from "../../../types/delivery";

type StatusFilter = ShipperStatus | "ALL";
type DialogMode = "create" | "edit";
type ShipperForm = {
  name: string;
  email: string;
  phone: string;
  password: string;
  userId: string;
  vehicleType: string;
  vehiclePlate: string;
  status: ShipperStatus;
};

const statusFilters: StatusFilter[] = ["ALL", "AVAILABLE", "BUSY", "OFFLINE", "SUSPENDED"];
const emptyForm: ShipperForm = { name: "", email: "", phone: "", password: "", userId: "", vehicleType: "", vehiclePlate: "", status: "OFFLINE" };

function signalScore(shipper: Shipper) {
  if (!shipper.current_lat || !shipper.current_lng) return 0;
  if (!shipper.last_seen_at) return 55;
  const seconds = Math.max(0, Math.round((Date.now() - new Date(shipper.last_seen_at).getTime()) / 1000));
  if (seconds < 60) return 100;
  if (seconds < 300) return 78;
  if (seconds < 1200) return 48;
  return 24;
}

function gpsValue(shipper: Shipper) {
  return shipper.current_lat && shipper.current_lng ? `${shipper.current_lat.toFixed(5)}, ${shipper.current_lng.toFixed(5)}` : "No location yet";
}

function toForm(shipper?: Shipper): ShipperForm {
  if (!shipper) return emptyForm;
  return {
    name: shipper.user?.name || "",
    email: shipper.user?.email || "",
    phone: shipper.user?.phone || "",
    password: "",
    userId: String(shipper.user_id),
    vehicleType: shipper.vehicle_type || "",
    vehiclePlate: shipper.vehicle_plate || "",
    status: shipper.status,
  };
}

export default function ShippersPage() {
  const [shippers, setShippers] = useState<Shipper[]>([]);
  const [users, setUsers] = useState<AuthUser[]>([]);
  const [message, setMessage] = useState("Loading shippers...");
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<StatusFilter>("ALL");
  const [mode, setMode] = useState<DialogMode>("create");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Shipper | null>(null);
  const [form, setForm] = useState<ShipperForm>(emptyForm);
  const [useExistingAccount, setUseExistingAccount] = useState(false);

  const loadData = useCallback(async () => {
    try {
      const params = new URLSearchParams();
      if (search.trim()) params.set("search", search.trim());
      if (status !== "ALL") params.set("status", status);
      const [shipperData, userData] = await Promise.all([
        apiGet<Shipper[]>(`/shippers${params.toString() ? `?${params}` : ""}`),
        apiGet<AuthUser[]>("/auth/users?role=SHIPPER"),
      ]);
      setShippers(shipperData);
      setUsers(userData);
      setMessage(`Loaded ${shipperData.length} shippers`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not load shippers");
    }
  }, [search, status]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadData(), 250);
    return () => window.clearTimeout(timer);
  }, [loadData]);

  const summary = useMemo(() => {
    const available = shippers.filter((shipper) => shipper.status === "AVAILABLE").length;
    const busy = shippers.filter((shipper) => shipper.status === "BUSY").length;
    const offline = shippers.filter((shipper) => shipper.status === "OFFLINE").length;
    const suspended = shippers.filter((shipper) => shipper.status === "SUSPENDED").length;
    const gpsReady = shippers.filter((shipper) => shipper.current_lat && shipper.current_lng).length;
    const activeOrders = shippers.reduce((total, shipper) => total + (shipper.active_order_count || 0), 0);
    return { available, busy, offline, suspended, gpsReady, activeOrders };
  }, [shippers]);

  function openCreate() {
    setMode("create");
    setEditing(null);
    setForm(emptyForm);
    setUseExistingAccount(false);
    setDialogOpen(true);
  }

  function openEdit(shipper: Shipper) {
    setMode("edit");
    setEditing(shipper);
    setForm(toForm(shipper));
    setUseExistingAccount(false);
    setDialogOpen(true);
  }

  async function submitForm() {
    try {
      if (mode === "create") {
        const account = useExistingAccount
          ? { user_id: Number(form.userId) }
          : { user: { name: form.name, email: form.email, phone: form.phone || null, password: form.password } };
        await apiPost<Shipper>("/shippers", { ...account, vehicle_type: form.vehicleType || null, vehicle_plate: form.vehiclePlate || null, status: form.status });
      } else if (editing) {
        await apiPut<Shipper>(`/shippers/${editing.id}`, {
          user: { name: form.name, email: form.email, phone: form.phone || null },
          vehicle_type: form.vehicleType || null,
          vehicle_plate: form.vehiclePlate || null,
          status: form.status,
        });
      }
      setDialogOpen(false);
      await loadData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save shipper");
    }
  }

  async function linkAccount(shipper: Shipper) {
    const userId = window.prompt("Enter the SHIPPER login account ID to link", String(shipper.user_id));
    if (!userId) return;
    try {
      await apiPost<Shipper>(`/shippers/${shipper.id}/link-account`, { user_id: Number(userId) });
      await loadData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not link account");
    }
  }

  async function setActive(shipper: Shipper, active: boolean) {
    try {
      await apiPost<Shipper>(`/shippers/${shipper.id}/${active ? "activate" : "deactivate"}`, {});
      await loadData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not update activation");
    }
  }

  async function removeShipper(shipper: Shipper) {
    if (!window.confirm(`Delete ${shipperName(shipper)}? Shippers with active orders cannot be deleted.`)) return;
    try {
      await apiDelete(`/shippers/${shipper.id}`);
      await loadData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not delete shipper");
    }
  }

  return (
    <AppShell
      title="Shipper Administration"
      subtitle="Manage real shipper login links, activation state, vehicle details, active workload, online status, and last GPS updates."
      actions={
        <Stack direction="row" spacing={1} flexWrap="wrap">
          <Button component={Link} href="/admin/map" variant="outlined">Open Live Map</Button>
          <Button variant="contained" startIcon={<AddRoundedIcon />} onClick={openCreate}>Create shipper</Button>
        </Stack>
      }
    >
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={6} md={3}><StatCard label="Total shippers" value={shippers.length} helper={`${summary.suspended} deactivated`} icon={<PersonRoundedIcon />} accent="#2563eb" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Online" value={summary.available + summary.busy} helper={`${summary.available} available · ${summary.busy} busy`} icon={<LocalShippingRoundedIcon />} accent="#16a34a" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="GPS ready" value={`${summary.gpsReady}/${shippers.length}`} helper="Latest location captured" icon={<MyLocationRoundedIcon />} accent="#f59e0b" /></Grid>
        <Grid item xs={6} md={3}><StatCard label="Active orders" value={summary.activeOrders} helper={`${summary.offline} offline shippers`} icon={<BatteryChargingFullRoundedIcon />} accent="#64748b" /></Grid>
      </Grid>

      <Card sx={{ borderRadius: 3.5, border: "1px solid #e2e8f0", mb: 3 }}>
        <CardContent>
          <Stack direction={{ xs: "column", md: "row" }} spacing={1.5} justifyContent="space-between">
            <TextField
              size="small"
              label="Search name, email, phone, vehicle, plate"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              sx={{ minWidth: { md: 420 } }}
              InputProps={{ startAdornment: <InputAdornment position="start"><SearchRoundedIcon fontSize="small" /></InputAdornment> }}
            />
            <FormControl size="small" sx={{ minWidth: 190 }}>
              <InputLabel>Status</InputLabel>
              <Select label="Status" value={status} onChange={(event) => setStatus(event.target.value as StatusFilter)}>
                {statusFilters.map((item) => <MenuItem key={item} value={item}>{item === "ALL" ? "All statuses" : item.replaceAll("_", " ")}</MenuItem>)}
              </Select>
            </FormControl>
          </Stack>
        </CardContent>
      </Card>

      <Alert severity={message.includes("Could") || message.includes("required") || message.includes("exists") ? "warning" : "info"} sx={{ mb: 3 }}>{message}</Alert>

      <Grid container spacing={2}>
        {shippers.map((shipper) => {
          const signal = signalScore(shipper);
          const active = shipper.status !== "SUSPENDED";
          return (
            <Grid item xs={12} md={6} xl={4} key={shipper.id}>
              <Card sx={{ borderRadius: 3.5, height: "100%", border: "1px solid #e2e8f0", boxShadow: "0 16px 38px rgba(15, 23, 42, 0.07)" }}>
                <CardContent sx={{ p: 2.4 }}>
                  <Stack direction="row" justifyContent="space-between" alignItems="flex-start" gap={2}>
                    <Box sx={{ minWidth: 0 }}>
                      <Typography variant="h6" fontWeight={950} noWrap>{shipperName(shipper)}</Typography>
                      <Typography variant="caption" color="text.secondary">Login #{shipper.user_id} · {shipper.user?.email}</Typography>
                      <Stack direction="row" spacing={1} alignItems="center" sx={{ color: "text.secondary", mt: 0.4 }}>
                        <PhoneRoundedIcon fontSize="small" />
                        <Typography variant="body2">{shipper.user?.phone || "No phone"}</Typography>
                      </Stack>
                    </Box>
                    <Stack alignItems="flex-end" spacing={0.7}>
                      <StatusChip status={shipper.status} />
                      <Chip size="small" label={active ? "Active" : "Deactivated"} color={active ? "success" : "default"} />
                    </Stack>
                  </Stack>

                  <Box sx={{ mt: 2, p: 1.5, borderRadius: 3, bgcolor: "#f8fafc", border: "1px solid #e2e8f0" }}>
                    <Grid container spacing={1.5}>
                      <Grid item xs={6}><Typography variant="caption" color="text.secondary">Vehicle</Typography><Typography fontWeight={900}>{shipper.vehicle_type || "—"}</Typography></Grid>
                      <Grid item xs={6}><Typography variant="caption" color="text.secondary">Plate</Typography><Typography fontWeight={900}>{shipper.vehicle_plate || "—"}</Typography></Grid>
                      <Grid item xs={6}><Typography variant="caption" color="text.secondary">Active orders</Typography><Typography fontWeight={900}>{shipper.active_order_count || 0}</Typography></Grid>
                      <Grid item xs={6}><Typography variant="caption" color="text.secondary">Last GPS</Typography><Typography fontWeight={900}>{lastSeenLabel(shipper.last_gps_update_at || shipper.last_seen_at)}</Typography></Grid>
                      <Grid item xs={12}><Typography variant="caption" color="text.secondary">GPS coordinates</Typography><Typography fontWeight={900}>{gpsValue(shipper)}</Typography></Grid>
                    </Grid>
                  </Box>

                  <Box sx={{ mt: 2 }}>
                    <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.7 }}>
                      <Typography fontWeight={850}>Signal freshness</Typography>
                      <Typography color="text.secondary">{lastSeenLabel(shipper.last_seen_at)}</Typography>
                    </Stack>
                    <LinearProgress variant="determinate" value={signal} color={signal > 70 ? "success" : signal > 40 ? "warning" : "error"} sx={{ height: 8, borderRadius: 999 }} />
                  </Box>

                  <Stack direction="row" spacing={1} justifyContent="space-between" sx={{ mt: 2 }}>
                    <Button size="small" startIcon={<EditRoundedIcon />} onClick={() => openEdit(shipper)}>Edit</Button>
                    <Button size="small" startIcon={<LinkRoundedIcon />} onClick={() => linkAccount(shipper)}>Link</Button>
                    <Button size="small" variant={active ? "outlined" : "contained"} onClick={() => setActive(shipper, !active)}>{active ? "Deactivate" : "Activate"}</Button>
                    <IconButton size="small" color="error" onClick={() => removeShipper(shipper)}><DeleteRoundedIcon fontSize="small" /></IconButton>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      {!shippers.length && <Alert severity="info" sx={{ mt: 3 }}>No shippers match this search and filter.</Alert>}

      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>{mode === "create" ? "Create shipper" : "Edit shipper"}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            {mode === "create" && (
              <FormControl size="small">
                <InputLabel>Login account mode</InputLabel>
                <Select label="Login account mode" value={useExistingAccount ? "existing" : "new"} onChange={(event) => setUseExistingAccount(event.target.value === "existing")}>
                  <MenuItem value="new">Create new SHIPPER login</MenuItem>
                  <MenuItem value="existing">Link existing SHIPPER login</MenuItem>
                </Select>
              </FormControl>
            )}
            {mode === "create" && useExistingAccount ? (
              <FormControl size="small">
                <InputLabel>Existing login</InputLabel>
                <Select label="Existing login" value={form.userId} onChange={(event) => setForm({ ...form, userId: event.target.value })}>
                  {users.map((user) => <MenuItem key={user.id} value={String(user.id)}>#{user.id} · {user.name} · {user.email}</MenuItem>)}
                </Select>
              </FormControl>
            ) : (
              <>
                <TextField size="small" label="Name" value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} />
                <TextField size="small" label="Email" value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} />
                <TextField size="small" label="Phone" value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} />
                {mode === "create" && <TextField size="small" label="Temporary password" type="password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} helperText="Minimum 8 characters for the shipper login." />}
              </>
            )}
            <TextField size="small" label="Vehicle information" value={form.vehicleType} onChange={(event) => setForm({ ...form, vehicleType: event.target.value })} placeholder="Motorbike, van, refrigerated truck" />
            <TextField size="small" label="Vehicle plate" value={form.vehiclePlate} onChange={(event) => setForm({ ...form, vehiclePlate: event.target.value.toUpperCase() })} />
            <FormControl size="small">
              <InputLabel>Status</InputLabel>
              <Select label="Status" value={form.status} onChange={(event) => setForm({ ...form, status: event.target.value as ShipperStatus })}>
                {statusFilters.filter((item): item is ShipperStatus => item !== "ALL").map((item) => <MenuItem key={item} value={item}>{item}</MenuItem>)}
              </Select>
            </FormControl>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button variant="contained" onClick={submitForm}>{mode === "create" ? "Create" : "Save"}</Button>
        </DialogActions>
      </Dialog>
    </AppShell>
  );
}
