"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import { Box, CircularProgress, Typography } from "@mui/material";
import { useAuth } from "../../context/AuthContext";
import type { AuthUser } from "../../lib/api";

export default function RequireAuth({ roles, children }: { roles?: AuthUser["role"][]; children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (loading) return;
    if (!user) router.replace(`/login?next=${encodeURIComponent(pathname || "/admin/dashboard")}`);
    else if (roles?.length && !roles.includes(user.role)) router.replace(user.role === "SHIPPER" ? "/shipper/home" : "/admin/dashboard");
  }, [loading, user, roles, router, pathname]);

  if (loading || !user || (roles?.length && !roles.includes(user.role))) {
    return (
      <Box sx={{ minHeight: "100vh", display: "grid", placeItems: "center" }}>
        <Box textAlign="center"><CircularProgress /><Typography sx={{ mt: 2 }}>Checking secure session...</Typography></Box>
      </Box>
    );
  }
  return <>{children}</>;
}
