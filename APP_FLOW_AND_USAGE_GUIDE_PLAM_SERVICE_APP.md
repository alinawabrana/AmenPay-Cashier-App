# AmenPay Palm Service Guide

Date: 2026-04-03

## Overview

AmenPay Palm Service is a dedicated Android app that turns the LS2 palm scanner into a local biometric matching service for the POS environment.

This app is designed to run on the Android device that has the palm scanner attached.

Its job is to:

- initialize the LS2 palm SDK
- capture palm scans
- enroll new palms into the local LS2 feature database
- recognize already enrolled palms
- return a stable `palm_id` to the cashier app
- sync enrolled palm data to the remote Laravel backend
- rebuild the local matcher database from backend on startup

This app is not the payment backend and it is not the cashier UI.

## Core Role In The System

The full system has three parts:

1. Cashier app
- runs on the POS device
- calls this palm service over localhost
- manages session claim, customer flow, and payment UI

2. Palm service app
- talks to the LS2 palm scanner
- performs biometric enrollment and recognition
- returns stable `palm_id`

3. Laravel backend
- stores business data
- maps `palm_id` to payment methods
- stores canonical enrollment records for sync
- processes payments

## Why This App Exists

The raw palm scan output is not stable enough to be used as the long-term backend identity.

So instead of relying on unstable scan output, this app:

- stores palm features in the LS2 local database
- performs local biometric matching
- returns a stable application-controlled `palm_id`

That stable `palm_id` is what the backend uses to find the user’s saved payment methods.

## Main Features

- Local palm enrollment
- Local palm recognition
- Duplicate palm detection during enrollment
- Stable `palm_id` generation and reuse
- Startup sync from backend
- Local HTTP API for cashier app integration
- API key protection via `X-Palm-Service-Key`
- Health endpoint for readiness checks
- Feature-count visibility
- Automatic scanner teardown after capture flow completes

## Local HTTP Endpoints

The app exposes a local HTTP server on port `8080`.

Common endpoints:

- `GET /health`
- `GET /feature-count`
- `POST /palm/capture-enroll`
- `POST /palm/capture-recognize`
- `POST /palm/delete`

Legacy feature-based routes also exist for compatibility:

- `POST /palm/enroll`
- `POST /palm/recognize`

Every request must include:

```http
X-Palm-Service-Key: <your local palm service key>
```

## How Enrollment Works

### Enrollment Flow

1. Cashier app creates and claims an enrollment session from backend.
2. Cashier app calls the local palm service:

```http
POST /palm/capture-enroll
```

3. Palm service initializes scanner flow.
4. Palm service captures palm features from the LS2 scanner.
5. Palm service checks local LS2 database for an existing biometric match.
6. If an existing palm is found:
- it reuses the existing `palm_id`
- returns `matched_existing = true`

7. If no valid match is found:
- it creates a new `palm_id`
- stores the new palm in local LS2 DB
- syncs the new enrollment to backend
- returns `matched_existing = false`

8. Cashier app sends the returned `palm_id` to backend submit-result endpoint.
9. Backend links the selected payment method to that `palm_id`.

### Enrollment Result

The app returns:

- `palm_id`
- `matched_existing`
- `voucher`
- `palm_type`
- `score`
- optional similarity scores when an existing palm was reused

## How Recognition Works For Payment

### Recognition Flow

1. Cashier app asks the user to place a palm on the scanner.
2. Cashier app calls:

```http
POST /palm/capture-recognize
```

3. Palm service captures a new scan.
4. Palm service matches the scan against the local LS2 feature database.
5. If a match is found, the app returns the stable `palm_id`.
6. Cashier app sends that `palm_id` to backend.
7. Backend returns the payment methods linked to that `palm_id`.
8. Cashier selects the desired method and payment is processed by backend.

### Recognition Result

The app returns:

- `matched`
- `palm_id`
- `voucher`
- `similar_rgb`
- `similar_nir`
- `mode`

## Startup Sync Behavior

When the palm service starts:

1. it initializes the LS2 layer
2. it calls backend sync API
3. it downloads active enrolled palms
4. it rebuilds the local LS2 feature database

This allows a new device to recognize previously enrolled users without re-enrolling everyone.

If startup sync is enabled, the cashier app should check:

- `sdk_ready`
- `sync_ready`

through the `/health` endpoint before attempting palm actions.

## Scanner Lifecycle

The scanner is activated only during actual palm capture operations.

For each capture flow, the service does:

1. `engineBuild(...)`
2. `previewStart(...)`
3. `collectStart(...)`
4. collect palm data
5. `collectCease(...)`
6. `discernCease(...)` or `inquireCease(...)` when relevant
7. `previewCease(...)`
8. `engineClear(...)`

This is intended to return the scanner to an idle state after each scan.

## What The User Gets From This App

For the cashier or POS operator, this app provides:

- reliable palm enrollment
- reliable palm-based customer recognition
- faster palm payments
- reuse of the same palm across multiple payment methods
- backend-independent local biometric matching
- easier device replacement through backend sync

For the end customer, this means:

- less repeated enrollment
- faster checkout
- no need to remember card details during palm payment
- more seamless matching across synced devices

## Pros Of Using This App

- Stable palm identity:
  The app uses a stable `palm_id` instead of unstable scan-only identifiers.

- Local recognition:
  Matching is done on-device, so payment lookup is faster and does not depend on backend reaching the scanner.

- Better user experience:
  A returning customer can be recognized with a palm scan and quickly linked to saved payment methods.

- Duplicate prevention:
  During enrollment, the app checks for an existing local match before creating a new identity.

- Device replacement support:
  Startup sync allows a new palm service device to rebuild the matcher database from backend.

- Safer architecture:
  The palm hardware and SDK are owned by the service app, reducing conflicts with the cashier app.

- Cleaner separation of responsibility:
  The cashier app handles UI and payment flow, the palm service handles biometrics, and Laravel handles business logic.

## How To Use The App

### Basic Setup

1. Install the app on the Android device connected to the LS2 scanner.
2. Configure:
- palm service API key
- backend sync base URL
- backend sync key
- optional sync device id

3. Start the app.
4. Confirm the service screen shows:
- service port
- API key configured
- live health
- sync readiness

### Before Using With Cashier App

Check the local health endpoint:

```http
GET /health
```

Make sure:

- `sdk_ready = true`
- `sync_ready = true`

### For Enrollment

1. Customer selects payment method in cashier flow.
2. Cashier claims session.
3. Cashier app calls `/palm/capture-enroll`.
4. User places palm on scanner.
5. Palm service returns `palm_id`.
6. Cashier app submits `palm_id` to backend.

### For Payment

1. Cashier app calls `/palm/capture-recognize`.
2. User places palm on scanner.
3. Palm service returns matched `palm_id`.
4. Cashier app fetches payment methods from backend.
5. Cashier completes payment.

## Important Operational Notes

- The palm service should be the only app that owns the LS2 palm SDK and hardware.
- The cashier app should call the local service and should not directly control the scanner.
- New enrollments should be synced to backend so startup sync continues to work on new devices.
- If health shows sync is not ready, palm operations should be blocked until the service is ready.

## Recommended Usage Summary

Use this app when you need:

- palm enrollment
- palm-based payment recognition
- stable `palm_id` identity
- multiple payment methods linked to one palm
- local biometric matching on Android
- backend-assisted sync across matcher devices

## Final Summary

AmenPay Palm Service is the biometric layer of the palm-payment system.

It makes palm scanning practical in production by:

- owning the LS2 scanner lifecycle
- providing local HTTP APIs to the cashier app
- generating and reusing stable palm identities
- keeping the matcher database synchronized with backend

This gives a more reliable enrollment flow, more reliable payment recognition, and a cleaner separation between biometric operations and payment/business logic.
