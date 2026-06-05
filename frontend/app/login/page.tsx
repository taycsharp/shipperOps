"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import LockRoundedIcon from "@mui/icons-material/LockRounded";
import LocalShippingRoundedIcon from "@mui/icons-material/LocalShippingRounded";
import { Alert, Box, Button, Card, CardContent, InputAdornment, Stack, TextField, Typography } from "@mui/material";

import { login } from "../../lib/api";
import { useAuth } from "../../context/AuthContext";

export default function LoginPage() {
  const router = useRouter();
  const { refreshUser } = useAuth();
  const [email, setEmail] = useState("admin@shipops.local");
  const [password, setPassword] = useState("admin123");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError("");
    if (!email || !password) {
      setError("Please enter email and password.");
      return;
    }
    setLoading(true);
    try {
      await login(email.trim(), password);
      const user = await refreshUser();
      const next = new URLSearchParams(window.location.search).get("next");
      if (next) router.replace(next);
      else router.replace(user?.role === "SHIPPER" ? "/shipper/home" : "/admin/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Wrong email or password.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Box sx={{ minHeight: "100vh", display: "grid", placeItems: "center", bgcolor: "#eef3f8", p: 2 }}>
      <Card sx={{ width: "100%", maxWidth: 460, borderRadius: 4, boxShadow: "0 28px 80px rgba(15,23,42,.18)" }}>
        <CardContent sx={{ p: { xs: 3, md: 4 } }}>
          <Stack spacing={1.2} alignItems="center" sx={{ mb: 3 }}>
            <Box sx={{ width: 60, height: 60, borderRadius: 3, bgcolor: "#0b1220", color: "white", display: "grid", placeItems: "center" }}>
              <LocalShippingRoundedIcon fontSize="large" />
            </Box>
            <Typography variant="h4" fontWeight={950}>ShipOps Pro</Typography>
            <Typography color="text.secondary" textAlign="center">Secure logistics dashboard and shipper workflow</Typography>
          </Stack>

          {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

          <Stack component="form" spacing={2} onSubmit={onSubmit}>
            <TextField label="Email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} fullWidth autoFocus />
            <TextField
              label="Password"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              fullWidth
              InputProps={{ startAdornment: <InputAdornment position="start"><LockRoundedIcon fontSize="small" /></InputAdornment> }}
            />
            <Button type="submit" variant="contained" size="large" disabled={loading} sx={{ py: 1.2, borderRadius: 2.5, fontWeight: 900 }}>
              {loading ? "Signing in..." : "Sign in"}
            </Button>
          </Stack>

          <Alert severity="info" sx={{ mt: 3 }}>
            Demo seed usually includes admin@shipops.local / admin123, dispatcher@shipops.local / dispatcher123, and shipper accounts.
          </Alert>
        </CardContent>
      </Card>
    </Box>
  );
}
