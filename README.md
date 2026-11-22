# ŠEzVEM mobile

ŠEzVEM is an Android prototype for monitoring recovery after a hospital stay. Pair a WHOOP 4.0 or a Samsung Galaxy Watch4 to collect live wearable readings. The phone groups samples into batches, uploads them for the configured patient ID, and reads monitoring states from the backend. KEVIN is an animated Android companion that can show alerts and chat using a separately installed Gemma model.

## Run the phone app

```sh
cd mobile
flutter pub get
flutter run
```

Set a patient ID in **Settings**, then use **Add device** to pair a wearable. The Galaxy Watch4 needs the separate watch APK. Build it with `./gradlew :wear:assembleDebug` from `mobile/android`.

## Explore the project

- [User guide](docs/user-guide.md) covers pairing, uploads, and KEVIN.
- [Mobile implementation](docs/mobile-implementation.md) covers builds, tests, and model setup.
- [API contracts](docs/contracts.md) describe telemetry and monitoring.
- [Video](video/) contains the Remotion promo project.
