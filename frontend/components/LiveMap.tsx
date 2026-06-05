"use client";

import { useEffect, useRef, useState } from "react";
import maplibregl from "maplibre-gl";
import { Protocol } from "pmtiles";
import { layers, namedFlavor } from "@protomaps/basemaps";
import "maplibre-gl/dist/maplibre-gl.css";
import { API_URL, WS_URL, getToken } from "../lib/api";

type ShipperStatus = "AVAILABLE" | "BUSY" | "OFFLINE" | "SUSPENDED" | string;

type LiveShipper = {
  shipper_id: number;
  name?: string;
  phone?: string | null;
  vehicle_plate?: string | null;
  vehicle_type?: string | null;
  status?: ShipperStatus;
  lat?: number | null;
  lng?: number | null;
  speed?: number | null;
  heading?: number | null;
  battery?: number | null;
  last_seen_at?: string | null;
};

const HCM_CENTER: [number, number] = [106.660172, 10.762622];
const LOCAL_PMTILES_URL = process.env.NEXT_PUBLIC_PMTILES_URL || "/maps/hcm.pmtiles";
const MAP_MODE = process.env.NEXT_PUBLIC_MAP_MODE || "local";

let pmtilesProtocolReady = false;

function registerPmtilesProtocol() {
  if (pmtilesProtocolReady) return;
  const protocol = new Protocol();
  maplibregl.addProtocol("pmtiles", protocol.tile);
  pmtilesProtocolReady = true;
}

const onlineOsmStreetStyle: maplibregl.StyleSpecification = {
  version: 8,
  name: "Online OpenStreetMap Street",
  sources: {
    osm: {
      type: "raster",
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      tileSize: 256,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    },
  },
  layers: [
    {
      id: "osm-street-map",
      type: "raster",
      source: "osm",
      minzoom: 0,
      maxzoom: 19,
    },
  ],
};

const localPmtilesStyle: maplibregl.StyleSpecification = {
  version: 8,
  name: "Local HCM PMTiles Street Map",
  glyphs: "https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf",
  sprite: "https://protomaps.github.io/basemaps-assets/sprites/v4/light",
  sources: {
    protomaps: {
      type: "vector",
      url: `pmtiles://${LOCAL_PMTILES_URL}`,
      attribution:
        '<a href="https://protomaps.com">Protomaps</a> © <a href="https://openstreetmap.org">OpenStreetMap</a>',
    },
  },
  layers: layers("protomaps", namedFlavor("light"), {
    lang: "local",
  }) as maplibregl.LayerSpecification[],
};

function getStatusColor(status?: ShipperStatus) {
  switch (status) {
    case "AVAILABLE":
      return "#2e7d32";
    case "BUSY":
      return "#ef6c00";
    case "OFFLINE":
      return "#64748b";
    case "SUSPENDED":
      return "#c62828";
    default:
      return "#1565c0";
  }
}

function getStatusLabel(status?: ShipperStatus) {
  return status || "UNKNOWN";
}

function formatTime(value?: string | null) {
  if (!value) return "-";
  try {
    return new Date(value).toLocaleTimeString();
  } catch {
    return value;
  }
}

function createShipperMarkerElement(shipperId: number, status?: ShipperStatus) {
  const wrapper = document.createElement("div");
  wrapper.dataset.shipperMarker = String(shipperId);
  wrapper.style.width = "42px";
  wrapper.style.height = "42px";
  wrapper.style.borderRadius = "50%";
  wrapper.style.background = getStatusColor(status);
  wrapper.style.border = "3px solid #ffffff";
  wrapper.style.boxShadow = "0 8px 20px rgba(0,0,0,0.35)";
  wrapper.style.display = "flex";
  wrapper.style.alignItems = "center";
  wrapper.style.justifyContent = "center";
  wrapper.style.color = "#ffffff";
  wrapper.style.fontSize = "13px";
  wrapper.style.fontWeight = "800";
  wrapper.style.cursor = "pointer";
  wrapper.style.transition = "background 180ms ease, transform 180ms ease";
  wrapper.innerText = String(shipperId);
  return wrapper;
}

function updateMarkerElement(marker: maplibregl.Marker, shipper: LiveShipper) {
  const element = marker.getElement();
  element.style.background = getStatusColor(shipper.status);
  element.style.transform = "scale(1.05)";
  window.setTimeout(() => {
    element.style.transform = "scale(1)";
  }, 160);
}

function buildPopupHtml(shipper: LiveShipper) {
  const lat = typeof shipper.lat === "number" ? shipper.lat.toFixed(6) : "-";
  const lng = typeof shipper.lng === "number" ? shipper.lng.toFixed(6) : "-";
  return `
    <div style="min-width:180px">
      <strong>${shipper.name || `Shipper #${shipper.shipper_id}`}</strong><br/>
      <span>Status: <b>${getStatusLabel(shipper.status)}</b></span><br/>
      <span>Plate: ${shipper.vehicle_plate || "-"}</span><br/>
      <span>Lat: ${lat}</span><br/>
      <span>Lng: ${lng}</span><br/>
      <span>Last seen: ${formatTime(shipper.last_seen_at)}</span>
    </div>
  `;
}

function addLocalDeliveryMapDetails(map: maplibregl.Map) {
  if (!map.getSource("protomaps")) return;

  if (!map.getLayer("custom-buildings-fill")) {
    map.addLayer({
      id: "custom-buildings-fill",
      type: "fill",
      source: "protomaps",
      "source-layer": "buildings",
      minzoom: 14,
      paint: {
        "fill-color": "#d6d1c4",
        "fill-opacity": ["interpolate", ["linear"], ["zoom"], 14, 0.22, 16, 0.58],
      },
    });
  }

  if (!map.getLayer("custom-buildings-outline")) {
    map.addLayer({
      id: "custom-buildings-outline",
      type: "line",
      source: "protomaps",
      "source-layer": "buildings",
      minzoom: 15,
      paint: {
        "line-color": "#8f8778",
        "line-width": ["interpolate", ["linear"], ["zoom"], 15, 0.45, 17, 1.25],
        "line-opacity": 0.8,
      },
    });
  }

  if (!map.getLayer("custom-major-roads-highlight")) {
    map.addLayer({
      id: "custom-major-roads-highlight",
      type: "line",
      source: "protomaps",
      "source-layer": "roads",
      minzoom: 12,
      filter: ["in", ["get", "kind"], ["literal", ["highway", "major_road"]]],
      paint: {
        "line-color": "#f2b84b",
        "line-width": ["interpolate", ["linear"], ["zoom"], 12, 1.5, 15, 4.5, 17, 9],
        "line-opacity": 0.75,
      },
    });
  }

  if (!map.getLayer("custom-minor-roads-detail")) {
    map.addLayer({
      id: "custom-minor-roads-detail",
      type: "line",
      source: "protomaps",
      "source-layer": "roads",
      minzoom: 14,
      filter: ["in", ["get", "kind"], ["literal", ["minor_road", "path"]]],
      paint: {
        "line-color": "#ffffff",
        "line-width": ["interpolate", ["linear"], ["zoom"], 14, 0.8, 16, 2.2, 18, 5],
        "line-opacity": 0.95,
      },
    });
  }

  if (!map.getLayer("custom-street-labels")) {
    map.addLayer({
      id: "custom-street-labels",
      type: "symbol",
      source: "protomaps",
      "source-layer": "roads",
      minzoom: 14,
      layout: {
        "symbol-placement": "line",
        "text-field": ["coalesce", ["get", "name"], ""],
        "text-font": ["Noto Sans Regular"],
        "text-size": ["interpolate", ["linear"], ["zoom"], 14, 11, 16, 14, 18, 17],
        "text-allow-overlap": false,
        "text-ignore-placement": false,
      },
      paint: {
        "text-color": "#1f2937",
        "text-halo-color": "#ffffff",
        "text-halo-width": 2,
      },
    });
  }
}

export default function LiveMap() {
  const mapContainer = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<Record<number, maplibregl.Marker>>({});
  const shippersRef = useRef<Record<number, LiveShipper>>({});
  const [status, setStatus] = useState("Connecting...");
  const [lastUpdate, setLastUpdate] = useState<string>("No GPS yet");
  const [shippers, setShippers] = useState<Record<number, LiveShipper>>({});
  const isLocalMap = MAP_MODE === "local";

  function setShipperState(next: Record<number, LiveShipper>) {
    shippersRef.current = next;
    setShippers(next);
  }

  function mergeShipper(update: LiveShipper) {
    const previous = shippersRef.current[update.shipper_id] || { shipper_id: update.shipper_id };
    const merged: LiveShipper = {
      ...previous,
      ...update,
      lat: update.lat ?? previous.lat,
      lng: update.lng ?? previous.lng,
      status: update.status ?? previous.status,
    };

    setShipperState({
      ...shippersRef.current,
      [merged.shipper_id]: merged,
    });

    return merged;
  }

  function upsertMarker(update: LiveShipper) {
    const map = mapRef.current;
    const shipper = mergeShipper(update);
    if (!map || typeof shipper.lat !== "number" || typeof shipper.lng !== "number") return;

    const lngLat: [number, number] = [shipper.lng, shipper.lat];
    const existing = markersRef.current[shipper.shipper_id];

    if (existing) {
      existing.setLngLat(lngLat);
      existing.setPopup(new maplibregl.Popup({ offset: 28 }).setHTML(buildPopupHtml(shipper)));
      updateMarkerElement(existing, shipper);
    } else {
      const marker = new maplibregl.Marker({
        element: createShipperMarkerElement(shipper.shipper_id, shipper.status),
        anchor: "center",
      })
        .setLngLat(lngLat)
        .setPopup(new maplibregl.Popup({ offset: 28 }).setHTML(buildPopupHtml(shipper)))
        .addTo(map);
      markersRef.current[shipper.shipper_id] = marker;
    }

    setLastUpdate(
      `Shipper #${shipper.shipper_id}: ${shipper.lat.toFixed(5)}, ${shipper.lng.toFixed(5)} · ${getStatusLabel(
        shipper.status
      )}`
    );
  }

  function updateShipperStatus(update: LiveShipper) {
    const shipper = mergeShipper(update);
    const marker = markersRef.current[shipper.shipper_id];

    if (marker) {
      marker.setPopup(new maplibregl.Popup({ offset: 28 }).setHTML(buildPopupHtml(shipper)));
      updateMarkerElement(marker, shipper);
    }

    setLastUpdate(`Shipper #${shipper.shipper_id} status: ${getStatusLabel(shipper.status)}`);
  }

  function flyToShipper(shipper: LiveShipper) {
    if (!mapRef.current || typeof shipper.lat !== "number" || typeof shipper.lng !== "number") return;
    mapRef.current.flyTo({ center: [shipper.lng, shipper.lat], zoom: 16, speed: 1.2 });
    markersRef.current[shipper.shipper_id]?.togglePopup();
  }

  useEffect(() => {
    if (!mapContainer.current || mapRef.current) return;

    if (isLocalMap) {
      registerPmtilesProtocol();
    }

    mapRef.current = new maplibregl.Map({
      container: mapContainer.current,
      style: isLocalMap ? localPmtilesStyle : onlineOsmStreetStyle,
      center: HCM_CENTER,
      zoom: 15.5,
      minZoom: 9,
      maxZoom: 19,
      pitch: 35,
      bearing: -10,
    });

    mapRef.current.addControl(new maplibregl.NavigationControl(), "top-right");
    mapRef.current.addControl(new maplibregl.ScaleControl({ unit: "metric" }), "bottom-left");

    mapRef.current.on("load", () => {
      const map = mapRef.current;
      if (!map || !isLocalMap) return;
      addLocalDeliveryMapDetails(map);
    });

    mapRef.current.on("error", (event) => {
      console.error("Map error", event.error);
      if (isLocalMap) {
        setStatus("Local map error: check frontend/public/maps/hcm.pmtiles");
      }
    });
  }, [isLocalMap]);

  useEffect(() => {
    async function loadInitialLocations() {
      try {
        const token = getToken();
        const res = await fetch(`${API_URL}/locations/live`, { headers: token ? { Authorization: `Bearer ${token}` } : undefined });
        const data = await res.json();
        data.forEach((item: LiveShipper) => upsertMarker(item));
      } catch {
        setStatus("Could not load live locations");
      }
    }

    loadInitialLocations();
    const token = getToken();
    if (!token) { setStatus("Login required for live GPS map"); return; }
    const separator = WS_URL.includes("?") ? "&" : "?";
    const ws = new WebSocket(`${WS_URL}${separator}token=${encodeURIComponent(token)}`);
    ws.onopen = () =>
      setStatus(isLocalMap ? "Live GPS connected · Local HCM detail map" : "Live GPS connected · Online OSM map");
    ws.onclose = () => setStatus("Live GPS disconnected");
    ws.onerror = () => setStatus("Live GPS error");
    ws.onmessage = (event) => {
      const payload = JSON.parse(event.data);

      if (payload.type === "shipper_location") {
        upsertMarker({
          shipper_id: payload.shipper_id,
          name: payload.name,
          vehicle_plate: payload.vehicle_plate,
          status: payload.status,
          lat: payload.lat,
          lng: payload.lng,
          speed: payload.speed,
          heading: payload.heading,
          battery: payload.battery,
          last_seen_at: payload.last_seen_at || payload.timestamp,
        });
      }

      if (payload.type === "shipper_status") {
        updateShipperStatus({
          shipper_id: payload.shipper_id,
          name: payload.name,
          vehicle_plate: payload.vehicle_plate,
          status: payload.status,
          lat: payload.lat,
          lng: payload.lng,
          last_seen_at: payload.last_seen_at,
        });
      }

      if (payload.type === "order_item_status") {
        const code = payload.order?.order_code || `Order #${payload.order_id}`;
        const item = payload.item?.name || "Item";
        const itemStatus = payload.item?.status || "UPDATED";
        setLastUpdate(`${code}: ${item} → ${itemStatus}`);
        if (payload.shipper_id && payload.order?.shipper_id) {
          updateShipperStatus({
            shipper_id: payload.shipper_id,
            status: payload.order.status === "DELIVERED" ? "AVAILABLE" : "BUSY",
          });
        }
      }
    };

    return () => ws.close();
  }, [isLocalMap]);

  const shipperList = Object.values(shippers).sort((a, b) => a.shipper_id - b.shipper_id);

  return (
    <div
      style={{
        position: "relative",
        height: "calc(100vh - 96px)",
        borderRadius: 20,
        overflow: "hidden",
        border: "1px solid rgba(15,23,42,0.12)",
        boxShadow: "0 16px 48px rgba(15,23,42,0.16)",
      }}
    >
      <div ref={mapContainer} style={{ height: "100%", width: "100%" }} />

      <div
        style={{
          position: "absolute",
          top: 16,
          left: 16,
          background: "rgba(255,255,255,0.96)",
          padding: "12px 16px",
          borderRadius: 16,
          boxShadow: "0 8px 24px rgba(0,0,0,0.18)",
          minWidth: 320,
          maxWidth: 360,
        }}
      >
        <div style={{ fontWeight: 800, fontSize: 16 }}>
          {isLocalMap ? "HCM Local Detail Map" : "HCM Online Street Map"}
        </div>
        <div style={{ marginTop: 4, fontSize: 13, color: "#475569" }}>{status}</div>
        <div style={{ marginTop: 4, fontSize: 13, color: "#0f172a" }}>{lastUpdate}</div>
        {isLocalMap && (
          <div style={{ marginTop: 8, fontSize: 12, color: "#64748b" }}>
            Source: {LOCAL_PMTILES_URL}
          </div>
        )}
      </div>

      <div
        style={{
          position: "absolute",
          top: 16,
          right: 56,
          width: 300,
          maxHeight: "calc(100% - 32px)",
          overflowY: "auto",
          background: "rgba(255,255,255,0.96)",
          padding: "12px",
          borderRadius: 16,
          boxShadow: "0 8px 24px rgba(0,0,0,0.18)",
        }}
      >
        <div style={{ fontWeight: 900, fontSize: 15, marginBottom: 8 }}>Realtime Shippers</div>
        {shipperList.length === 0 ? (
          <div style={{ color: "#64748b", fontSize: 13 }}>No active shipper location yet.</div>
        ) : (
          shipperList.map((shipper) => (
            <button
              key={shipper.shipper_id}
              onClick={() => flyToShipper(shipper)}
              style={{
                width: "100%",
                textAlign: "left",
                border: "1px solid #e2e8f0",
                background: "#ffffff",
                borderRadius: 12,
                padding: 10,
                marginBottom: 8,
                cursor: "pointer",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8 }}>
                <strong>{shipper.name || `Shipper #${shipper.shipper_id}`}</strong>
                <span
                  style={{
                    background: getStatusColor(shipper.status),
                    color: "white",
                    borderRadius: 999,
                    padding: "2px 8px",
                    fontSize: 11,
                    fontWeight: 800,
                  }}
                >
                  {getStatusLabel(shipper.status)}
                </span>
              </div>
              <div style={{ color: "#475569", fontSize: 12, marginTop: 4 }}>
                ID #{shipper.shipper_id} · {shipper.vehicle_plate || "No plate"}
              </div>
              <div style={{ color: "#64748b", fontSize: 12, marginTop: 2 }}>
                GPS: {typeof shipper.lat === "number" ? shipper.lat.toFixed(5) : "-"},{" "}
                {typeof shipper.lng === "number" ? shipper.lng.toFixed(5) : "-"}
              </div>
              <div style={{ color: "#64748b", fontSize: 12, marginTop: 2 }}>
                Last seen: {formatTime(shipper.last_seen_at)}
              </div>
            </button>
          ))
        )}
      </div>
    </div>
  );
}
