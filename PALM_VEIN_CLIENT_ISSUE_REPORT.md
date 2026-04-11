# Palm Vein + NFC Integration Issue Report (Client Shareable)

## 1. Executive Summary (Non-Technical)

We tested Palm Vein enrollment on the Leshun LSP980 terminal and confirmed:

- QR scanner is working.
- Palm Vein hardware is detected by the app.
- Palm Vein SDK libraries are present in the app.
- The app crashes when Palm Vein enrollment starts.
- NFC factory test works on device, but app-side NFC runtime init fails on this firmware.

The crash is happening inside the vendor Palm SDK native runtime (after startup begins), not in normal app UI/business logic.

Current status: **app integration paths are correct, but vendor runtime/firmware compatibility is mismatched for Palm and NFC on this firmware build.**

---

## 2. Device and Build Context

- Device model: `LSP980`
- Android version: `7.1.2` (from field testing context)
- Hardware brand/product: `leshun / LSF8102WL980`
- Palm USB module detected: `VID 807 / PID 4105` (`Shiyun Veinshine 01`)
- App build marker tested: `amenpay-hwtest-r2026-03-03-15`

---

## 3. What Was Verified

1. Palm SDK classes are available at runtime:
   - `com.leshun.support.baseline.BaseLine`
   - `com.leshun.support.shunpalm.ShunPalm`
   - `com.leshun.support.shunpalm.ls2.ShunPalmWorker`
2. Palm USB module is detected and permission is granted.
3. Enrollment flow enters `engineBuild()` and receives callback state `WAITING`.
4. Process crashes before `SUCCEED`/`FAILURE` callback arrives.

This indicates failure in native vendor runtime after engine startup begins.

---

## 4. Key Diagnostic Evidence

Latest crash diagnostics:

- `report_schema_version = crash-diagnostic-v1`
- `app_build_marker = amenpay-hwtest-r2026-03-03-15`
- `palm_checkpoint.stage = callback_engineBuild`
- `palm_checkpoint.detail = WAITING`
- `palm_app_bootstrap.initialized = true`
- `palm_runtime_permissions_granted = true`
- No Java/Kotlin uncaught exception captured

Interpretation:
- App reaches Palm SDK engine build callback.
- Palm bootstrap is successful and permissions are already granted.
- Native layer crashes/hard-aborts after that point.
- Not a normal Dart/Flutter/Java exception path.

Additional evidence from full Android bug report (`log-record.txt`):

- Native abort captured at Palm start:
  - `JNI DETECTED ERROR IN APPLICATION: fid == null`
  - `Fatal signal 6 (SIGABRT)`
- Failing native entrypoint:
  - `com.api.stream.veinshine.DeviceImplVeinshine.nativeCreateIr(...)`
- Concrete missing field from runtime:
  - `NoSuchFieldError: no "J" field "mDeviceHandle" in class "Lcom/api/stream/veinshine/DeviceImplVeinshine;"`

Interpretation of this new evidence:
- This is a JNI/native contract mismatch (Java class/field expected by native `.so` does not match runtime class shape).
- Confirms the crash is inside vendor native Palm stack, not Flutter logic.

---

## 5. Why This Is Likely a Vendor SDK/Firmware Compatibility Issue

- SDK initializes and enters engine lifecycle.
- Crash occurs inside/after native engine startup.
- Full Android log proves JNI contract failure in vendor native Palm library (`fid == null`, missing `mDeviceHandle`).
- Same behavior persists even after:
  - adding required AAR/JAR dependencies,
  - runtime diagnostics and stage checkpoints,
  - packaging adjustments (ARMv7-only test build).

This pattern strongly matches binary compatibility mismatch between SDK bundle and firmware/hardware stack.

---

## 6. Request to Vendor / Device Provider (Action Required)

Please provide a **known-good Palm SDK package for this exact environment**:

- Device: `LSP980`
- Android: `7.1.2`
- Palm module: `VID 807 / PID 4105 (Veinshine 01)`

Required deliverables:

1. Exact compatible versions of:
   - `BaseLine-*.aar`
   - `ShunPalm-*.aar`
   - `ShunPalm-LS2-*.aar`
   - `hwadapter*.jar` (if required)
   - matching native `.so` set
2. Compatibility matrix (firmware build ↔ SDK versions).
3. Vendor demo APK built for the same firmware/device.
4. Confirmation whether additional firmware component/update is mandatory.

---

## 7. Recommended Next Validation

1. Install vendor-provided demo APK on the same terminal.
2. Test Palm enrollment.
3. Outcomes:
   - If demo also crashes: firmware/device stack issue.
   - If demo works: provide exact demo SDK bundle so app can align to same versions.

---

## 8. Notes

- Android 7.1.2 does not support modern process-exit history APIs used on Android 11+, so native crash reason cannot be fully auto-extracted from OS APIs.
- Current app diagnostics are already instrumented to capture enrollment stage boundaries for root-cause isolation.

---

## 9. NFC Card Integration Issue (Added)

### 9.1 Summary

- Android standard NFC framework is not exposed on this device image (client confirmed this can be normal for vendor-reader devices):
  - `has_feature_nfc = false`
  - `available = false`
- Vendor NFC wrapper class is present in app (`com.leshun.hwinf.NFCAdapter`), but vendor init fails for all card modes.

### 9.2 Latest NFC Evidence

Latest tested marker: `amenpay-hwtest-r2026-03-03-19`

- `vendor_hwinf_class_available = true`
- `vendor_hwinf_initialized = false`
- `vendor_hwinf_init_attempts = [CARD_TYPE_AUTO:false, CARD_TYPE_Mifare:false, CARD_TYPE_PlusCPU:false, CARD_TYPE_CPU:false]`
- `vendor_hwinf_last_error` includes:
  - vendor `NFCAdapter.init(...)` false for all card types

Android bug report consistency:
- No NFC crash/abort is seen.
- NFC behavior remains: framework not exposed (`has_feature_nfc=false`) and vendor init path returns false.
- So the issue remains a vendor runtime initialization/configuration mismatch, not a Flutter-side crash.

### 9.3 Interpretation

- This is not a Flutter UI issue and not an Android runtime permission issue.
- NFC fails at vendor `NFCAdapter` runtime initialization layer on this firmware build.
- Factory NFC test success indicates device hardware is present, but app runtime path is firmware/vendor-stack dependent.

### 9.4 Vendor JAR API Signature Verification (Completed)

We validated the actual class/method signatures directly from vendor JAR:

- Source JAR:
  - `HWAdapterTest/app/libs/com.leshun.hwadapter.jar`
- Verified NFC class:
  - `com.leshun.hwinf.NFCAdapter`
- Verified methods:
  - `getInstance()`
  - `init(Context, NFCInf.NFC_CARD_TYPE)`
  - `deInit()`
  - `startRead(HWDataCallBack)`
  - `startRead(HWDataCallBack, boolean)`
  - `stopRead()`
  - `readBlock(int, byte[], byte[], byte[])`
  - `writeBlock(int, byte[], byte[], byte[])`
  - `sendAPDU(byte[], int, byte[])`
  - `getATS(byte[])`
- Verified enum values:
  - `CARD_TYPE_AUTO`, `CARD_TYPE_Mifare`, `CARD_TYPE_PlusCPU`, `CARD_TYPE_CPU`

Conclusion:
- App-side NFC API mapping/class names match vendor JAR contract.
- Current failure is at vendor runtime init stage (`NFCAdapter.init(...)` returns false for all card types), not due to wrong method/class selection.

### 9.5 Vendor Action Required (NFC)

Please provide for the exact same terminal/firmware:

1. NFC-enabled firmware/runtime package where vendor NFC init succeeds.
2. Exact NFC API contract for this firmware variant:
   - expected `NFCAdapter` init behavior and required prerequisites on this firmware.
3. Known-good vendor demo APK + matching dependency set.
4. Compatibility matrix:
   - firmware build ↔ `com.leshun.hwdevice.jar`/hwadapter version ↔ supported NFC card types.
