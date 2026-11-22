# IXLand user guide

IXLand is an Android app for monitoring after a hospital stay. It sends readings from a paired wearable to the monitoring service for your patient ID. The animated companion can open a chat or show a monitoring alert.

## Set up the phone

1. Install the IXLand Android installation file (APK) provided by your setup team and open **IXLand**.
2. On **Sign in**, tap **Continue** to open **Connected devices**. The prototype uses a patient ID to assign your readings.
3. Tap the **Settings** gear and scroll to **Patient ID**. Enter the ID you were given and tap **Save patient ID**. For a new demo record, tap **Create patient** if your setup team directs you to do so. The app saves the ID it receives.
4. Go back to **Connected devices** and tap **Add device**. Choose your wearable below. IXLand connects to one wearable at a time.

## Connect a WHOOP 4.0

1. Turn on Bluetooth and keep the strap near your phone. Slide a charged battery pack onto the strap to wake it. A flashing blue light means it is ready to pair.
2. In **Add device**, choose **WHOOP**, then tap **Scan for WHOOP**. Allow Bluetooth access when Android asks.
3. Select your strap and confirm the Android pairing prompt if it appears. Wear the strap and wait for your heart rate to appear on **Connected devices**.

If the strap connects but your heart rate stays blank, check that the strap is against your skin. You can also enable **Heart Rate Broadcast** in the WHOOP app and reconnect in IXLand.

## Connect a Samsung Galaxy Watch4

1. Pair the watch with your phone in **Galaxy Wearable**. Install and open **IXLand Watch** on the watch. The watch uses its own APK. [Watch installation instructions](mobile-implementation.md#build-and-install-ixland-watch)
2. On the phone, open **Add device**, choose **Samsung Galaxy Watch**, tap **Scan for Samsung Galaxy Watch**, and select the watch.
3. On the watch, tap **Start** and allow heart-rate access. Allow physical activity access to share steps as well.
4. Wear the watch and keep **IXLand Watch** open while measuring. Check that the phone shows your heart rate in BPM.

Tap **Stop** on the watch to end measurement. To switch wearables, tap **Disconnect** on **Connected devices**, then use **Add device** again.

## Check that readings are uploading

**Connected devices** shows your latest heart rate and **Samples in batch**. The app tries to upload completed batches every minute by default. When the first upload is attempted, the status appears under **Batch JSON (debug)**. **Uploaded (HTTP 201)** means the monitoring service accepted the batch.

If an upload fails, check your internet connection and the saved **Patient ID**. Leave **Debug jam** off for normal uploads. The app keeps pending readings in memory and retries while the session is running. If you are waiting for a retry, keep IXLand running.

## Use the companion

1. On **Connected devices**, tap **TEST** to show the companion. If Android opens **Display over other apps**, enable it for IXLand and return. The character can appear over the home screen and other apps.
2. Tap the character to open chat. The Gemma model loads on the phone the first time chat opens. If you see **Model file not found**, follow [Set up Gemma chat](#set-up-gemma-chat).
3. Type a message and tap **Send**. Tap **Close chat** to close the panel. Tap the character again to resume the conversation. **New chat** clears the conversation.

When the monitoring service requests a check-in, the companion can appear and open chat automatically. Answer its questions in chat. If you see **Check-in preview**, that preview stays on your phone. If the app displays an **Emergency monitoring alert**, it asks you to contact your medical team immediately.

Open **Settings** and use **Shape**, **Hat**, and **Top** under **Companion style** to change the character’s appearance. Swipe the character left or right to send it away. A pending monitoring alert can bring it back. To stop the companion service, tap **Stop** in the **IXLand companion** Android notification.

Wearable batches go to the monitoring service. Chat runs on your phone, and the conversation stays in memory while the companion window is running.

## Troubleshooting

| What you see | What to try |
| --- | --- |
| **No devices found** | For WHOOP, check Bluetooth and wake the strap. For Galaxy Watch4, open **IXLand Watch** and check that the watch is paired with this phone. Then scan again. |
| **Waiting for heart rate** | Wear the device snugly. On Galaxy Watch4, check heart-rate access, tap **Start**, and keep the watch app open. |
| Readings appear and uploads remain pending | Check your network connection, saved **Patient ID**, and **Debug jam** setting. |
| The companion does not appear | Tap **TEST** and check that **Display over other apps** is enabled for IXLand. |
| **Model file not found** | Copy the Gemma model to the folder shown in the chat. See [Set up Gemma chat](#set-up-gemma-chat). |

## Set up Gemma chat

On-device chat is available on Android devices that use `arm64-v8a` or `x86_64`. Gemma 4 E2B uses a separate model file, `gemma-4-E2B-it.litertlm`, which takes about 2.6 GB of storage. Ask your setup team to copy it to your phone if chat reports that the model is missing.

For the person setting up the device, open companion chat once so IXLand creates its `models` folder. With Android Debug Bridge (ADB) connected to the phone, run the following command from the folder containing the downloaded model. Replace `PHONE_SERIAL` with the phone's identifier from `adb devices`.

```sh
adb -s PHONE_SERIAL push gemma-4-E2B-it.litertlm /sdcard/Android/data/com.ixland.ixland_mobile/files/models/
```

Close and reopen the chat to load the model. The first load can take several seconds. [Model download and installation details](mobile-implementation.md#on-device-gemma-model-files)
