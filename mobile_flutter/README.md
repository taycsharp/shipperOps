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
- Mobile-first professional UI


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
