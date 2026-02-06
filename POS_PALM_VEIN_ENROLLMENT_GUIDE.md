# POS PALM VEIN ENROLLMENT GUIDE (For POS/Backend Developer)

**Audience:** The developer building the POS application and integrating the palm vein hardware SDK.

**Scope:** Palm vein enrollment only.
- POS scans session QR
- POS claims session with Laravel
- POS runs palm SDK enrollment
- POS receives `template_id`
- POS submits `template_id` to Laravel

**Out of scope:** Payments, charging, payment gateway, palm verification for transactions.

---

## 1. What the POS developer must know

Yes — the POS developer must understand **enough hardware-linking knowledge** to:
- Read QR codes from the scanner/camera
- Invoke the palm vein device SDK (enrollment)
- Receive `template_id` from SDK
- Call Laravel endpoints with correct auth, device binding, and error handling

They do **not** need to know biometric algorithms (feature extraction/matching) because the SDK already returns a `template_id`.

---

## 2. System responsibilities (quick map)

### 2.1 Customer App (Flutter)
- Creates enrollment session and shows QR
- Polls session status to display completion

### 2.2 POS App
- Scans enrollment QR
- Claims session (locks to POS `device_id`)
- Runs palm SDK enrollment
- Submits result to backend

### 2.3 Laravel Backend
- Validates QR signature + expiry
- Manages session state
- Enforces enrollment rules:
  - One template per user
  - Reset required for re-enroll
  - No overwrite/no silent replacement
  - `(device_id, template_id)` unique and never reused across users

---

## 3. POS prerequisites

### 3.1 A stable POS `device_id`
The POS app must have a stable identifier like:
- `POS-001`
- terminal serial number
- Android ID (only if reliable for your devices)

**Rule:** The same POS device must use the same `device_id` consistently.

### 3.2 POS authentication
The POS must authenticate separately from customers.
Recommended options:
- Device API key per POS (recommended)
- Merchant login + device registration (more complex)

The POS will call protected endpoints such as:
- `POST /api/palm/enroll/sessions/claim`
- `POST /api/palm/enroll/sessions/{session_id}/submit-result`

---

## 4. Enrollment flow (POS)

### 4.1 High-level steps
1. Scan enrollment QR shown on customer phone
2. Call backend to claim session
3. Start palm enrollment via SDK
4. SDK returns `template_id`
5. Submit `template_id` to backend
6. Show success/failure on POS

---

## 5. QR session details

### 5.1 QR format
The QR content is a **session QR**, not the persistent customer QR.

Recommended format:
`PALMENROLL:{sessionId}:{expUnix}:{nonce}:{sig}`

Where `sig = HMAC_SHA256(sessionId|expUnix|nonce, SERVER_SECRET)`.

### 5.2 POS responsibility
POS does not need to compute HMAC.
POS should send `qr_data` exactly as scanned to the backend claim endpoint.

---

## 6. Backend endpoints the POS must call

### 6.1 Claim session
**POST** `/api/palm/enroll/sessions/claim`

**Auth:** POS

**Request**
```json
{
  "qr_data": "PALMENROLL:...:SIG",
  "device_id": "POS-001"
}
```

**Success response**
```json
{
  "session_id": "b1b3d7b0-2c14-4a6a-9d2a-5b6f3b7f4c1d",
  "status": "claimed",
  "expires_at": "2026-01-22T11:33:00Z"
}
```

**Important:** After claim succeeds, the session is locked to `device_id`. The POS must keep using the same `device_id` during submit-result.

Common error codes:
- `INVALID_QR`
- `SIGNATURE_INVALID`
- `SESSION_EXPIRED`
- `SESSION_ALREADY_CLAIMED`
- `SESSION_ALREADY_ENROLLED`

---

### 6.2 Submit enrollment result
**POST** `/api/palm/enroll/sessions/{session_id}/submit-result`

**Auth:** POS

#### Success request
```json
{
  "device_id": "POS-001",
  "result": "success",
  "template_id": "LSP980-TPL-0000123456",
  "quality_score": 87,
  "liveness": "pass"
}
```

#### Success response
```json
{
  "status": "enrolled",
  "user_id": "USER-UUID",
  "device_id": "POS-001",
  "template_id": "LSP980-TPL-0000123456",
  "enrolled_at": "2026-01-22T11:32:10Z"
}
```

#### Failure request
```json
{
  "device_id": "POS-001",
  "result": "failed",
  "error_code": "LOW_QUALITY",
  "error_message": "Palm capture quality too low"
}
```

Common error codes:
- `SESSION_DEVICE_MISMATCH`
- `SESSION_EXPIRED`
- `ALREADY_ENROLLED` (user needs reset)
- `TEMPLATE_ALREADY_LINKED` (template already used by another user)

---

## 7. Hardware integration (what to implement)

### 7.1 Palm vein SDK integration
The POS developer needs vendor SDK documentation. The typical integration shape:

- `startEnrollment()`
- SDK returns callback/result containing:
  - `template_id`
  - `quality_score` (optional)
  - `liveness` (optional)
  - `error_code` / `error_message` (on failure)

**Critical constraint from system docs:** Do not persist palm images. Only pass/store `template_id` and non-sensitive metadata.

### 7.2 QR scanner integration
Two common approaches:

#### Option A: Serial port scanner (common for POS hardware)
- Android reads from serial device (example from project docs):
  - Port: `/dev/ttyHSL3`
  - Baud rate: `9600`
- The scanner produces text strings (the QR payload)

POS responsibilities:
- Open serial connection
- Listen for scanned string
- Debounce duplicates
- Immediately call `/claim`

#### Option B: Camera scanning
- Use camera QR scanning if no serial scanner exists

---

## 8. Flutter POS app architecture (recommended)

### 8.1 Split into layers
- **Hardware layer** (native Android): serial + palm SDK
- **Dart layer**: state machine + API calls + UI

### 8.2 Platform channels
Expose native functionality to Flutter using MethodChannels.
Suggested channel methods:
- `scanQrOnce()` → returns `String qrData`
- `startPalmEnrollment()` → returns `{ template_id, quality_score, liveness }`

POS Dart flow:
1. `qrData = scanQrOnce()`
2. `claim(qrData, deviceId)`
3. `result = startPalmEnrollment()`
4. `submitResult(sessionId, deviceId, templateId, ...)`

---

## 9. POS UI requirements (minimum)

The POS does NOT need full cashier screens to ship enrollment.
Minimum screens:
- “Ready to scan enrollment QR”
- “Claimed, place palm to enroll”
- “Enrolling…”
- “Success / Failed”

---

## 10. Error handling and POS messaging

### 10.1 Suggested UI mapping
- `INVALID_QR` / `SIGNATURE_INVALID`
  - Show: “Invalid enrollment QR. Ask customer to refresh QR.”
- `SESSION_EXPIRED`
  - Show: “Session expired. Ask customer to regenerate QR.”
- `SESSION_ALREADY_CLAIMED`
  - Show: “Session already used. Ask customer to regenerate QR.”
- `ALREADY_ENROLLED`
  - Show: “Customer already enrolled. Reset required.”
- `TEMPLATE_ALREADY_LINKED`
  - Show: “Palm template already linked. Contact support.”
- `LOW_QUALITY`
  - Show: “Low quality scan. Try again.”

### 10.2 Retry behavior
- For QR/session errors: re-scan a fresh QR
- For hardware errors: allow re-try enrollment locally, but don’t submit success without a new `template_id`

---

## 11. Security checklist (POS)

- Use HTTPS
- Use POS-specific auth credentials
- Never log full QR payloads in production
- Never log `template_id` in plaintext logs if logs are shared; treat as sensitive identifier
- Ensure `device_id` is stable and not user-editable

---

## 12. Text sequence diagram (POS-centric)

```text
Customer App                   POS App                          Laravel
    | shows enrollment QR         |                                |
    |---------------------------->| scan QR                        |
    |                             | POST /claim(qr_data, device_id)|
    |                             |------------------------------->|
    |                             |         200 claimed(session_id)|
    |                             |<-------------------------------|
    |                             | start palm SDK enrollment       |
    |                             | (SDK returns template_id)       |
    |                             | POST /submit-result(template_id)|
    |                             |------------------------------->|
    |                             |            200 enrolled         |
    |                             |<-------------------------------|
    |                             | show success                    |
```

---

## 13. Integration testing plan

### 13.1 Backend ready checklist
- `/claim` works for valid QR
- `/submit-result` stores mapping and marks session `enrolled`
- Unique constraints are enforced:
  - one identity per user
  - `(device_id, template_id)` unique

### 13.2 POS ready checklist
- QR scan reading stable (serial or camera)
- Claim call uses correct `device_id`
- Palm SDK returns `template_id`
- Submit-result success path works

### 13.3 End-to-end scenario
- Customer generates QR
- POS claims
- POS enrolls and submits
- Customer sees `enrolled` status

---

## 14. Appendix: Required constants

- `device_id`: Stable string per terminal
- Serial scanner (if used): `/dev/ttyHSL3`, baud `9600` (verify on target hardware)

---
**End of document**
