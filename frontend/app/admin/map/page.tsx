import Link from "next/link";
import { Button, Stack } from "@mui/material";

import LiveMap from "../../../components/LiveMap";
import AppShell from "../../../components/layout/AppShell";

export default function AdminMapPage() {
  return (
    <AppShell
      title="Live Shipper Map"
      subtitle="Realtime GPS movement, status color, and local HCM PMTiles basemap."
      actions={
        <Stack direction="row" spacing={1}>
          <Button component={Link} href="/shipper/simulator" variant="contained" color="success">Simulator</Button>
          <Button component={Link} href="/admin/orders" variant="outlined">Orders</Button>
        </Stack>
      }
    >
      <LiveMap />
    </AppShell>
  );
}
