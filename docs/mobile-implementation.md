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
- Group readings by UTC receipt time into fixed-length windows. The prototype window defaults to 60 seconds. See [Batch interval configuration](#batch-interval-configuration) for build-time overrides.
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
flutter run --dart-define=BATCH_UPLOAD_INTERVAL_SECONDS=60
```

From `mobile/`, run the analyzer and widget tests.

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The widget tests cover the bundled provider picker, setup guide, simulated live samples entering a batch, and disconnect. Unit tests cover WHOOP 4.0 protocol and decoding, Samsung discovery and sample mapping over mocked platform channels, and batch windows. The user verified their WHOOP 4.0 connection. The phone APK is generated at `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

Flutter analysis and all nine tests passed. Both debug APKs built with matching signing certificates. IXLand Watch installed and launched on the physical Galaxy Watch4, and the updated IXLand app installed and launched on its Android phone. The live sensor check starts when the wearer grants access and taps Start on the watch.

## Timed batch preview and retries

Connected Devices attempts to send completed UTC windows on the configured batch cadence. The buffer groups readings by provider and device, keeps pending samples after disconnect, and removes only the samples acknowledged by the sender. Pending data and batch numbers live in memory for the current app session.

`_ConnectedDevicesScreenState._sendBatch` displays the latest attempted object under **Batch JSON (debug)** and calls the telemetry gateway. The sender returns `true` after confirmed acceptance, returns `false` for confirmed non-acceptance, and throws when delivery is uncertain. After confirmed non-acceptance, the next attempt includes newly completed windows for that device and extends the interval from the original start. A lost response retries the original payload unchanged while additional readings continue to buffer.

The upload requires a configured [Patient ID](#patient-id-settings) while sign-in is a placeholder. Missing metric fields are omitted from the live request.

`flutter test` covers the preview and simulates confirmed rejection and a lost response.

## Batch interval configuration

Set a positive whole number with `BATCH_UPLOAD_INTERVAL_SECONDS`. The app defaults to 60 seconds if the value is absent or invalid. Rerun the app after changing the build-time setting.

From `mobile/`, run `flutter run --dart-define=BATCH_UPLOAD_INTERVAL_SECONDS=10` and connect a wearable. When the next 10-second window closes, check that **Batch JSON (debug)** shows `extra.batch_interval_in_seconds` of 10. The widget test also verifies the override with `flutter test --dart-define=BATCH_UPLOAD_INTERVAL_SECONDS=10 test/device_flow_test.dart`.

## Debug jam

After the first JSON preview appears, check **Debug jam** below it to simulate an API that receives no batches. The preview updates on each attempt and the app skips the HTTP request. Keep the wearable streaming through two windows and check that the pending sample count grows and the attempted payload spans both windows. Uncheck **Debug jam** to let the next scheduled attempt upload and clear the readings the API accepts. The Connected Devices widget test exercises this flow with synthetic heart-rate readings.

## Companion overlay test

The companion is a small animated character that appears over other Android apps. This version is a manual test with placeholder art and six test actions.

1. On **Connected devices**, tap **TEST** below **Add device**. The first time, Android opens **Display over other apps** for IXLand. Turn it on and go back. If access stays off, the app explains why it can't continue.
2. IXLand moves to the background. The companion walks in from the right edge and rests near the right side of the screen, over whatever app is visible. The app underneath stays usable outside the character.
3. Interact with the companion. It runs one action at a time and ignores other input until the current action ends.
4. Choose the companion's look on **Connected devices** → **Settings** → **Companion style**. Each style shows an animated preview. **Classic** is the original look. **Dress-up** adds **Base**, **Hat**, and **Top** pickers below the list, each option shown on the companion. A visible companion switches right away, and the choices are kept after a restart.
5. While the companion is visible and IXLand is in the background, it walks to a random point every 4 to 8 seconds. A notification stays visible while the companion service runs. Its **Stop** action removes the companion. See [Monitoring state alerts](#monitoring-state-alerts) for when a state brings the companion onto the screen.

| Input | Test action |
| --- | --- |
| Tap | Bounces and opens the chat with the on-device assistant. See [Companion chat with on-device Gemma](#companion-chat-with-on-device-gemma). |
| Swipe left or right | Runs off that edge and its window closes. |
| Swipe up | Jumps and does a backflip. |
| Swipe down | Looks sad for two seconds. |
| Hold | Plays an inflating sound and grows to 1.8 times its size over two seconds. Shrinks back on release. |

A short drag snaps back without triggering an action.

| Path | Role |
| --- | --- |
| `mobile/lib/companion/companion_overlay.dart` | Main-app interface to check and request overlay access, show, hide, and move the companion, check whether it's showing, and minimize the app. |
| `mobile/lib/companion/companion_wander_test.dart` | Moves a visible companion to a random point while the app is hidden. |
| `mobile/lib/companion/companion_overlay_app.dart` | Root widget of the overlay engine. Turns taps, swipes, and holds into inputs for the action controller. |
| `mobile/lib/companion/companion_actions.dart` | Inputs, the action type, the context an action runs with, the controller that runs one action at a time, and the built-in entrance and walk-to-point actions. |
| `mobile/lib/companion/companion_test_actions.dart` | The six test actions and the map from inputs to actions. |
| `mobile/lib/companion/companion_animator.dart` | Decides which animation plays: state, facing, mood, and the bounce, backflip, and inflate clips. |
| `mobile/lib/companion/companion_movement.dart` | Moves the window in a straight line at a set speed and converts 0 to 1 screen coordinates to window positions. Knows nothing about animation. |
| `mobile/lib/companion/companion_character.dart` | Runs the idle and walk cycles and blinking, combines them with the animator into a `CompanionPose`, and has the selected style draw it. |
| `mobile/lib/companion/styles/companion_style.dart` | The style contract: the `CompanionAnimation` list every style must show, the `CompanionPose` passed to styles, and the window sizes styles must fit. |
| `mobile/lib/companion/styles/classic_style.dart` | The Classic style: a round teal body with two eyes, drawn on the canvas. |
| `mobile/lib/companion/styles/companion_styles.dart` | Registry of styles in settings order. The first style is the default. |
| `mobile/lib/companion/styles/companion_look.dart` | The saved look: the chosen style and the slot choices for each style, and its saved form. |
| `mobile/lib/companion/styles/dress_up/dress_up_style.dart` | The Dress-up style: its slots, the parts it offers, and the animations shared by every base. |
| `mobile/lib/companion/styles/dress_up/dress_up_parts.dart` | Dress-up bases, hats, and tops. |
| `mobile/lib/settings/settings_screen.dart` | Settings screen with the companion style picker, slot pickers for customizable styles, and animated previews. |
| `mobile/lib/companion/companion_window.dart` | Overlay-side channel to read the window layout, move or resize the window, play the inflating sound, show an alert, and close it. Also receives layout changes and move requests from the service. |
| `mobile/lib/companion/companion_state.dart` | Companion states (`hidden`, `entering`, `idle`, `walking`, `reacting`, `exiting`), facing, and mood. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/CompanionOverlayService.kt` | Foreground service with a notification. Owns the overlay window, the second Flutter engine that renders the character, and the generated sound, and passes move requests to the overlay. |
| `mobile/android/app/src/main/res/drawable/ic_companion.xml` | Notification icon. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/CompanionBridge.kt` | `ixland/companion` channel for the main app, including the overlay settings flow and saving the style. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/CompanionPrefs.kt` | Saves the chosen style and slot choices in Android `SharedPreferences`. |

### Add a companion action

An action is an async function that takes a `CompanionActionContext`. Use the context to call app code and drive the character: `animator` for animations, state, and mood, `movement` to walk the window, `window` for alerts and sound, `withRoom` to grow the window while the action runs, and `close` to remove the companion. A hold action can wait on `released` to learn when the finger lifts. Register the function for an input in `testCompanionActions`, or pass another map to `CompanionOverlayApp`. When an action finishes, the controller returns the companion to `idle` unless the action closed it.

The main app can also drive the companion. `CompanionOverlay.moveTo` sends a point in 0 to 1 screen coordinates. (0, 0) puts the companion in the top-left corner of the usable screen and (1, 1) in the bottom-right, so the same point is the same relative spot on any phone. The range keeps 16 dp of padding from every edge, plus room for the companion to grow: 128 dp at the top for the backflip and 16 dp at each side for inflation. With that room, no animation pushes the companion off screen or makes it jump. On a 360 by 732 dp usable screen, this leaves 104 dp of horizontal and 380 dp of vertical range. The overlay runs the move as the built-in `walkToUv` action, so it follows the one-action-at-a-time rule. `moveTo` returns false when the companion isn't showing or is busy, and the caller can try again later.

```dart
Future<void> wave(CompanionActionContext context) async {
  context.animator.state = CompanionState.reacting;
  await context.animator.bounce();
}
```

### Add a companion style

A style is a `CompanionStyle` with a stable `id`, a `name` for settings, and a `paint` method that draws one frame from a `CompanionPose`. The pose holds the progress of every animation in `CompanionAnimation`: `idle`, `walk`, `blink`, `bounce`, `backflip`, `sad`, and `inflate`, plus the facing direction. Several can be active at once, so a style must combine them, for example blinking while walking and sad. The values are normalized, so a style can draw with the canvas, pick sprite sheet frames, or drive a Rive state machine. `ClassicCompanionStyle` shows one way to map each value.

A style draws in design units, standing at the bottom center of a box. The box is `CompanionStyle.restSize` (96 by 96) most of the time and grows upward to `backflipSize` (96 by 160) or `inflateSize` (136 by 136) only during those animations, so each animation has to fit its box. In every animation, a style may draw at most `maxSideOverflow` (8 units) past either side of the resting width. The companion is shown at `displayScale` (2) logical pixels per unit, so the overlay window is 192 by 192 dp at rest. Add the style to `companionStyles` to list it in settings. Never change an `id` after release, because settings save it.

A style can also offer `slots`, things a person customizes such as a hat. Each `CompanionSlot` has options, and the first option is the default. The style reports its current `choices` and returns a changed copy from `customize`, ignoring unknown slots and options. Settings shows a picker for each slot of the selected style, and `CompanionLook` saves the choices for each style separately, so switching styles keeps them.

`test/companion_style_test.dart` checks every registered style, and every combination of options for a style with slots. For each animation it draws the style at rest and with that animation active and fails if the two frames are identical. It also fails if any frame of any animation reaches the edge of its box or draws past the side limit, facing either way, and if the style doesn't turn to face both ways. To add a new animation, add it to `CompanionAnimation` with a field on `CompanionPose` and an example value. The test then fails for each style until the style draws it.

### Dress-up parts

| Slot | Options |
| --- | --- |
| Base | Green circle, Orange triangle |
| Hat | None, Cat ears, Cap, Top hat |
| Top | None, T-shirt, Doctor's coat |

Both bases have larger eyes with a shine dot than Classic. The Dress-up body is smaller than Classic, with a 23 instead of a 30 unit radius, so a hat still fits the window while the companion inflates or does a backflip. All bases share the same animations. Hats and tops are drawn on the body, so they move, spin, squash, and grow with it. The cap's bill and the coat's pocket pen follow the facing direction, and the stethoscope hangs on the other side. Cat ears take the body color and droop when sad. Tops are clipped to the body outline, so they fit any base. Saved choices for a part that was removed, such as the earlier party hat and scarf, fall back to **None**.

To add a base, extend `DressUpBase` with an outline, colors, and where the eyes, mouth, neck, and hat go, in multiples of the body radius. To add a hat or top, extend `DressUpAccessory` and draw it from the `DressUpBody` it receives. Add the part to `bases`, `hats`, or `tops` in `DressUpCompanionStyle`. The style test then checks it with every other part.

### Overlay decisions

- The overlay uses a native window instead of an overlay plugin, so the app controls its size, flags, and lifecycle with no new dependency. `CompanionOverlayService` adds a 192 dp `TYPE_APPLICATION_OVERLAY` window that is never focusable, so touches outside it reach the app underneath. Android requires the user to grant **Display over other apps**, which the app checks with `Settings.canDrawOverlays`. [Overlay window type](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY) · [Overlay permission](https://developer.android.com/reference/android/provider/Settings#ACTION_MANAGE_OVERLAY_PERMISSION)
- The window runs a second Flutter engine that starts at `companionOverlayMain` in `main.dart`. The entry point has to stay in that library so Android can find it. The engine renders with a transparent texture and doesn't register plugins. Dart decides where the character goes and calls the service to move the window, so the character's look and behavior stay in Flutter.
- Movement and animation are separate. `CompanionMovementController` only sets the window position. `CompanionAnimator` decides which animation plays, and `CompanionCharacter` draws it. The placeholder painter draws from a normalized `CompanionPose`, so a sprite sheet or Rive renderer can replace it without changing actions or controllers. Animations stop while the companion is hidden.
- Transparent pixels inside the window still receive touches, so the window is only as large as the companion: 192 dp, twice the 96-unit style box. The backflip and the hold action grow it with `withRoom` only while they run, to 192 by 320 dp and 272 by 272 dp, upward from its bottom center. The character keeps a fixed size so it doesn't jump when the window changes. The 192 dp size is set in both `companion_actions.dart`, as `restSize` times `displayScale`, and `CompanionOverlayService.kt`.
- The native side clamps the window's vertical position to the screen. If the companion stood too close to the top, a backflip would push the window against that limit and the companion would drop down during the flip. Random positions reserve room at the top for this. The wider inflate window may extend past the side of the screen, because only its transparent part goes off screen.
- Horizontal positions may go off screen so the character can walk out. Vertical positions are clamped to the area outside system bars and display cutouts. After rotation or a display change, the window is moved back on screen. Before Android 11, the clamp uses the full display size and doesn't account for cutouts.
- The chosen look is saved natively in `SharedPreferences` instead of through a Flutter plugin, because the overlay engine doesn't register plugins. It stores the style ID and the slot choices as a JSON string. The main app writes it through `CompanionBridge`, and the overlay reads it on start. When the look changes while the companion is showing, the service tells the overlay to switch. Unknown or missing styles fall back to the first style, and unknown options keep the default. Bad saved data gives the default look.
- Swipes use the larger axis of the fling velocity, or of the drag distance for a slow drag. Holding still for Flutter's long-press delay starts the hold action.
- The inflating sound is generated in the service as rushing air under a rising tone and played with `AudioTrack`, so no audio package or sound file is needed. It plays as a sonification sound, stops when the character reaches its limit or the finger lifts, and is skipped if audio can't start. [AudioTrack](https://developer.android.com/reference/android/media/AudioTrack)
- The companion service runs as a foreground service with an ongoing notification. Without it, Android freezes or stops a backgrounded app, so the app couldn't move the companion. It is declared with the `specialUse` type and a stated reason, because no other type covers an on-screen companion. Google Play reviews that reason before release. The notification opens IXLand, and its **Stop** action ends the service. On Android 13 and later, the notification only shows in the drawer if notification access is allowed. The service still runs either way. [Foreground service types](https://developer.android.com/develop/background-work/services/fg-service-types#special-use) · [Foreground service notifications](https://developer.android.com/develop/ui/views/notifications/notification-permission#exemptions)
- Swiping the companion away removes its window and engine but keeps the service running. If a monitored state remains abnormal, the app brings the companion back by calling the running service directly. Android can still refuse to start the service from the background, which applies to Android 15 and later unless the companion is already visible. The app reports that as `start_blocked` and pending monitoring alerts are retried on the next state fetch or when the app resumes. Tap **TEST** while IXLand is open to start the service. [Restrictions on starting from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- The batch timer and monitoring cache run in the main app's Dart engine. If the user removes IXLand from recent apps, that engine ends while the companion service can stay visible.
- Settings, AI-triggered appearances, a policy for when the companion may appear, and handling for access being revoked while it's visible aren't implemented yet.

### Verify the companion

From `mobile/`, run the analyzer and tests, then build and install the phone app.

```sh
flutter analyze
flutter test
flutter run
```

`test/companion_test.dart` covers swipe classification in all four directions, the one-action-at-a-time rule, and the TEST button with granted and denied access. It also covers each test action with the window channel mocked: the alert on tap, walking off and closing on side swipes, the backflip's temporary resize, inputs blocked while sad, and the hold's sound, resize, and release. Inputs after closing are ignored. For styles, it covers the overlay drawing the saved style and Dress-up choices and switching when the look changes, and the settings picker opening from Connected devices, saving a style, customizing Dress-up, keeping Dress-up choices after switching style, and keeping the old style when saving fails. `test/companion_style_test.dart` also covers the Dress-up options, applying choices, and saving and reading looks, including bad saved data. For app control, it covers the 0 to 1 coordinate mapping with padding and density, walking to a point the app sends, and declining a move while busy.

On a physical Android phone, tap **TEST**, grant access, and check that the companion walks in over the home screen. Open another app and confirm you can tap and scroll around the character. Try each input from the table, and check that other inputs do nothing while an action runs, especially during the two sad seconds. Hold with the phone's sound on to hear the inflating sound. Check the backflip and inflation aren't clipped and the character doesn't jump when the window resizes. Rotate the phone while it's visible and check it stays on screen. Swipe the companion away with a normal cache and confirm it stays hidden. Use **Stop** in the notification and check the companion and the notification go away. Open **Settings** and check that **Classic** is selected and its preview animates. Choose **Dress-up**, try each base, hat, and top, and check that the visible companion changes right away. Run each input with a hat on and check that the hat stays inside the window during the backflip and inflation.

Flutter analysis and all 274 tests passed, and the debug APK built. The companion hasn't been run on a device yet.

## Live telemetry API

From `mobile/`, run the app and enter your test patient ID in **Settings**. You can also supply an initial ID when running the app. `BATCH_API_URL` is the full POST URL, including `/batches`. The deployed endpoint below is the default. Configure a different full URL to use a test server. Rebuild or rerun after changing a build-time setting. [Deployed API documentation](https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/docs)

```sh
flutter run \
  --dart-define=BATCH_API_URL=https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/batches \
  --dart-define=BATCH_PATIENT_ID="$IXLAND_TEST_PATIENT_ID"
```

**Batch JSON (debug)** displays the POST body, with the batch duration in `extra.batch_interval_in_seconds`. The status below the title shows storage, rejection, uncertain delivery, or a missing setting. A jammed or unconfigured sender keeps the buffer. After an uncertain delivery, the sender retries the same body and batch number, even if Debug jam is switched on and off in between. The queue is in memory for the current session.

Run `flutter test` and `flutter analyze` for fixture verification. `telemetry_api_test.dart` uses a loopback HTTP server to verify the method, URL path, JSON, acknowledgments, and error handling. `device_flow_test.dart` verifies that the preview and POST body match, that jammed batches never reach the gateway, and that the merged batch uploads once the jam clears.

## Patient ID settings

On **Connected devices → Settings**, the **Patient ID** field shows the active ID. Edit it and tap **Save patient ID** to apply it, or tap **Create patient** to get a new ID from the API.

Android stores the saved value in private app preferences via the `ixland/patient_settings` channel. A saved value takes precedence over the optional `BATCH_PATIENT_ID` build-time default. IDs accept 1–128 ASCII letters, digits, hyphens, and underscores. An invalid edit leaves the last saved ID active.

New readings use the saved ID immediately. The first ID also claims readings buffered before any ID was configured. Readings already assigned to an ID keep it through upload retries. The app groups batches by patient, provider, and device to keep their samples separate.

To check on the phone, save a test ID, restart the app, and reopen Settings. Connect a wearable and compare the saved value with `patient_id` in the debug JSON. **Debug jam** lets you check the payload while skipping the upload. Flutter tests verify edits, restoration through a mocked preferences channel, and separate uploads across a change of patient ID.

## Create a patient through the API

**Create patient** sends `POST /patients` with `{"name":"IXLand patient"}`. The API requires a name, so the button uses a placeholder to keep creation to one tap. The API generates the ID. The app validates the `patient_id` in the HTTP 201 response and saves it to Android preferences before using it for new readings. [Deployed API documentation](https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/docs)

`PatientApi` in `mobile/lib/sync/patient_api.dart` derives the creation URL from `BATCH_API_URL` by replacing the last path segment with `patients`. A rejection or unconfirmed creation leaves the current ID active. The app sends one request per creation attempt. If Android fails to save a confirmed ID, tapping **Create patient** again in the same app session retries saving that ID.

`patient_api_test.dart` exercises the HTTP contract against a local server. `patient_settings_test.dart` covers saving and restoring a returned ID and retrying a failed local save. `device_flow_test.dart` checks that clicking **Create patient** puts the new ID on the next batch while telemetry already buffered for the previous ID keeps its assignment.

## Batch temperature and cumulative watch steps

The shared buffer accepts heart-rate, temperature, and cumulative step samples independently. For each upload, the telemetry gateway averages the available Celsius readings within the API's 30–45 °C range, rounds upward to one decimal, and sends one scalar. For example, 33.02 and 33.08 average to 33.05 and send as `33.1`. A batch without a valid reading keeps temperature missing. The gateway omits the field on the wire because the deployed batch contract defines an optional number.

The Galaxy Watch4 lacks an infrared skin-temperature sensor. The WHOOP 4.0 heart-rate stream lacks temperature, and NOOP documents the historical v24 temperature field as a raw ADC value of unresolved calibration. Those sources currently leave temperature missing. The direct WHOOP adapter also lacks a verified step-count record. [Samsung temperature support](https://www.samsung.com/uk/support/apps-services/how-to-use-the-menstrual-skin-temperature-sensor-with-samsung-health/) · [NOOP WHOOP 4.0 sensor records](https://github.com/ryanbr/noop/blob/main/docs/PROTOCOL_SENSORS.md#whoop-4-historical-v24)

The Wear OS companion subscribes to the Health Services `STEPS_DAILY` counter while a foreground measurement is running. It sends the reported count on `/ixland/steps/v1` when Health Services delivers it and alongside heart-rate updates so later batches can include the current count. Wear OS resets the counter at local midnight and controls when new readings arrive. The buffer sends the last reported count, including zero after a reset. Denying the watch's physical activity permission leaves heart-rate collection available. [Wear OS Health Services compatibility](https://developer.android.com/health-and-fitness/health-services/compatibility#passive-monitoring-client)

Build and update both Android APKs, open **IXLand Watch**, tap **Start**, and grant physical activity access. With the phone connected to the watch in IXLand, take a few steps and compare successive `steps` values under **Batch JSON (debug)**. The Flutter tests cover translation of step messages, reset to zero, merged windows, missing temperature, and averaging and rounding of valid readings.

## Heart-rate sample timestamps

The WHOOP and Samsung adapters capture the phone's receipt time on each heart-rate event. The batch buffer stores those times with their readings and serializes them as UTC ISO 8601 strings. Every batch POST includes the top-level `sample_timestamps` array in the same order as `hr`. Filtering out a BPM value removes the corresponding timestamp. Temperature and step totals remain batch fields.

**Batch JSON (debug)** shows the POST body. A merged batch retains each reading's receipt time, and an unconfirmed upload retries the original pairs. Flutter buffer, widget, and loopback HTTP tests cover these paths. Live upload requires the backend update that accepts the field. [Deployed API documentation](https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/docs)

## Heart-rate-only sleep estimation

`mobile/lib/wearables/sleep_estimator.dart` looks for a completed low-heart-rate period in the existing WHOOP and Samsung streams. It calculates a median for each UTC minute with at least three valid BPM readings and keeps up to 24 hours of history per patient, provider, and device. The threshold is 105% of the 10th percentile of those minute medians. A candidate needs at least 60 covered minutes below or at the threshold, then 15 consecutive covered minutes above it. Short interruptions can stay within the candidate. More than five missing minutes break the candidate. The estimated wake time is the start of the confirmed higher-heart-rate run. [NOOP heart-rate-only approach](https://github.com/ryanbr/noop/blob/main/Packages/StrandAnalytics/Sources/StrandAnalytics/SleepStager.swift#L3025)

The estimator operates after each UTC minute closes. The buffer holds a confirmed pair until the backend acknowledges its batch. A rejected batch can still grow, and an uncertain delivery retries its immutable body. If a short upload interval already sent the wake readings, the pair can travel in its own batch. `extra.sleep_start` and `extra.sleep_end` appear together in **Batch JSON (debug)**. The estimate and pending batches are held in memory during the current app session.

The estimate requires overnight heart-rate coverage, with the watch companion open and measuring for Samsung. It can confuse sustained quiet wakefulness with sleep. The window provides timing only. The backend still needs beat-to-beat intervals for HRV.

`flutter test test/sleep_estimator_test.dart` covers a session spanning midnight, transient spikes, sparse data and disconnect gaps, patient and device isolation, the POST shape, and acknowledgment and retry behavior. Verify estimates against a recorded sleep window on a physical wearable before using them for recovery assessments.

## Simulated night replay

In a debug build, open **Connected devices → Settings** and tap the moon icon labeled **Replay simulated night**. The replay uses 23:14 on the previous local calendar date through 06:57 on the phone's current date. It generates three BPM readings per minute with a sleeping average of 53 BPM, followed by 15 minutes of higher readings to confirm the estimated wake time. The screen displays the estimated times in local time and the batch timestamps in UTC.

The replay uses a separate in-memory batch buffer and the regular telemetry payload mapper. Its local sender captures the session batch for display and acknowledges the other synthetic batches in memory. It does not use the active patient ID or send HTTP requests.

`flutter test test/simulated_night_test.dart` checks the average, the exact boundaries, and the JSON fields using a fixed local date.

## Kotlin 2.3 build upgrade

The Android build uses the Kotlin Gradle plugin 2.3.21 in `mobile/android/settings.gradle.kts`. Google's LiteRT-LM Android library (`com.google.ai.edge.litertlm:litertlm-android` 0.19.1), planned for the on-device companion model, is compiled against Kotlin 2.4 metadata, and the earlier 2.1 compiler cannot read it. Kotlin 2.3 rejects the old `kotlinOptions { jvmTarget = ... }` block, so `mobile/android/app/build.gradle.kts` and `mobile/android/wear/build.gradle.kts` set the same JVM 11 target through `kotlin { compilerOptions { ... } }`. The Android Gradle plugin stays at 8.9.1 and Gradle at 8.12.

The commit before the upgrade is tagged `pre-kotlin-upgrade`. To verify, run `flutter analyze`, `flutter test`, and `flutter build apk --debug` in `mobile/`, and `./gradlew :wear:assembleDebug` in `mobile/android/`. A temporary build that added the LiteRT-LM dependency and constructed an `Engine` compiled with this setup. The dependency itself is added with the model harness.

## On-device Gemma model files

The companion assistant uses Gemma 4 E2B in the LiteRT-LM format, the file `gemma-4-E2B-it.litertlm` (about 2.59 GB, Apache 2.0, not gated) from [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm). Model files are too large for git and the APK. Keep them in the `models/` folder next to the repository checkouts, outside git:

```text
ada_hack/
├── ixland/          Codex checkout (master)
├── ixland-claude/   Claude worktree
└── models/
    └── gemma-4-E2B-it.litertlm
```

Download the file once from the `ada_hack/` folder:

```sh
mkdir -p models
curl -L -C - -o models/gemma-4-E2B-it.litertlm \
  https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
```

`-C -` resumes an interrupted download. During development, copy the model to the phone app's external files folder with ADB. That folder needs no storage permission and is deleted when the app is uninstalled. Both checkouts build the same application ID and share this folder on the phone.

```sh
adb shell mkdir -p /sdcard/Android/data/com.ixland.ixland_mobile/files/models
adb shell chmod 2775 /sdcard/Android/data/com.ixland.ixland_mobile/files/models
adb push models/gemma-4-E2B-it.litertlm /sdcard/Android/data/com.ixland.ixland_mobile/files/models/
```

A folder created by `adb shell mkdir` belongs to the shell user and blocks the app, so the chat reports the model as missing. The `chmod` line fixes that. The app also creates the folder itself when the chat opens, so after the app has opened the chat once, `adb push` alone is enough.

Check free phone storage first with `adb shell df -h /data`. E2B needs roughly 2.6 GB of storage and several GB of free RAM while loaded. The larger E4B file (3.66 GB) is not used on the test phone.

## Companion chat with on-device Gemma

Tap the companion to open a chat with Gemma 4 E2B running on the phone through Google's LiteRT-LM. The companion hurries to the top-right corner at eight times its walking speed. There the window grows to the usable screen around it, a dim backdrop and the chat panel fade in, and the character stays in place at its normal size as the chat head. After the chat closes, the window shrinks around the character and it hurries back to where it was. Type a message and the reply streams in. Tap the head, the backdrop, **Close chat**, or Back to close it. The window returns to the character's earlier spot. While the chat is open, the companion ignores other gestures and moves from the main app.

Messages and the model's conversation exist in memory only. Closing and reopening the chat keeps them. **New chat** clears them. When the companion window closes, the chat is discarded and the model unloads to free its memory. Nothing is sent over the network or written to storage, and native logs contain only load and reply timings and chunk counts, never message text.

| Path | Role |
| --- | --- |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/AssistantEngine.kt` | One LiteRT-LM engine and conversation per app process. Loads, replies, cancels, resets, and unloads on a background thread. Holds the short system instruction. |
| `mobile/android/app/src/main/kotlin/com/ixland/ixland_mobile/AssistantBridge.kt` | `ixland/assistant` method channel and `ixland/assistant/events` reply stream for a Flutter engine. The overlay engine registers it. |
| `mobile/lib/assistant/assistant_engine.dart` | `AssistantEngine` interface and the native implementation. Each reply has an ID chosen by Dart, so chunks from different replies don't mix. |
| `mobile/lib/assistant/assistant_chat.dart` | In-memory messages, model state, send, stop, and new chat. |
| `mobile/lib/companion/companion_chat_panel.dart` | Chat panel: status line, messages, text field, send, stop, new chat, and close. |
| `mobile/lib/companion/companion_overlay_app.dart` | Opens the chat from the tap action, animates the head, and collapses the window afterward. |

Decisions:

- The model runs in native Kotlin through LiteRT-LM 0.19.1 rather than a Flutter plugin. It's Google's supported runtime, it supports tool calling for the next step, and both Flutter engines can share one loaded model. The `flutter_gemma` plugin was discontinued in October 2026.
- The model loads when the chat first opens. Loading takes several seconds, and the status line shows the time it took. The send button stays disabled until the model is ready.
- Inference uses the CPU by default. To try the GPU, build with `--dart-define=ASSISTANT_BACKEND=gpu`. The manifest declares the optional OpenCL libraries LiteRT-LM needs for the GPU.
- Android shows the overlay's last frame stretched to a new window size until Flutter draws one at that size. The overlay therefore draws nothing while the window expands or collapses, about 0.2 s, and waits until Flutter reports the new size. It then shows the character, builds the panel on the next frame, and fades the panel in. The model starts loading after the fade, because loading keeps the CPU busy and would delay those frames.
- While the chat is open, the head slides up by the empty space above the character, 38% of its box, and the panel starts just below the character. While the keyboard is open, the head shrinks to 60% in the top-right corner and the panel moves up with it. Both changes animate over the 180 ms fade and reverse before the window collapses, so the character is back where it was when the window shrinks.
- In a debug build, the first panel build takes about 0.7 s while the character waits at the top. Later openings are faster.
- While the chat is open, the window is focusable so the keyboard can type into it, and it uses `SOFT_INPUT_ADJUST_RESIZE`. The panel also pads itself by the keyboard inset. Back is intercepted in the window's root view and closes the chat.
- The system instruction comes from `mobile/assets/soul.md`. See [Companion soul](#companion-soul). API tools come later.

To verify, copy the model to the phone as described in [On-device Gemma model files](#on-device-gemma-model-files), then install the app, show the companion, and tap it. Check load and reply timings with `adb logcat -s AssistantEngine`. If the model file is missing, the chat shows the path the app expects. `flutter test test/assistant_chat_test.dart test/companion_test.dart` covers the chat state, the channel protocol, opening and closing the chat, streaming, Back, and the missing-model message.

## Fetch monitoring states with telemetry

When `TelemetryApi` sends a batch, it concurrently calls `GET /patients/{patient_id}/states` at the base URL configured by `BATCH_API_URL`, including on retries. Debug jam and a missing patient ID prevent both requests. The POST determines batch acknowledgment. The fetch can observe the previously evaluated state if the backend is still processing the concurrent POST.

## Monitoring state alerts

**Connected devices** shows **Monitoring state cache (debug)** next to the batch diagnostics. The cache is in memory for the configured patient and clears when that ID changes or when the screen is recreated. A state tracks its latest status, previous status, and three flags named `summon`, `addressed`, and `resolved`. The app ranks `normal` below `warning` and HRV `unbalanced`, then `critical` and HRV `low`, then `emergency`. An empty or unknown status is unassessed. The first observed abnormal status counts as worsening.

Worsening raises all three flags. When the companion is visible, the app clears the summon flags and starts a check-in if the monitoring response has a prompt. A response without prompts uses one alert listing each addressed state and its status. A successful handoff clears the addressed flags. The raised `resolved` flag keeps the worse previous status on improvement and stays raised pending a resolution action. Swiping the companion away raises `addressed` again for every state with `resolved` set, including states that have returned to normal. The notification's **Stop** action stops the service. There is no timed summon.

From `mobile/`, run `flutter test test/telemetry_api_test.dart test/companion_test.dart test/device_flow_test.dart`. The fixtures cover the per-patient GET, independent batch acknowledgment, prompt delivery, the combined alert, and swipe-triggered resummoning. On Android, grant overlay access through **TEST** and use a synthetic patient with multiple states. Return a previously abnormal state to normal, swipe the companion away, and verify that the companion returns while that state's `resolved` flag is set.

## Companion soul

`mobile/assets/soul.md` defines who the companion is. It's a medical help assistant for a recently discharged patient. It answers only questions about health and medicine. For any other topic, it replies with exactly "I don't know that, I'm a medical expert." A few example exchanges in the file show the model when to refuse and when to answer. It greets back briefly when greeted. It tells the patient to call emergency services first for symptoms that could be an emergency, and it sends treatment decisions, such as changing a medicine, to the care team. Replies are brief plain text in the patient's language.

The file is a Flutter asset, so edit it without touching code. It lives under `mobile/assets/` rather than `docs/` because the app reads it at runtime. `NativeAssistantEngine` reads it and sends it as `systemInstruction` with the `load` call. `AssistantEngine.kt` uses it as the LiteRT-LM system instruction. If the instruction changes while the model is loaded, the conversation starts over. A short fallback in `AssistantEngine.kt` applies only if no instruction arrives.

A 2B model follows these rules most of the time, not always. Check new wording on the phone with one medical and one unrelated question. `flutter test test/assistant_chat_test.dart` checks that the asset is bundled with the refusal sentence and that `load` sends it.

## Monitoring check-in with a system prompt and tool

Each state from `GET /patients/{patient_id}/states` includes a top-level `prompt`, written by the doctor or generated by the API. `mobile/lib/companion/companion_monitoring.dart` joins the nonblank prompts from the latest response for the configured patient in response order, with a blank line between them. The combined prompt includes instructions from every state in that response, including normal states. A prompted summon opens the check-in directly, including when a state with a prompt escalates to critical or becomes critical again after recovery. The Android service queues the prompt until the overlay is ready. [Deployed monitoring state schema](https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/openapi.json)

`mobile/lib/assistant/assistant_engine.dart` appends the combined prompt to `soul.md` and passes the result as the system instruction over `ixland/assistant`. The prompt text is kept in memory and excluded from the monitoring debug cache and app logs. Tapping the character opens the pending check-in or resumes the existing conversation. Closing the chat panel keeps the conversation in memory for the life of the companion window. A changed prompt starts a fresh check-in, and switching the configured patient discards the previous patient's check-in.

The existing LiteRT-LM 0.19.1 dependency registers `report_heart_rate_check_in` for check-in conversations. `HeartRateCheckInTool.kt` accepts the patient's description and their optional SpO₂ percentage. The first valid call shows **Check-in preview** on the phone. The report is held in memory and the preview makes no HTTP request. The report callback in `CompanionOverlayService.kt` is the point to wire up the future API. [LiteRT-LM tool registration](https://developers.google.com/edge/litert-lm/android#registering_tools)

Run `flutter test test/assistant_chat_test.dart test/companion_test.dart test/device_flow_test.dart test/telemetry_api_test.dart`, `flutter analyze`, and `flutter build apk --debug` from `mobile/`. To exercise Gemma on Android, install the [model file](#on-device-gemma-model-files), grant overlay access, and use a synthetic patient with at least two states whose `prompt` fields ask different questions. Mark one state as warning or critical. After a telemetry batch, confirm that the chat opens by itself and follows both prompts. Close the panel and tap the character to check that the conversation resumes. If a prompt asks Gemma to call the heart-rate report tool, check that the preview alert appears once.

## Emergency monitoring alert

On a transition to `output.status: emergency`, the app summons the companion if needed, closes any check-in, and immediately shows a fixed message asking the patient to contact their medical team because the monitoring results indicate a risk of complications. The alert works independently of Gemma and takes priority while any state remains at `emergency`. Pending lower-priority alerts and check-ins can resume when the emergency clears. Identical snapshots leave the alert acknowledged. Swiping the companion away re-arms the alert while the state is in emergency.

From `mobile/`, run `flutter test test/companion_test.dart test/telemetry_api_test.dart`. On Android, grant overlay access and use a synthetic patient whose monitoring response changes from `critical` to `emergency`, first with the companion hidden and again while a check-in is open. Verify that the care-team message appears in both cases. The live schema currently lists `critical` as the highest documented status for declarative models, so the fixture must emit `emergency` explicitly. [Deployed OpenAPI schema](https://europe-west3-pati-api-8fac6.cloudfunctions.net/api/openapi.json)
