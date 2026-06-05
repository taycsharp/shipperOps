"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Grid,
  Stack,
  Typography,
} from "@mui/material";
import { apiGet, apiPost } from "../../../lib/api";
import type { Shipper, ShipperStatus } from "../../../types/delivery";

type SimStatus = Extract<ShipperStatus, "AVAILABLE" | "BUSY" | "OFFLINE">;

type DemoProfile = {
  name: string;
  plate: string;
  status: SimStatus;
  path: [number, number][]; // [lat, lng]
};

type DemoShipper = DemoProfile & {
  id: number;
};

type RuntimeState = Record<number, { index: number; running: boolean; lat: number; lng: number; lastSent?: string }>;

const demoProfiles: DemoProfile[] = [
  {
    name: "Shipper One",
    plate: "59-A1 12345",
    status: "AVAILABLE",
    path: [
      [10.69971, 106.73121],
      [10.7045, 106.7296],
      [10.7122, 106.7247],
      [10.7295, 106.7218],
      [10.7428, 106.7135],
    ],
  },
  {
    name: "Shipper Two",
    plate: "59-B2 23456",
    status: "BUSY",
    path: [
      [10.7721, 106.6983],
      [10.7769, 106.7009],
      [10.7814, 106.7045],
      [10.7928, 106.6907],
      [10.8012, 106.7118],
    ],
  },
  {
    name: "Shipper Three",
    plate: "59-C3 34567",
    status: "AVAILABLE",
    path: [
      [10.7952, 106.7218],
      [10.8012, 106.7118],
      [10.8102, 106.7038],
      [10.8224, 106.6891],
      [10.8353, 106.6758],
    ],
  },
  {
    name: "Shipper Four",
    plate: "59-D4 45678",
    status: "BUSY",
    path: [
      [10.85, 106.77],
      [10.8415, 106.7592],
      [10.829, 106.7482],
      [10.8165, 106.739],
      [10.8012, 106.7118],
    ],
  },
  {
    name: "Shipper Five",
    plate: "59-E5 56789",
    status: "AVAILABLE",
    path: [
      [10.7626, 106.6822],
      [10.7592, 106.6902],
      [10.7554, 106.7012],
      [10.7481, 106.7114],
      [10.7428, 106.7135],
    ],
  },
  {
    name: "Shipper Six",
    plate: "59-F6 67890",
    status: "OFFLINE",
    path: [
      [10.846, 106.642],
      [10.832, 106.654],
      [10.817, 106.666],
      [10.802, 106.678],
      [10.7928, 106.6907],
    ],
  },
];

function initialState(shippers: DemoShipper[]): RuntimeState {
  return Object.fromEntries(
    shippers.map((shipper) => [
      shipper.id,
      {
        index: 0,
        running: false,
        lat: shipper.path[0][0],
        lng: shipper.path[0][1],
      },
    ])
  );
}

function normalizeStatus(status: ShipperStatus | undefined, fallback: SimStatus): SimStatus {
  if (status === "AVAILABLE" || status === "BUSY" || status === "OFFLINE") return status;
  return fallback;
}

function buildDemoShippers(apiShippers: Shipper[]): DemoShipper[] {
  return apiShippers.slice(0, demoProfiles.length).map((shipper, index) => {
    const profile = demoProfiles[index];
    return {
      ...profile,
      id: shipper.id,
      name: shipper.user?.name || profile.name,
      plate: shipper.vehicle_plate || profile.plate,
      status: normalizeStatus(shipper.status, profile.status),
    };
  });
}

function getErrorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Unknown error";
}

export default function MultiShipperSimulatorPage() {
  const [demoShippers, setDemoShippers] = useState<DemoShipper[]>([]);
  const [state, setState] = useState<RuntimeState>({});
  const [message, setMessage] = useState("Loading shippers from API...");
  const timerRef = useRef<number | null>(null);
  const stateRef = useRef<RuntimeState>({});
  const shippersRef = useRef<DemoShipper[]>([]);

  const runningCount = useMemo(() => Object.values(state).filter((item) => item.running).length, [state]);

  function setRuntime(next: RuntimeState) {
    stateRef.current = next;
    setState(next);
  }

  async function loadDemoShippers() {
    try {
      const apiShippers = await apiGet<Shipper[]>("/shippers");
      const nextShippers = buildDemoShippers(apiShippers);
      shippersRef.current = nextShippers;
      setDemoShippers(nextShippers);
      const nextState = initialState(nextShippers);
      setRuntime(nextState);

      if (nextShippers.length === 0) {
        setMessage("No shippers found. Run seed first: docker compose --env-file .env.production -f docker-compose.prod.yml exec backend python -m app.seed");
      } else {
        setMessage(`Ready. Loaded ${nextShippers.length} shippers from API. Open the admin live map in another tab, then start simulation.`);
      }
    } catch (error) {
      setMessage(`Could not load shippers: ${getErrorMessage(error)}`);
    }
  }

  async function runAction(action: () => Promise<void>) {
    try {
      await action();
    } catch (error) {
      setMessage(`Simulator error: ${getErrorMessage(error)}`);
    }
  }

  async function updateStatus(shipper: DemoShipper, status: SimStatus) {
    await apiPost(`/shippers/${shipper.id}/status`, { status });
  }

  async function sendLocation(shipper: DemoShipper, indexOverride?: number) {
    const current = stateRef.current[shipper.id];
    if (!current) throw new Error(`Runtime state missing for shipper #${shipper.id}`);

    const nextIndex = indexOverride ?? ((current.index + 1) % shipper.path.length);
    const [lat, lng] = shipper.path[nextIndex];

    await apiPost("/locations/update", {
      shipper_id: shipper.id,
      lat,
      lng,
      speed: current.running ? 25 + shipper.id * 3 : 0,
      heading: 80 + shipper.id * 15,
      battery: Math.max(30, 95 - shipper.id * 7),
    });

    const nextState = {
      ...stateRef.current,
      [shipper.id]: {
        ...current,
        index: nextIndex,
        lat,
        lng,
        lastSent: new Date().toLocaleTimeString(),
      },
    };
    setRuntime(nextState);
    setMessage(`Sent ${shipper.name} (#${shipper.id}): ${lat.toFixed(5)}, ${lng.toFixed(5)}`);
  }

  async function stepAll() {
    for (const shipper of shippersRef.current) {
      await sendLocation(shipper);
    }
  }

  async function startOne(shipper: DemoShipper) {
    await updateStatus(shipper, shipper.status === "OFFLINE" ? "AVAILABLE" : shipper.status);
    setRuntime({
      ...stateRef.current,
      [shipper.id]: { ...stateRef.current[shipper.id], running: true },
    });
    await sendLocation(shipper, stateRef.current[shipper.id].index);
  }

  async function stopOne(shipper: DemoShipper) {
    await updateStatus(shipper, "OFFLINE");
    setRuntime({
      ...stateRef.current,
      [shipper.id]: { ...stateRef.current[shipper.id], running: false },
    });
    setMessage(`${shipper.name} stopped.`);
  }

  async function startAll() {
    for (const shipper of shippersRef.current) {
      await startOne(shipper);
    }
    setMessage("Multi-shipper simulation started. Admin map should update every 2 seconds.");
  }

  async function stopAll() {
    for (const shipper of shippersRef.current) {
      await stopOne(shipper);
    }
    setMessage("All demo shippers stopped and set to OFFLINE.");
  }

  useEffect(() => {
    void loadDemoShippers();
  }, []);

  useEffect(() => {
    timerRef.current = window.setInterval(async () => {
      const runningIds = Object.entries(stateRef.current)
        .filter(([, value]) => value.running)
        .map(([id]) => Number(id));

      if (runningIds.length === 0) return;

      for (const shipper of shippersRef.current.filter((item) => runningIds.includes(item.id))) {
        try {
          await sendLocation(shipper);
        } catch (error) {
          setMessage(`Failed to send location for ${shipper.name}: ${getErrorMessage(error)}`);
        }
      }
    }, 2000);

    return () => {
      if (timerRef.current) window.clearInterval(timerRef.current);
    };
  }, []);

  return (
    <Box sx={{ minHeight: "100vh", p: { xs: 2, md: 4 }, bgcolor: "#f4f6f8" }}>
      <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" spacing={2} sx={{ mb: 3 }}>
        <Box>
          <Typography variant="h4" fontWeight={900}>Multi-Shipper Simulator</Typography>
          <Typography color="text.secondary">Simulate existing shippers moving around HCM City without phone GPS.</Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button component={Link} href="/admin/map" variant="contained">Open Live Map</Button>
          <Button component={Link} href="/shipper/home" variant="outlined">Single Shipper</Button>
        </Stack>
      </Stack>

      <Card sx={{ borderRadius: 4, boxShadow: 3, mb: 3 }}>
        <CardContent>
          <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" alignItems={{ xs: "flex-start", md: "center" }} spacing={2}>
            <Box>
              <Typography variant="h6" fontWeight={900}>Control Panel</Typography>
              <Typography color="text.secondary">Running: {runningCount} / {demoShippers.length} shippers</Typography>
            </Box>
            <Stack direction="row" spacing={1} flexWrap="wrap">
              <Button variant="contained" color="success" disabled={demoShippers.length === 0} onClick={() => void runAction(startAll)}>Start All</Button>
              <Button variant="contained" disabled={demoShippers.length === 0} onClick={() => void runAction(stepAll)}>Send One Step</Button>
              <Button variant="contained" color="error" disabled={demoShippers.length === 0} onClick={() => void runAction(stopAll)}>Stop All</Button>
              <Button variant="outlined" onClick={() => void loadDemoShippers()}>Reload Shippers</Button>
            </Stack>
          </Stack>
          <Alert severity={demoShippers.length === 0 ? "warning" : "info"} sx={{ mt: 2 }}>{message}</Alert>
        </CardContent>
      </Card>

      <Grid container spacing={2}>
        {demoShippers.map((shipper) => {
          const runtime = state[shipper.id];
          if (!runtime) return null;
          return (
            <Grid item xs={12} md={6} lg={4} key={shipper.id}>
              <Card sx={{ borderRadius: 4, boxShadow: 2, height: "100%" }}>
                <CardContent>
                  <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                    <Box>
                      <Typography fontWeight={900}>{shipper.name}</Typography>
                      <Typography variant="body2" color="text.secondary">ID #{shipper.id} · {shipper.plate}</Typography>
                    </Box>
                    <Chip label={runtime.running ? "MOVING" : "STOPPED"} color={runtime.running ? "success" : "default"} />
                  </Stack>

                  <Typography variant="body2" sx={{ mt: 1 }}>
                    GPS: {runtime.lat.toFixed(5)}, {runtime.lng.toFixed(5)}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Path step: {runtime.index + 1} / {shipper.path.length} · Last sent: {runtime.lastSent || "-"}
                  </Typography>

                  <Stack direction="row" spacing={1} sx={{ mt: 2 }} flexWrap="wrap">
                    {!runtime.running ? (
                      <Button size="small" variant="contained" color="success" onClick={() => void runAction(() => startOne(shipper))}>Start</Button>
                    ) : (
                      <Button size="small" variant="contained" color="error" onClick={() => void runAction(() => stopOne(shipper))}>Stop</Button>
                    )}
                    <Button size="small" variant="outlined" onClick={() => void runAction(() => sendLocation(shipper))}>Step</Button>
                    <Button size="small" variant="outlined" onClick={() => void runAction(() => updateStatus(shipper, "AVAILABLE"))}>Available</Button>
                    <Button size="small" variant="outlined" onClick={() => void runAction(() => updateStatus(shipper, "BUSY"))}>Busy</Button>
                    <Button size="small" variant="outlined" onClick={() => void runAction(() => updateStatus(shipper, "OFFLINE"))}>Offline</Button>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
}
