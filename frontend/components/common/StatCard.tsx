import type { ReactNode } from "react";
import { Box, Card, CardContent, Stack, Typography } from "@mui/material";

type Props = {
  label: string;
  value: string | number;
  helper?: string;
  icon?: ReactNode;
  accent?: string;
};

export default function StatCard({ label, value, helper, icon, accent = "#2563eb" }: Props) {
  return (
    <Card
      sx={{
        borderRadius: 3,
        border: "1px solid #e2e8f0",
        boxShadow: "0 16px 40px rgba(15, 23, 42, 0.06)",
        height: "100%",
        overflow: "hidden",
        position: "relative",
      }}
    >
      <Box sx={{ position: "absolute", inset: "0 auto auto 0", width: 5, height: "100%", bgcolor: accent }} />
      <CardContent sx={{ p: 2.4, pl: 3 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={2}>
          <Box>
            <Typography color="text.secondary" fontWeight={800} fontSize={13}>{label}</Typography>
            <Typography variant="h4" fontWeight={950} sx={{ mt: 0.6, letterSpacing: -0.8 }}>{value}</Typography>
            {helper && <Typography variant="body2" color="text.secondary" sx={{ mt: 0.3 }}>{helper}</Typography>}
          </Box>
          {icon && (
            <Box sx={{ width: 42, height: 42, borderRadius: 2.5, bgcolor: `${accent}14`, color: accent, display: "grid", placeItems: "center" }}>
              {icon}
            </Box>
          )}
        </Stack>
      </CardContent>
    </Card>
  );
}
