# Flutter mobile implementation

## Current flow

1. **Sign in** opens first. Continue takes the user straight to Connected devices. The placeholder accepts no credentials and makes no network request. Replacing the sign-in route keeps it out of the back stack after Continue.
2. **Connected devices** starts empty. **Add device** loads WHOOP and Samsung Galaxy Watch from the bundled provider catalog.
3. Select **WHOOP** and follow the numbered setup steps. Wake the WHOOP 4.0 with its charged battery pack and look for the flashing blue LED. In IXLand, tap **Scan for WHOOP**, grant Bluetooth access if prompted, and select your strap. Accept any Android pairing prompt and wear the strap. The app supports one active connection and shows the latest heart rate and sample count. Disconnect stops collection from the strap.
4. For **Samsung Galaxy Watch**, pair the watch with the phone through Galaxy Wearable and open **IXLand Watch**. On the phone select **Add device → Samsung Galaxy Watch**, scan, and select the watch. On the watch tap **Start**, grant heart-rate permission, and wear the watch. The phone shows BPM and the batch sample count as readings arrive. Tap **Stop** on the watch to end measurement.

## Files and decisions

| Path | Role |
| --- | --- |
| `mobile/lib/main.dart` | App entry point, provider registration, and placeholder sign-in. |
| `mobile/lib/devices/connected_devices_screen.dart` | Starts and stops the selected adapter session, forwards normalized samples to the batch buffer, and displays the latest reading. |
| `mobile/lib/devices/provider_picker_screen.dart` | Catalog loading, empty, error, and populated states. |
| `mobile/lib/devices/device_scan_screen.dart` | Renders the provider's numbered setup steps and starts scanning when the user taps the scan button. Handles retries and device selection. |
| `mobile/lib/devices/provider_catalog.dart` | Parses JSON into provider entries with a stable ID and display name. |
| `mobile/assets/providers.json` | Static provider catalog registered in `mobile/pubspec.yaml`. |
| `mobile/lib/wearables/wearable_adapter.dart` | Provider-independent scan and connection interface and live heart-rate events. |
| `mobile/lib/wearables/whoop/whoop_ble_adapter.dart` | WHOOP discovery, Android pairing trigger, and live heart-rate subscriptions. |
| `mobile/lib/wearables/whoop/whoop4_protocol.dart` | WHOOP 4.0 command frames and reassembly and checksum validation for live heart-rate notifications. |
| `mobile/lib/wearables/samsung/samsung_wear_adapter.dart` | Discovers nearby IXLand Watch nodes and emits the common wearable events. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/WearBridge.kt` | Exposes Wear OS discovery and messages from the selected watch node through Flutter channels. |
| `mobile/android/wear/` | Separate Wear OS app module with the watch sensor permission and Start and Stop screen. |
| `mobile/lib/wearables/metric_batch_buffer.dart` | Provider-independent measurement windows and collection. |

To add a provider, implement `WearableAdapter` in its own folder. Supply its setup steps and handle discovery, connection, and parsing there, then emit the common events. Register the adapter by the stable ID in `main.dart` and add a matching catalog entry. The provider picker enables entries that have a registered adapter. Batch windowing stays shared.

Use plain Material widgets and Flutter navigation. Android is the first scaffolded platform, with the application ID `com.ixland.ixland_mobile` and launcher name IXLand. The catalog stores display metadata and ships with the app. Keep IDs unique across entries.

```json
[
  { "id": "whoop", "name": "WHOOP" },
  { "id": "samsung", "name": "Samsung Galaxy Watch" }
]
```

## WHOOP Bluetooth and batch decisions

- Discover WHOOP 4.0 by its vendor service or advertised name. After a device is selected and its services are discovered, send an acknowledged battery query on the protected WHOOP 4.0 command characteristic. Noop uses this write to initiate bonding where Android requires it. An acknowledged write means the GATT operation completed. Treat a valid reading as the evidence that heart-rate streaming works. [Noop Android pairing implementation](https://github.com/ryanbr/noop/blob/main/android/app/src/main/java/com/noop/ble/WhoopBleClient.kt#L9690-L9712) · [Noop WHOOP 4 profile](https://github.com/ryanbr/noop/blob/main/docs/PROTOCOL_WHOOP4.md#bond-handshake--connect-lifecycle-whoop-40)
- Request the WHOOP 4.0 live heart-rate stream and re-arm it while connected. When available, also listen to the standard Bluetooth Heart Rate Service `0x180D` and characteristic `0x2A37`. Use one source at a time to avoid counting both streams. Heart Rate Broadcast, enabled separately, also works through that standard path. Support for the vendor live-stream command varies by firmware. [Noop command notes](https://github.com/ryanbr/noop/blob/main/docs/PROTOCOL_COMMANDS.md#whoop-4) · [Bluetooth Heart Rate Service](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/HRS_v1.0/out/en/index-en.html)
- All provider-specific commands and parsers stay in the adapter directory. The adapter emits integer BPM and the phone's UTC receipt time. The WHOOP 4.0 parser accepts complete checksum-verified live heart-rate frames. The standard parser reads 8-bit and 16-bit BPM values and skips measurements with an explicit no-contact flag. Both paths skip missing or zero BPM. The current BLE dependency is `flutter_reactive_ble` 5.4.2. [Noop sensor records](https://github.com/ryanbr/noop/blob/main/docs/PROTOCOL_SENSORS.md#whoop-4-realtime-heart-rate-record-type-40) · [Flutter Reactive BLE](https://pub.dev/packages/flutter_reactive_ble/versions/5.4.2)
- Group readings by UTC receipt time into fixed-length windows. `BATCH_UPLOAD_INTERVAL_MINUTES` is a Dart build-time setting for the prototype window length. It defaults to five minutes. The buffer retains up to 24 nonempty windows in memory for the current app session, including after disconnect. It is reset when the app session ends.
- The Bluetooth path currently collects heart rate. The POST contract requires additional fields such as `steps` and `spo2` and needs an agreed missing-data policy. Durable storage and POST submission are future steps.

## Galaxy Watch4 companion

- The watch app reads BPM from Wear OS Health Services while the user keeps the measurement screen open. It stops when the user taps Stop or leaves the screen. The watch asks for heart-rate access on first use. [Watch4 Health Services support](https://developer.samsung.com/health/blog/en/2022/01/14/using-health-services-on-galaxy-watch) · [Wear OS spot measurement](https://developer.android.com/health-and-fitness/health-services/active-data/measure-client)
- The watch and phone advertise separate Data Layer capabilities. The watch sends positive BPM readings to a nearby IXLand phone. The phone listens only to messages from the selected watch. The Samsung adapter timestamps incoming BPM in UTC and feeds the same in-memory batch buffer as WHOOP. This flow runs through Wear OS Data Layer and uses its best-effort live messaging. [Wear OS capabilities](https://developer.android.com/training/wearables/data/discover-devices) · [Data Layer message delivery](https://developer.android.com/training/wearables/data/client-types)
- Build the phone and watch APKs with matching package names and signing keys. Their package is `com.ixland.ixland_mobile`. The watch build has a distinct launcher and requires Wear OS 3 or higher. [Wear OS Data Layer requirements](https://developer.android.com/training/wearables/data/overview)

### Build and install IXLand Watch

From the project root, build the watch module and target the Watch4 serial listed by ADB. Replace `WATCH_SERIAL` with the serial or Wi-Fi connection address. [Wear OS Wi-Fi debugging](https://developer.android.com/training/wearables/get-started/debug-wifi)

```sh
cd mobile/android
./gradlew :wear:assembleDebug
adb devices -l
adb -s WATCH_SERIAL install -r ../build/wear/outputs/apk/debug/wear-debug.apk
```

The APK is generated at `mobile/build/wear/outputs/apk/debug/wear-debug.apk`. Open **IXLand Watch** from the watch's app list. Use the current phone APK for its Samsung provider.

## Run and verify the phone app

Use a physical Android phone and a WHOOP 4.0 to verify direct pairing. Start with Heart Rate Broadcast off and follow the in-app guide. Check that repeated readings increase the sample count, then disconnect and confirm the device disappears from the list. Test the alternate standard path with Heart Rate Broadcast enabled. [WHOOP 4.0 wake and pairing indicators](https://support.whoop.com/s/article/Setting-Up-Your-WHOOP-4-0?language=en_US) · [WHOOP broadcast guide](https://www.whoop.com/us/en/thelocker/strain-coach/)

```sh
cd mobile
flutter pub get
flutter run --dart-define=BATCH_UPLOAD_INTERVAL_MINUTES=5
```

From `mobile/`, run the analyzer and widget tests.

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The widget tests cover the bundled provider picker, setup guide, simulated live samples entering a batch, and disconnect. Unit tests cover WHOOP 4.0 protocol and decoding, Samsung discovery and sample mapping over mocked platform channels, and batch windows. The user verified their WHOOP 4.0 connection. The phone APK is generated at `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

Flutter analysis and all nine tests passed. Both debug APKs built with matching signing certificates. IXLand Watch installed and launched on the physical Galaxy Watch4, and the updated IXLand app installed and launched on its Android phone. The live sensor check starts when the wearer grants access and taps Start on the watch.

## Companion overlay test

The companion is a small animated character that appears over other Android apps. This first version is a manual test with placeholder art and a placeholder tap action.

1. On **Connected devices**, tap **TEST** below **Add device**. The first time, Android opens **Display over other apps** for IXLand. Turn it on and go back. If access stays off, the app explains why it can't continue.
2. IXLand moves to the background. The companion walks in from the right edge and rests near the right side of the screen, over whatever app is visible. The app underneath stays usable outside the character.
3. Tap the companion to see a **Hello world** alert. Swipe it left or right and it runs off that edge, and its window closes. A short drag snaps it back.

| Path | Role |
| --- | --- |
| `mobile/lib/companion/companion_overlay.dart` | Main-app interface to check and request overlay access, show and hide the companion, and minimize the app. |
| `mobile/lib/companion/companion_overlay_app.dart` | Root widget of the overlay engine. Runs the enter, tap, and swipe-to-exit behavior and classifies swipes. |
| `mobile/lib/companion/companion_window.dart` | Overlay-side channel to read the window layout, move the window, show an alert, and close it. |
| `mobile/lib/companion/companion_movement.dart` | Moves the window horizontally at a set speed. Knows nothing about animation. |
| `mobile/lib/companion/companion_character.dart` | Draws the character and animates idle bobbing, blinking, walking, and the tap reaction from the current state and facing. |
| `mobile/lib/companion/companion_state.dart` | Companion states (`hidden`, `entering`, `idle`, `walking`, `reacting`, `exiting`) and facing direction. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/CompanionOverlayService.kt` | Owns the overlay window and the second Flutter engine that renders the character. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/CompanionBridge.kt` | `ixland/companion` channel for the main app, including the overlay settings flow. |

### Overlay decisions

- The overlay uses a native window instead of an overlay plugin, so the app controls its size, flags, and lifecycle with no new dependency. `CompanionOverlayService` adds a 96 dp `TYPE_APPLICATION_OVERLAY` window that is never focusable, so touches outside it reach the app underneath. Android requires the user to grant **Display over other apps**, which the app checks with `Settings.canDrawOverlays`. [Overlay window type](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY) · [Overlay permission](https://developer.android.com/reference/android/provider/Settings#ACTION_MANAGE_OVERLAY_PERMISSION)
- The window runs a second Flutter engine that starts at `companionOverlayMain` in `main.dart`. The entry point has to stay in that library so Android can find it. The engine renders with a transparent texture and doesn't register plugins. Dart decides where the character goes and calls the service to move the window, so the character's look and behavior stay in Flutter.
- Movement and animation are separate. `CompanionMovementController` only sets the window position. `CompanionCharacter` picks its animation from `CompanionState` and the facing direction. The placeholder painter draws from a normalized `CompanionPose`, so a sprite sheet or Rive renderer can replace it without changing the controllers. Animations stop while the companion is hidden.
- Transparent pixels inside the 96 dp window still receive touches, so the window is kept small. Horizontal positions may go off screen so the character can walk out. Vertical positions are clamped to the area outside system bars and display cutouts. After rotation or a display change, the window is moved back on screen. Before Android 11, the clamp uses the full display size and doesn't account for cutouts.
- The **Hello world** alert is a system dialog shown as an overlay window. It stands in for opening the chat, which doesn't exist yet.
- The service is started while IXLand is in the foreground. It isn't a foreground service and shows no notification. Android can still stop the process in the background, which removes the companion. Appearances triggered later in the background will need a supported path, such as a notification the user taps or a foreground service with a matching type. [Background service limits](https://developer.android.com/about/versions/oreo/background#services) · [Foreground service types](https://developer.android.com/develop/background-work/services/fg-service-types)
- Settings, AI-triggered appearances, a policy for when the companion may appear, and handling for access being revoked while it's visible aren't implemented yet.

### Verify the companion

From `mobile/`, run the analyzer and tests, then build and install the phone app.

```sh
flutter analyze
flutter test
flutter run
```

`test/companion_test.dart` covers swipe classification, the TEST button with granted and denied access, and the overlay walking in, sending **Hello world** on tap, and walking off and closing after a swipe, with the window channel mocked.

On a physical Android phone, tap **TEST**, grant access, and check that the companion walks in over the home screen. Open another app and confirm you can tap and scroll around the character. Tap the companion for the alert, then swipe it away in each direction. Rotate the phone while it's visible and check it stays on screen.

Flutter analysis and all 15 tests passed, and the debug APK built. The companion hasn't been run on a device yet.
