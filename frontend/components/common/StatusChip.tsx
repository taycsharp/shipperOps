"use client";

import { Chip } from "@mui/material";
import { statusLabel } from "../../lib/operations";

type Props = {
  status: string;
  size?: "small" | "medium";
};

function color(status: string) {
  if (["DELIVERED", "AVAILABLE"].includes(status)) return "success" as const;
  if (["FAILED", "RETURNED", "CANCELLED", "SUSPENDED"].includes(status)) return "error" as const;
  if (["ASSIGNED", "PICKED_UP", "IN_TRANSIT", "BUSY"].includes(status)) return "warning" as const;
  if (status === "OFFLINE") return "default" as const;
  return "info" as const;
}

export default function StatusChip({ status, size = "small" }: Props) {
  return (
    <Chip
      label={statusLabel(status)}
      color={color(status)}
      size={size}
      sx={{
        fontWeight: 900,
        borderRadius: 2,
        letterSpacing: 0.15,
      }}
    />
  );
}
