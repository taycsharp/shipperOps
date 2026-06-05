"use client";

import { useEffect, useRef } from "react";
import { getToken, WS_URL } from "../lib/api";
import type { RealtimeMessage } from "../types/delivery";

export function useRealtime(onMessage: (message: RealtimeMessage) => void) {
  const handlerRef = useRef(onMessage);
  handlerRef.current = onMessage;

  useEffect(() => {
    const token = getToken();
    if (!token) return;
    const separator = WS_URL.includes("?") ? "&" : "?";
    const ws = new WebSocket(`${WS_URL}${separator}token=${encodeURIComponent(token)}`);
    ws.onmessage = (event) => {
      try {
        handlerRef.current(JSON.parse(event.data));
      } catch {
        // Ignore malformed development messages.
      }
    };
    return () => ws.close();
  }, []);
}
