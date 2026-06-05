"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import DashboardRoundedIcon from "@mui/icons-material/DashboardRounded";
import Inventory2RoundedIcon from "@mui/icons-material/Inventory2Rounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import MapRoundedIcon from "@mui/icons-material/MapRounded";
import PlayCircleRoundedIcon from "@mui/icons-material/PlayCircleRounded";
import PhoneIphoneRoundedIcon from "@mui/icons-material/PhoneIphoneRounded";
import { Box, Button, Chip, Divider, Stack, Typography } from "@mui/material";
import RequireAuth from "../auth/RequireAuth";
import { useAuth } from "../../context/AuthContext";

const nav = [
  { label: "Command Center", href: "/admin/dashboard", icon: <DashboardRoundedIcon fontSize="small" /> },
  { label: "Dispatch Board", href: "/admin/orders", icon: <Inventory2RoundedIcon fontSize="small" /> },
  { label: "Live Map", href: "/admin/map", icon: <MapRoundedIcon fontSize="small" /> },
  { label: "Fleet", href: "/admin/shippers", icon: <LocalShippingRoundedIcon fontSize="small" /> },
  { label: "Simulator", href: "/shipper/simulator", icon: <PlayCircleRoundedIcon fontSize="small" /> },
  { label: "Shipper App", href: "/shipper/home", icon: <PhoneIphoneRoundedIcon fontSize="small" /> },
];

type Props = {
  title: string;
  subtitle?: string;
  children: ReactNode;
  actions?: ReactNode;
};

export default function AppShell({ title, subtitle, children, actions }: Props) {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const roles = pathname?.startsWith("/shipper") ? (["SHIPPER", "ADMIN", "DISPATCHER"] as const) : (["ADMIN", "DISPATCHER"] as const);

  return (
    <RequireAuth roles={[...roles]}>
    <Box sx={{ minHeight: "100vh", bgcolor: "#eef3f8", display: "flex" }}>
      <Box
        component="aside"
        sx={{
          display: { xs: "none", lg: "flex" },
          flexDirection: "column",
          width: 278,
          p: 2,
          bgcolor: "#0b1220",
          color: "white",
          position: "sticky",
          top: 0,
          height: "100vh",
        }}
      >
        <Box sx={{ p: 1.5 }}>
          <Typography variant="h5" fontWeight={950} letterSpacing={-0.6}>ShipOps Pro</Typography>
          <Typography variant="body2" sx={{ opacity: 0.68, mt: 0.4 }}>Realtime shipper and order control</Typography>
          <Typography variant="caption" sx={{ opacity: 0.55 }}>Signed in as {user?.name || user?.email}</Typography>
        </Box>
        <Chip label="Production Cloudflare Tunnel" size="small" sx={{ mx: 1.5, mt: 1, bgcolor: "rgba(34,197,94,.12)", color: "#86efac", fontWeight: 800 }} />
        <Divider sx={{ my: 2, borderColor: "rgba(255,255,255,.09)" }} />
        <Stack spacing={0.8}>
          {nav.map((item) => {
            const active = pathname === item.href || pathname?.startsWith(`${item.href}/`);
            return (
              <Button
                key={item.href}
                component={Link}
                href={item.href}
                startIcon={item.icon}
                fullWidth
                sx={{
                  justifyContent: "flex-start",
                  borderRadius: 2.5,
                  px: 1.6,
                  py: 1.15,
                  color: active ? "#ffffff" : "rgba(255,255,255,.7)",
                  bgcolor: active ? "rgba(37,99,235,.95)" : "transparent",
                  textTransform: "none",
                  fontWeight: 850,
                  "&:hover": { bgcolor: active ? "rgba(37,99,235,1)" : "rgba(255,255,255,.08)" },
                }}
              >
                {item.label}
              </Button>
            );
          })}
        </Stack>
        <Box sx={{ mt: "auto", p: 1.5, borderRadius: 3, bgcolor: "rgba(255,255,255,.06)", border: "1px solid rgba(255,255,255,.08)" }}>
          <Typography fontWeight={900}>Operational rule</Typography>
          <Typography variant="caption" sx={{ opacity: 0.7 }}>Keep API, dashboard, and WebSocket behind Cloudflare. Do not expose PostgreSQL publicly.</Typography>
          <Button onClick={logout} size="small" sx={{ mt: 1, color: "white", borderColor: "rgba(255,255,255,.25)" }} variant="outlined">Logout</Button>
        </Box>
      </Box>

      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Box sx={{ display: { xs: "block", lg: "none" }, bgcolor: "#0b1220", color: "white", p: 2 }}>
          <Typography variant="h6" fontWeight={950}>ShipOps Pro</Typography>
          <Stack direction="row" spacing={1} sx={{ mt: 1, overflowX: "auto", pb: 0.5 }}>
            {nav.map((item) => (
              <Button key={item.href} component={Link} href={item.href} size="small" variant="outlined" sx={{ color: "white", borderColor: "rgba(255,255,255,.25)", whiteSpace: "nowrap" }}>
                {item.label}
              </Button>
            ))}
          </Stack>
        </Box>

        <Box component="main" sx={{ p: { xs: 2, md: 4 }, maxWidth: 1540, mx: "auto" }}>
          <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" alignItems={{ xs: "stretch", md: "flex-start" }} gap={2} sx={{ mb: 3 }}>
            <Box>
              <Typography variant="h3" fontWeight={950} letterSpacing={-1.2}>{title}</Typography>
              {subtitle && <Typography color="text.secondary" sx={{ mt: 0.5, maxWidth: 860 }}>{subtitle}</Typography>}
            </Box>
            {actions && <Box>{actions}</Box>}
          </Stack>
          {children}
        </Box>
      </Box>
    </Box>
    </RequireAuth>
  );
}
