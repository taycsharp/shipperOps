# Flutter platform setup for location tracking

## Android

Edit `android/app/src/main/AndroidManifest.xml` and add these permissions above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For foreground MVP tracking, `ACCESS_FINE_LOCATION` and `INTERNET` are enough.

For background tracking later, you will also need:

```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

Background GPS has Google Play policy requirements. Start with foreground tracking first.

## iOS

Edit `ios/Runner/Info.plist` and add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location to update delivery tracking while you are working.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app uses your location to update delivery tracking during active deliveries.</string>
```

For iOS background tracking later, enable location background mode in Xcode and provide a clear App Store permission explanation.

## Run with production Cloudflare API

```bash
flutter run --dart-define=API_BASE_URL=https://ship-api.dolasol.com
```

## Run with local backend

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
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
```
