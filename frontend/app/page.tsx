import Link from "next/link";
import DashboardRoundedIcon from "@mui/icons-material/DashboardRounded";
import Inventory2RoundedIcon from "@mui/icons-material/Inventory2Rounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import MapRoundedIcon from "@mui/icons-material/MapRounded";
import PlayCircleRoundedIcon from "@mui/icons-material/PlayCircleRounded";
import PhoneIphoneRoundedIcon from "@mui/icons-material/PhoneIphoneRounded";
import { Box, Button, Card, CardContent, Chip, Grid, Stack, Typography } from "@mui/material";

const entries = [
  { title: "Command Center", href: "/admin/dashboard", desc: "Executive operations view with KPIs, priority orders, COD exposure, and fleet health.", icon: <DashboardRoundedIcon /> },
  { title: "Dispatch Board", href: "/admin/orders", desc: "Assign orders, filter delivery lanes, update package status, and manage exceptions.", icon: <Inventory2RoundedIcon /> },
  { title: "Live Map", href: "/admin/map", desc: "Realtime shipper GPS with WebSocket updates through Cloudflare Tunnel.", icon: <MapRoundedIcon /> },
  { title: "Fleet", href: "/admin/shippers", desc: "Vehicle, status, signal freshness, last-seen GPS, and shipper roster.", icon: <LocalShippingRoundedIcon /> },
  { title: "Shipper Console", href: "/shipper/home", desc: "Mobile-like browser workflow for status, GPS, assigned orders, and item fulfillment.", icon: <PhoneIphoneRoundedIcon /> },
  { title: "Route Simulator", href: "/shipper/simulator", desc: "Generate realistic moving shippers for testing the map and dispatch workflow.", icon: <PlayCircleRoundedIcon /> },
];

export default function HomePage() {
  return (
    <Box sx={{ minHeight: "100vh", bgcolor: "#08111f", color: "white", p: { xs: 2, md: 6 }, position: "relative", overflow: "hidden" }}>
      <Box sx={{ position: "absolute", width: 560, height: 560, borderRadius: "50%", bgcolor: "rgba(37,99,235,.22)", filter: "blur(80px)", right: -160, top: -140 }} />
      <Box sx={{ position: "absolute", width: 420, height: 420, borderRadius: "50%", bgcolor: "rgba(22,163,74,.18)", filter: "blur(70px)", left: -120, bottom: -120 }} />
      <Stack spacing={4} sx={{ maxWidth: 1180, mx: "auto", position: "relative", zIndex: 1 }}>
        <Stack spacing={2} alignItems="flex-start" sx={{ maxWidth: 840 }}>
          <Chip label="Cloudflare + Docker production ready" sx={{ bgcolor: "rgba(134,239,172,.14)", color: "#86efac", fontWeight: 900 }} />
          <Typography variant="h2" fontWeight={950} letterSpacing={-2}>ShipOps Pro</Typography>
          <Typography variant="h5" sx={{ color: "rgba(255,255,255,.76)", lineHeight: 1.45 }}>
            Practical shipper-order management for dispatch teams: live GPS, order assignment, item-level tracking, COD monitoring, and a realistic simulator for testing.
          </Typography>
          <Stack direction="row" spacing={1.5} flexWrap="wrap">
            <Button component={Link} href="/admin/dashboard" size="large" variant="contained">Open Command Center</Button>
            <Button component={Link} href="/admin/orders" size="large" variant="outlined" sx={{ color: "white", borderColor: "rgba(255,255,255,.3)" }}>Dispatch Orders</Button>
          </Stack>
        </Stack>

        <Grid container spacing={2.2}>
          {entries.map((item) => (
            <Grid item xs={12} md={6} lg={4} key={item.href}>
              <Card sx={{ borderRadius: 4, height: "100%", bgcolor: "rgba(255,255,255,.96)", boxShadow: "0 24px 80px rgba(0,0,0,.25)" }}>
                <CardContent sx={{ p: 3 }}>
                  <Box sx={{ width: 52, height: 52, borderRadius: 3, bgcolor: "#eff6ff", color: "#2563eb", display: "grid", placeItems: "center", mb: 2 }}>
                    {item.icon}
                  </Box>
                  <Typography variant="h6" fontWeight={950}>{item.title}</Typography>
                  <Typography color="text.secondary" sx={{ my: 1.5, minHeight: 72 }}>{item.desc}</Typography>
                  <Button component={Link} href={item.href} variant="contained" fullWidth>Open</Button>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Stack>
    </Box>
  );
}
