# Local HCM Map Setup

This project is prepared for a local HCM City map using **PMTiles + MapLibre + Protomaps style**.

## 1. Current frontend setting

`docker-compose.yml` sets:

```yaml
NEXT_PUBLIC_MAP_MODE: local
NEXT_PUBLIC_PMTILES_URL: /maps/hcm.pmtiles
```

So the map expects this file:

```txt
frontend/public/maps/hcm.pmtiles
```

## 2. How to get `hcm.pmtiles`

Recommended approach:

```bash
mkdir -p frontend/public/maps
```

Then create or download an HCM-only `.pmtiles` file and save it as:

```bash
frontend/public/maps/hcm.pmtiles
```

A typical HCM bounding box is approximately:

```txt
106.35,10.35,107.10,11.20
```

Order is:

```txt
minLng,minLat,maxLng,maxLat
```

## 3. PMTiles extraction example

If you have the `pmtiles` CLI and a source PMTiles basemap, extract HCM like this:

```bash
pmtiles extract SOURCE.pmtiles frontend/public/maps/hcm.pmtiles   --bbox=106.35,10.35,107.10,11.20
```

You can use a remote source URL or a local source file, depending on where you get your Protomaps basemap.

## 4. Rebuild frontend

After putting the file in place:

```bash
docker compose build frontend
docker compose up -d
```

Open:

```txt
http://localhost:3000/admin/map
```

You should see street names and HCM local map data.

## 5. Temporary fallback to online map

If you do not have `hcm.pmtiles` yet, change `docker-compose.yml`:

```yaml
NEXT_PUBLIC_MAP_MODE: online
```

Then rebuild the frontend.

## 6. Notes

The PMTiles map data is the background map only. Live shipper GPS still comes from FastAPI + PostgreSQL + WebSocket.

For a fully offline/private production map, you should also self-host Protomaps glyphs and sprites. This starter still loads glyphs/sprites from Protomaps CDN so that street labels display correctly with minimal setup.
