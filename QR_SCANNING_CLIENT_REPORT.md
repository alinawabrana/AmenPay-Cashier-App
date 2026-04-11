# QR Scanning (AmenPay Cashier POS) — Code + Recent Error Logs

This document summarizes the QR scanning implementation in the AmenPay Cashier POS app and includes the recent logs shared during troubleshooting.

## 1) High-level flow

The app supports receiving a QR payload through three inputs:

1. **Serial (UART)**
   - Primary path for embedded POS scanners using a serial device node (example: `/dev/ttyHSL3`).
   - On Android, the app tries the vendor `SerialPortAdapter` first and falls back to a raw `FileInputStream` read.

2. **Broadcast-based scanners**
   - Common for OEM “scan wedge” integrations that broadcast an intent (e.g., Zebra DataWedge).
   - On Android, the app registers a receiver and extracts QR text from intent extras.

3. **HID keyboard wedge**
   - Some scanners inject keystrokes as if from a keyboard.
   - Android captures keystrokes and emits a QR payload after a terminator (Enter/Tab) or after a short inactivity debounce.

All three sources emit events into the same Flutter stream: `qrScanner/events`.

## 2) Flutter code (consuming QR payloads)

File: `lib/features/home/screens/enroll_palm_vein_screen.dart`

### 2.1 Channels used by Flutter

```dart
class _PalmHardware {
  static const MethodChannel _posDeviceMethods = MethodChannel('posDevice/methods');
  static const MethodChannel _qrScannerMethods = MethodChannel('qrScanner/methods');
  static const EventChannel _qrScannerEvents = EventChannel('qrScanner/events');
  static const MethodChannel _palmEnrollmentMethods = MethodChannel('palmEnrollment/methods');

  static Stream<Map<String, dynamic>> qrEvents() {
    return _qrScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'payload': event.toString(), 'source': 'raw'};
    });
  }

  static Future<String?> scanQrOnce({required int timeoutMs}) async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'scanQrOnce',
      <String, dynamic>{'timeout_ms': timeoutMs},
    );
    return res?.toString();
  }
}
```

### 2.2 Subscribing to continuous QR events

This stream is used to auto-fill the QR field and optionally trigger auto-claim:

```dart
_qrSubscription = _PalmHardware.qrEvents().listen(
  (event) {
    final payload = event['payload']?.toString() ?? '';
    final source = event['source']?.toString() ?? '';
    final action = event['action']?.toString();
    final devicePath = event['device_path']?.toString();
    final extraKey = event['extra_key']?.toString();

    final value = payload.trim();
    if (!mounted || value.isEmpty) return;

    setState(() {
      _qrDataController.text = value;
    });

    _log('QR payload received', <String, Object?>{
      'qr_data': _redactText(value),
      if (source.isNotEmpty) 'source': source,
      if (action != null && action.isNotEmpty) 'action': action,
      if (devicePath != null && devicePath.isNotEmpty) 'device_path': devicePath,
      if (extraKey != null && extraKey.isNotEmpty) 'extra_key': extraKey,
    });
    _maybeAutoClaim(value);
  },
  onError: (Object error, StackTrace stackTrace) {
    _log('QR stream error', <String, Object?>{'error': error.toString()});
  },
);
```

### 2.3 One-shot scan button

This method triggers a one-time scan with timeout:

```dart
Future<void> _scanQrOnce() async {
  try {
    _log('scanQrOnce started');
    final qr = await _PalmHardware.scanQrOnce(timeoutMs: 15000);
    final value = qr?.trim();
    if (value == null || value.isEmpty) {
      _log('scanQrOnce empty');
      return;
    }
    setState(() {
      _qrDataController.text = value;
    });
    _log('scanQrOnce received', <String, Object?>{
      'qr_data': _redactText(value),
    });
  } on PlatformException catch (e) {
    _log('scanQrOnce platform error', <String, Object?>{
      'code': e.code,
      'message': e.message,
    });
  } catch (e) {
    _log('scanQrOnce error', <String, Object?>{'error': e.toString()});
  }
}
```

## 3) Android code (producing QR payloads)

File: `android/app/src/main/kotlin/com/example/amenpay_cashir_app/MainActivity.kt`

### 3.1 Flutter channels on Android

Android registers:
- `EventChannel("qrScanner/events")` to stream scan events to Flutter
- `MethodChannel("qrScanner/methods")` to support `scanQrOnce`, diagnostics, and device path settings

```kotlin
EventChannel(flutterEngine.dartExecutor.binaryMessenger, "qrScanner/events")
  .setStreamHandler(object : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
      qrEventSink = events
      startQrReaderIfNeeded()
      startQrBroadcastIfNeeded()
    }

    override fun onCancel(arguments: Any?) {
      qrEventSink = null
      stopQrReader()
      stopQrBroadcast()
    }
  })
```

### 3.2 Serial reader (adapter first, raw fallback)

The reader tries vendor `SerialPortAdapter` first:

```kotlin
val adapter = SerialPortAdapter()
val initOk = adapter.init(this@MainActivity, devicePath, bitrate)
if (initOk) {
  adapter.startRead(object : HWDataCallBack {
    override fun onDataReceived(data: ByteArray, len: Int) {
      val chunk = String(data, 0, len.coerceAtMost(data.size), Charset.forName("UTF-8"))
      // split on terminators and emit payload
    }
    override fun onError(msg: String) {
      emitQrError("QR_ADAPTER_ERROR", msg.trim().ifEmpty { null })
    }
  })
  return@Thread
}
```

If the adapter init fails, it falls back to raw reads:

```kotlin
val input = FileInputStream(devicePath)
val buffer = ByteArray(256)
val sb = StringBuilder()
val charset = Charset.forName("UTF-8")

while (qrReaderRunning.get()) {
  val read = input.read(buffer)
  if (read <= 0) continue
  val chunk = String(buffer, 0, read, charset)
  for (ch in chunk) {
    if (qrTerminators.contains(ch)) {
      val payload = sb.toString().trim()
      sb.setLength(0)
      emitQrPayloadIfNew(payload)
    } else {
      sb.append(ch)
    }
  }
}
```

### 3.3 Broadcast-based scanner receiver

Android registers a broadcast receiver for common OEM scanning actions and extracts payload from extras.
If a payload is found, it is emitted to Flutter as `source="broadcast"`.

### 3.4 HID keyboard wedge capture

Android captures keystrokes and emits a payload:
- immediately on Enter/Tab, OR
- after a short inactivity debounce (for scanners that do not send Enter)

## 4) Recent error logs (shared during troubleshooting)

### 4.1 Updated logs: repeated timeouts, bytes_total=0

```
[2026-02-04T06:40:14.619841] Device id loaded {"device_id":"f99699e1b9e5b8f6"}
[2026-02-04T06:40:14.646855] QR device diagnostics {"qr_device_path":"/dev/ttyHSL3","qr_device_candidates":[{"path":"/dev/ttyHSL3","exists":true,"can_read":true,"can_write":true},{"path":"/dev/ttyHSL0","exists":true,"can_read":false,"can_write":false},{"path":"/dev/ttyHSL1","exists":true,"can_read":true,"can_write":true},{"path":"/dev/ttyHSL2","exists":true,"can_read":true,"can_write":true}]}
[2026-02-04T06:40:51.817014] scanQrOnce started
[2026-02-04T06:41:16.832271] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
[2026-02-04T06:41:47.434067] scanQrOnce started
[2026-02-04T06:42:12.442888] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
[2026-02-04T06:42:23.729943] scanQrOnce started
[2026-02-04T06:42:48.742359] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
[2026-02-04T06:42:50.135185] scanQrOnce started
[2026-02-04T06:43:15.146511] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
[2026-02-04T06:43:26.145248] scanQrOnce started
[2026-02-04T06:43:51.156009] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
[2026-02-04T06:43:52.328233] scanQrOnce started
[2026-02-04T06:44:17.336443] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
[2026-02-04T06:44:19.731548] scanQrOnce started
[2026-02-04T06:44:44.742765] scanQrOnce platform error {"code":"QR_SCAN_FAILED","message":"Timed out waiting for QR payload. Reader is running, but no new scan arrived within 15000ms (last_scan_age_ms=-1, bytes_total=0, frames_total=0, last_byte_age_ms=-1, last_terminator_age_ms=-1, path=/dev/ttyHSL3 exists=true canRead=true canWrite=true)."}
```

### 4.2 Log after scanning QR without clicking “Scan Enrollment QR”

```
[2026-02-05T22:43:53.436529] Device id loaded {"device_id":"f99699e1b9e5b8f6"}
[2026-02-05T22:43:53.474556] QR device diagnostics {"qr_device_path":"/dev/ttyHSL3","qr_device_candidates":[{"path":"/dev/ttyHSL3","exists":true,"can_read":true,"can_write":true},{"path":"/dev/ttyHSL0","exists":true,"can_read":false,"can_write":false},{"path":"/dev/ttyHSL1","exists":true,"can_read":true,"can_write":true},{"path":"/dev/ttyHSL2","exists":true,"can_read":true,"can_write":true}]}
```

## 5) What these logs indicate (summary)

- The serial device node exists and is readable/writable by the OS user running the app.
- The QR scan attempts time out with `bytes_total=0`, which indicates the app is not receiving any bytes from `/dev/ttyHSL3` during scans.
- Common root causes (device-side):
  - Scanner is configured as **HID** (keyboard wedge) instead of UART.
  - Scanner is configured to send data via an **OEM broadcast** integration.
  - UART routing/permissions/service prerequisites for the vendor serial driver are not satisfied on that firmware image.

