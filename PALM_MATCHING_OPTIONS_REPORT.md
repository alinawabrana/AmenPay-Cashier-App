# Palm Matching Service Options

Date: 2026-03-25

This document compares the two realistic palm-matching architectures discussed for the AmenPay POS project:

1. Vendor-provided server SDK as the matching service
2. Android AAR SDKs used through a dedicated Android matching-service app

It also explains what is required for each option to work, including runtime environment, deployment model, risks, and recommended use cases.

---

## 1. Option A: Vendor Server SDK as Matching Service

### 1.1 What it means

In this option, the hardware company provides a true server-compatible matching SDK or matching engine.

Typical forms:
- Java SDK for Linux server
- Native Linux library
- Vendor-hosted matching service
- Dockerized matching service
- Documented server-side matching engine

Laravel or a separate backend service calls this matching engine directly.

### 1.2 How it works

Enrollment flow:
1. POS device captures palm features
2. Backend sends those features to the vendor server matcher
3. Server matcher stores or indexes them
4. Server matcher returns a stable `palm_id`
5. Backend stores `palm_id` against the payment method

Recognition flow:
1. POS device scans palm again
2. Backend sends fresh features to the server matcher
3. Server matcher compares them against enrolled features
4. Server matcher returns matched `palm_id`
5. Backend fetches payment methods using `palm_id`

### 1.3 Environment required

To use this option, one of these environments is needed:
- VPS with root/SSH access
- Dedicated Linux server
- Cloud VM
- Vendor-managed hosted matching service

Typical requirements:
- Linux server runtime
- Java or native runtime depending on SDK
- Persistent storage for feature database
- Secure private network access or TLS-protected public access
- Stable server uptime

### 1.4 Pros

- Best long-term architecture
- Centralized matching across all POS devices
- No dependency on one Android matcher device
- Easier scaling across branches or multiple POS terminals
- Better operational control and monitoring
- Cleaner separation between backend and biometric engine
- Easier failover, backup, and migration if server stack is properly designed
- Stronger production posture for multi-device deployments

### 1.5 Cons

- Not currently available in this project
- Fully dependent on hardware vendor support
- Integration cannot proceed unless vendor provides:
  - server SDK
  - matching API
  - or full comparison algorithm
- May require vendor licensing or additional commercial terms
- May still require performance tuning and infrastructure work

### 1.6 Security profile

This is the strongest security model among the available options if implemented correctly.

Why:
- matching service can run in a controlled server environment
- access can be restricted at network and application layers
- centralized audit logging is easier
- device-to-service trust is easier to manage than Android-device-local trust

Security requirements:
- authentication between backend and matching service
- TLS if traffic crosses untrusted networks
- secure storage for biometric data/templates
- restricted admin access
- logging and audit trail

### 1.7 Reliability profile

This is the strongest reliability model if the vendor server SDK is stable.

Why:
- one central feature DB
- no dependency on a particular Android matcher device
- easier backup and disaster recovery
- better suited to branch-wide or multi-terminal deployments

### 1.8 What is needed from the hardware company

To make this option possible, the hardware company must provide at least one of the following:
- server-side SDK
- hosted matching service
- Linux/Java/native matching library
- documented recognition/search API for server use
- full feature comparison algorithm and thresholds

Without that, this option cannot be implemented properly.

---

## 2. Option B: Android AAR SDKs as Matching Service

### 2.1 What it means

In this option, the LS2 Android SDK is used to create a separate native Android app that acts as a biometric matching service.

This Android service app runs on an Android device and exposes APIs such as:
- `/health`
- `/palm/enroll`
- `/palm/recognize`
- `/palm/delete`

Laravel or another backend service calls that Android app over HTTP.

### 2.2 How it works

Enrollment flow:
1. Android matching-service app uses LS2 to collect palm features
2. It inserts those features into the LS2 local feature library using SDK APIs such as `featureInsert`
3. It stores a stable application-generated `palm_id`
4. Backend stores the same `palm_id` against the payment method

Recognition flow:
1. Android matching-service app scans palm again
2. It uses LS2 APIs such as `discernStart` or `featureSearch`
3. LS2 returns the matched entry from its local feature library
4. Service returns matched `palm_id`
5. Backend uses `palm_id` to find payment methods

### 2.3 Environment required

This option requires:
- A dedicated Android device, or
- One Android POS acting as the matcher node

Runtime requirements:
- Android OS
- Installed LS2 AARs
- Native Kotlin Android app
- Persistent foreground service or always-on service app
- Stable power/network if used as shared matcher

Important note:
- This is not a normal server deployment
- A standard PHP host, shared hosting, or regular VPS cannot directly run Android AAR SDKs

### 2.4 What the current SDK supports

Based on the inspected LS2 documentation and AAR contents, LS2 supports local matching-related operations including:
- `featureInsert`
- `featureDelete`
- `featureSearch`
- `discernStart`
- `discernCease`
- `inquireStart`
- `featureCounts`

This means LS2 can act as a local matching engine.

Important limitation:
- Matching appears to be local to the Android/SDK environment
- It is not a true server SDK

### 2.5 Pros

- Feasible with the assets already available in this project
- Does not require waiting for vendor server SDK
- Can solve the unstable `template_id` issue by using LS2 feature-library matching
- Suitable for pilot and controlled deployment
- Can be built as a separate service app without mixing matching logic into Flutter cashier UI
- Faster path to proof-of-concept or branch-level rollout

### 2.6 Cons

- Requires a dedicated Android runtime/device
- Matching database is local to the Android matcher device unless vendor provides sync/export support
- Harder to scale across multiple POS devices or branches
- Operationally weaker than a real server-side matcher
- If the matcher device is reset, replaced, or damaged, biometric DB may be lost unless migration/backup is supported
- More infrastructure burden than a proper server SDK
- If installed on the same POS device, SDK/device-lifecycle conflicts are possible if not carefully managed

### 2.7 Security profile

This option can be secure enough for controlled deployment, but it is weaker than a proper server-side service.

Security risks:
- Android device becomes part of backend infrastructure
- local LS2 biometric library lives on Android device
- physical device access matters more
- weak deployment can expose matching service over unsafe network paths

Minimum security requirements:
- keep service on private LAN only
- never expose directly to the public internet
- require API key or HMAC header between backend and service app
- restrict inbound caller IPs if possible
- disable debug access on production matcher device
- avoid logging raw biometric features in production
- maintain audit logs for enroll/delete/recognize operations

### 2.8 Reliability profile

This option can be reliable enough for single-device or tightly controlled rollout, but only with discipline.

Required reliability controls:
- all LS2 operations must be serialized
- no concurrent enroll/recognize operations
- health endpoint must be available
- service app should run as foreground service
- matcher device should stay powered and online
- enrollment and recognition should go through the same matcher feature DB

Main reliability risk:
- biometric feature DB locality

If the same enrolled data is not available on the matching device, recognition will fail.

### 2.9 Deployment models

#### Model B1: Dedicated Android matcher device

Best Android-based approach.

How it works:
- one Android device runs the matching service continuously
- backend calls that device over LAN
- one centralized LS2 feature DB exists on that device

Pros:
- cleaner than installing on every POS
- better consistency
- easier branch-level control

Cons:
- requires one always-on Android device

#### Model B2: Matching service installed on same POS device

How it works:
- same POS runs cashier app and matching service app
- enrollment and recognition happen through that POS-local matcher

Pros:
- no extra device needed
- simplest for pilot or demo

Cons:
- cashier terminal becomes matcher infrastructure
- more risk of SDK/device conflicts
- if multiple POS devices exist, matching DB is fragmented per device

#### Model B3: Matching service installed on each POS independently

How it works:
- each POS maintains its own LS2 feature DB
- same customer must be recognized on the same POS where enrolled, unless sync exists

Pros:
- no dedicated matcher device needed

Cons:
- weakest operational model
- not good for multi-device usage
- not ideal for production

---

## 3. Direct Comparison

| Topic | Server SDK Matching Service | Android AAR Matching Service |
|---|---|---|
| Runtime | Linux/server/cloud | Android device only |
| Current availability | Not available yet | Available now with LS2 |
| Scalability | Strong | Moderate to weak |
| Multi-device support | Strong | Weak unless centralized on one matcher device |
| Operational complexity | Moderate | Moderate to high |
| Architecture quality | Best | Workable compromise |
| Security posture | Stronger | Acceptable only with hardening |
| Reliability | Stronger | Good only in controlled deployment |
| Dependency on vendor | High | Medium |
| Dependency on Android device uptime | No | Yes |
| Best use case | Production-scale rollout | Pilot / controlled branch deployment |

---

## 4. What is Needed for Each Option to Work

### 4.1 What is needed for Server SDK option

Needed from vendor:
- server SDK or server-side matching API
- matching/search documentation
- thresholds and scoring guidance
- deployment/runtime requirements

Needed from infrastructure:
- VPS or dedicated server
- persistent storage
- secure network path
- operational monitoring

Needed from backend:
- enrollment API to send palm features to matcher
- recognition API to query matcher
- storage of returned stable `palm_id`

### 4.2 What is needed for Android AAR option

Needed from LS2 SDK:
- feature library APIs such as `featureInsert`, `featureSearch`, `discernStart`
- stable local matching behavior

Needed from infrastructure:
- dedicated Android matcher device or designated POS device
- LAN access from backend to matcher app
- service app running continuously or operationally available when needed

Needed from backend:
- call Android matching service over HTTP
- store stable `palm_id`
- stop relying on `template_id`

Needed from operations:
- plan for matcher device uptime
- plan for LS2 feature DB persistence
- plan for device replacement/migration

---

## 5. Security Requirements Summary

### For either option

These should be treated as minimum:
- do not use unstable scan-generated `template_id` as the final identity key
- use a stable application-controlled `palm_id`
- authenticate all calls to the matching service
- log enroll/delete/recognize events
- avoid storing or logging raw feature blobs unnecessarily
- keep biometric traffic on private trusted paths

### Additional Android matcher requirements

- matcher device must be physically controlled
- service must not be public on the internet
- debug access should be disabled in production
- Android service must be treated as infrastructure, not as a casual user app

---

## 6. Reliability Requirements Summary

### For server SDK option

Reliable if:
- vendor SDK is stable
- server is persistent
- feature database is backed up
- health checks and monitoring exist

### For Android matcher option

Reliable if:
- one dedicated matcher device is used, or deployment is strictly same-device
- SDK calls are serialized
- service is kept alive
- feature DB locality is managed intentionally
- enrollment and recognition hit the same feature library

---

## 7. Recommendation

### Best long-term option

Use a vendor-provided server SDK or server-compatible matching engine if the hardware company can provide it.

Reason:
- cleaner architecture
- stronger multi-device support
- stronger production reliability and security

### Best currently workable option

Use the LS2 Android SDK through a separate Android matching-service app.

Reason:
- matching APIs are available in the LS2 SDK
- can be implemented now
- can eliminate the unstable `template_id` problem by shifting to SDK feature-library matching and stable `palm_id`

### Important engineering conclusion

If server-side SDK support remains unavailable, the Android matching-service app is the best practical workaround, but it should be deployed with full awareness of its operational limits.

---

## 8. Final Conclusion

- If the client wants the strongest production architecture, a vendor server SDK is the correct direction.
- If the client wants a workable implementation with the assets already available, the LS2 Android AAR matching-service app is feasible and can work in a controlled environment.
- The Android AAR solution is a compromise, not the ideal final architecture.
- The unstable palm `template_id` issue should not be solved by continuing template-id lookup. It should be solved by feature-library matching and a stable `palm_id`.

