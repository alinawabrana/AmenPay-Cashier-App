# POS Palm Enrollment — Hardware Details (Android POS + Flutter)
This document focuses on the POS-side hardware work required to support palm vein enrollment:
- Reading an enrollment session QR payload (scanner/camera)
- Running the Leshun palm enrollment SDK to obtain `template_id`
- Bridging the native Android SDKs into Flutter

Customer app hardware integration is out of scope here (customer only shows QR and polls backend).

## 1) Hardware overview for enrollment
### 1.1 Components
- Android POS device
- QR reader
  - Serial port scanner (common) or camera
- Palm vein scanner device (vendor hardware)
- Vendor SDK libraries (.aar/.jar) and native libraries (.so)

### 1.2 Data outputs used by backend
POS must submit:
- `device_id` (stable per POS terminal)
- `template_id` (from palm SDK on success)
- Optional metadata when available:
  - `quality_score`
  - `liveness`

## 2) Serial QR scanner integration (common POS approach)
### 2.1 Device/port details referenced in project docs
- Port: `/dev/ttyHSL3`
- Baud rate: `9600`

These values are device-specific; confirm the actual port on your POS hardware image.

### 2.2 Native layer responsibilities (serial)
- Open the serial device file
- Configure baud rate
- Continuously read bytes and decode to text
- Emit one “scan event” per QR payload string
- Debounce repeated payloads (many scanners send the same payload multiple times)

### 2.3 Suggested Flutter bridge shape
- EventChannel: `qrScanner/events` streaming scanned strings
- MethodChannel: `qrScanner/methods` helper methods

Dart example surface:
```dart
abstract class QrScannerPlatform {
  Stream<String> scannedPayloads();
  Future<String> scanOnce({Duration timeout});
}
```

## 3) Palm enrollment SDK integration (Leshun)
### 3.1 SDK files you have locally
Palm SDK bundle:
- `/Users/alinawab/Downloads/leshun_plam_v2.10/libs/`
  - `BaseLine-1.00.aar`
  - `ShunPalm-2.01.aar`
  - `ShunPalm-LS2-2.10.aar`

Observed notable classes (high-level):
- `com.leshun.support.shunpalm.ls2.ShunPalmWorker` (in `ShunPalm-LS2-2.10.aar`)
- `com.api.stream.PalmSdk` (inside `ShunPalm-LS2-2.10.aar` embedded jar)

Hardware adapter jar (contains serial/NFC/system adapters):
- `/Users/alinawab/Downloads/LeShun Xinke LSF980 Series Horizontal Consumer Machine API User Manual V1.01/`
  - `com.leshun.hwadapter_1.13.jar` (contains `com.leshun.hwinf.SerialPortAdapter`, etc.)
  - `printsdk.jar` (also includes an `android_serialport_api` implementation)

### 3.2 Native layer responsibilities (palm SDK)
- Initialize the SDK and required dependencies
- Start enrollment
- Wait for SDK callback/result
- On success, extract `template_id` (+ optional quality/liveness)
- On failure, extract vendor error code + message
- Do not store raw palm images or frames

### 3.3 Suggested Flutter bridge shape (palm)
- MethodChannel: `palmEnrollment/methods`
- EventChannel (optional): `palmEnrollment/events` for progress hints / UI guidance

Dart return model shape:
```dart
sealed class PalmEnrollmentResult {}

final class PalmEnrollmentSuccess extends PalmEnrollmentResult {
  final String templateId;
  final int? qualityScore;
  final String? liveness;
  PalmEnrollmentSuccess(this.templateId, {this.qualityScore, this.liveness});
}

final class PalmEnrollmentFailure extends PalmEnrollmentResult {
  final String errorCode;
  final String? errorMessage;
  PalmEnrollmentFailure(this.errorCode, {this.errorMessage});
}
```

## 4) Integrating vendor SDKs into an Android module
This repo does not currently include these SDKs. The typical Android steps for a POS app:

### 4.1 Add .aar/.jar dependencies
Common patterns:
- Create `android/app/libs/` and place `.aar`/`.jar` there
- Configure Gradle to load them

Example Gradle Kotlin DSL snippet:
```kotlin
dependencies {
  implementation(files("libs/BaseLine-1.00.aar"))
  implementation(files("libs/ShunPalm-2.01.aar"))
  implementation(files("libs/ShunPalm-LS2-2.10.aar"))
  implementation(files("libs/com.leshun.hwadapter_1.13.jar"))
  implementation(files("libs/printsdk.jar"))
}
```

### 4.2 ABI / native libs
`ShunPalm-LS2-2.10.aar` includes native `.so` libraries (e.g., under `jni/arm64-v8a/`).
Ensure your POS device ABI matches (many POS devices are arm64).

### 4.3 Proguard / R8
If you build a release APK/AAB, keep rules may be required. Vendor provides `proguard.txt` inside the AARs; apply those rules as needed.

## 5) End-to-end POS enrollment flow (what Dart should orchestrate)
1. Receive `qr_data` from scanner/camera
2. Call backend `POST /api/palm/enroll/sessions/claim` with `{ qr_data, device_id }`
3. If claim succeeds, call `startPalmEnrollment()` on native layer
4. On success, call backend `POST /api/palm/enroll/sessions/{session_id}/submit-result`
5. Display success/failure UI on POS

Backend error codes to map in POS UI (examples from docs):
- `INVALID_QR`, `SIGNATURE_INVALID`
- `SESSION_EXPIRED`, `SESSION_ALREADY_CLAIMED`, `SESSION_ALREADY_ENROLLED`
- `SESSION_DEVICE_MISMATCH`
- `ALREADY_ENROLLED`, `TEMPLATE_ALREADY_LINKED`

## 6) Android permissions and device constraints
The exact permissions depend on your POS firmware and SDK requirements:
- Serial device access often requires elevated permissions or vendor ROM support.
- USB/OTG-based scanners may need USB host permissions and a device filter.

Treat these as “hardware bring-up” items to verify on the target POS device image.

## 7) Verification checklist (POS)
- Serial scan produces correct QR payload string in Flutter
- Claim endpoint works and binds to stable `device_id`
- Palm SDK enrollment returns `template_id`
- Submit-result succeeds and backend marks session as `enrolled`
- Customer app sees enrollment via polling (`enrolled`)
