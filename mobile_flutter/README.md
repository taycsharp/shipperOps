# Shipper Mobile Flutter App

Professional Flutter shipper app for the upgraded FastAPI Shipper / Delivery Operations backend.

## Compatible backend

This version is adjusted for the production upgrade backend with JWT authentication and role-based access.

Default production API:

```txt
https://ship-api.dolasol.com
```

Override at runtime:

```bash
flutter run --dart-define=API_BASE_URL=https://ship-api.dolasol.com
```

## Main features

- Secure login through `POST /auth/login`
- Loads current user through `GET /auth/me`
- Saves JWT locally with `shared_preferences`
- Logout clears local token
- English is the default UI language; drivers can switch between English and Vietnamese from the language menu, and the selection is saved locally with `shared_preferences` across app restarts
- Binds the session to the authenticated SHIPPER user's own shipper profile only; no production profile selector is shown
- Sends authenticated GPS updates to `POST /locations/update`
- Updates shipper online/busy/offline status through `POST /shippers/{id}/status`
- Loads assigned orders through `GET /orders/shipper/{shipper_id}`
- Step-by-step order workflow using `POST /orders/{id}/status` with backend-aligned transitions: `ASSIGNED -> PICKED_UP -> IN_TRANSIT -> DELIVERED|FAILED|RETURNED`
- Requires receiver name, delivery note, proof photo, and COD collection confirmation when applicable before marking delivered
- Supports failed and returned delivery reasons with predefined practical reason codes
- Updates item status through upgraded endpoint `POST /orders/{order_id}/items/{item_id}/status`
- Uploads proof of delivery image through `POST /orders/{id}/proof`
- Call customer button using phone dialer
- Open pickup/customer directions in Google Maps
- Mobile-first professional UI with a compact shipper header, non-wrapping status chips, scanner-friendly assigned-order cards, and production-safe GPS/error messaging




## Language support

The Flutter app includes simple built-in English/Vietnamese localization without generated ARB files or backend changes.

- Default language: **English**.
- Supported languages: **English** and **Tiếng Việt**.
- Change language from the globe menu on the login screen or top app bar.
- The selected language is persisted in `shared_preferences` under `app_language_code` and is restored on restart.
- Translations live in `lib/l10n/app_localizations.dart` and cover the visible shipper UI: login, delivery console, shipper statuses, GPS card, assigned orders, order statuses, workflow buttons, COD and proof upload labels, empty states, error/retry messages, logout/refresh, call/map actions, and failed/returned reason dialogs.
- Backend/API enum values such as `ASSIGNED`, `IN_TRANSIT`, `DELIVERED`, `FAILED`, and `RETURNED` are still sent unchanged; only the display text is localized.

Vietnamese terms intentionally use practical logistics wording such as **Bảng giao hàng**, **Đơn được giao**, **Bắt đầu GPS**, **Gửi vị trí**, **Sẵn sàng**, **Đang bận**, **Ngoại tuyến**, **Đã giao**, **Giao thất bại**, **Đã hoàn**, and **COD còn lại**.

## Production mobile UX notes

The shipper home screen is optimized for fast route work on iPhone and Android:

- A single compact header shows the bound shipper name, vehicle type, license plate, current status, active order count, and COD remaining.
- The Available / Busy / Offline control is a segmented chip row designed to keep labels on one line on small screens.
- GPS tracking keeps Start live GPS, Stop, and Send once actions visible, while showing last update time, accuracy, and tracking state first. Raw latitude/longitude is available only in debug location details.
- Technical backend, Cloudflare, timeout, and network details are logged for debugging but converted to user-friendly messages such as server temporarily unavailable, unable to send GPS, or order update failed.
- Assigned-order cards prioritize order code, customer name, phone, status, COD, and delivery address before secondary package details.
- The language menu in the login screen and delivery console switches all shipper-facing labels, dialogs, GPS messages, order workflow actions, COD/proof labels, empty states, refresh/logout actions, failed/returned reason dialogs, call customer, and map actions at runtime. API enum/status values remain unchanged; only display labels are translated.

## Production shipper binding

After JWT login the app loads `GET /auth/me`, verifies the user role is `SHIPPER`, then resolves the one shipper profile whose `user_id` matches the authenticated user. GPS updates, status changes, assigned-order loading, proof upload, and order actions all use that bound profile.

If no profile is linked to the logged-in shipper user, the app shows a clear blocking message and disables GPS/order operation until an admin/dispatcher links a shipper profile.

## Order workflow

The mobile buttons intentionally mirror the backend state machine:

```txt
ASSIGNED   -> PICKED_UP
PICKED_UP  -> IN_TRANSIT
IN_TRANSIT -> DELIVERED
IN_TRANSIT -> FAILED
IN_TRANSIT -> RETURNED
```

There is no direct `ASSIGNED -> DELIVERED` action in the mobile UI. The app also checks the current status before calling the backend so invalid transitions are caught with user-friendly messages.

Delivery completion requires receiver name, delivery note, a proof photo if no proof has already been uploaded, and COD confirmation/payment details when the order has a COD amount. Failed and returned deliveries require a reason from the practical predefined list, with notes for extra context.


## GPS reliability and troubleshooting

The production app keeps GPS tracking friendly for real shippers:

- The GPS card shows clear states for GPS off, permission required, live tracking, sending, failed last update, and offline/waiting for network.
- The last successful update time, estimated accuracy, pending retry count, and short connection status are visible without exposing raw coordinates.
- Raw latitude/longitude remains hidden unless a tester expands **Debug location details**.
- If a location upload fails, the app saves a small local retry queue and retries automatically on the normal tracking cadence once the API/network is reachable. The queue keeps only the latest reasonable set of pending points to avoid backend spam.
- Selecting **Offline**, pressing **Stop**, or logging out stops the tracking timer cleanly.
- Starting live GPS sends an immediate update, then continues at the configured available/busy intervals.

Troubleshooting checklist for drivers and QA:

1. Confirm the shipper is **Available** or **Busy**. GPS stays paused while the shipper is **Offline**.
2. If the card says **GPS OFF**, turn on device Location Services and return to the app.
3. If the card says **PERMISSION** or **SETTINGS**, allow location access for Shipper Mobile in system settings. Use the in-app **Open app settings** button when shown.
4. If the card says **OFFLINE**, keep the app open or backgrounded with network restored. Pending locations retry automatically; avoid tapping **Send now** repeatedly.
5. For iOS production testing, verify the app has the Location usage strings and `location` background mode in `ios/Runner/Info.plist`.
6. For Android production testing, verify fine/coarse/background location and foreground-service permissions in `android/app/src/main/AndroidManifest.xml`.
7. Test GPS on a real device whenever possible; simulators often return stale or low-accuracy locations.

## Backend endpoints used

```txt
POST /auth/login
GET  /auth/me
GET  /shippers
GET  /shippers/{id}
POST /shippers/{id}/status
POST /locations/update
GET  /orders/shipper/{shipper_id}
GET  /orders?active_only=true&limit=100
POST /orders/{id}/status
POST /orders/{order_id}/items/{item_id}/status
POST /orders/{id}/proof
```

## Demo login

After backend seed:

```txt
shipper1@example.com / shipper123
```

Admin/dispatcher accounts should use the web dashboard or a separate simulator/test tool. This production mobile app does not allow admin/dispatcher users to choose a shipper profile or operate as another shipper.

## Run on iPhone / Android

```bash
flutter clean
flutter pub get
flutter run -d YOUR_DEVICE_ID \
  --dart-define=API_BASE_URL=https://ship-api.dolasol.com
```

Android release APK:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://ship-api.dolasol.com
```

iOS release:

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://ship-api.dolasol.com
```

## Local development API

Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

iOS simulator:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

Real phone on same Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LINUX_OR_MAC_LAN_IP:8000
```

## Backend setup reminder

Run migrations and seed data:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production exec backend alembic upgrade head
docker compose -f docker-compose.prod.yml --env-file .env.production exec backend python -m app.db.seed
```

Check API:

```bash
curl -I https://ship-api.dolasol.com/docs
```

## Mobile permissions

For real GPS and proof photo upload, test on a real phone and allow:

- Location permission
- Camera permission
- Photo library permission

Platform folders are not included in this starter ZIP. If you create a new Flutter project around this `lib/` folder, ensure Android/iOS permissions are added for `geolocator`, `image_picker`, and `url_launcher`.
