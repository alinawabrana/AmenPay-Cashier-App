# Palm Matching Service Integration (Laravel + POS)

This document describes how to integrate a server-side palm matching service with a PHP/Laravel backend, and what to change on the Flutter POS app when using backend matching (Option 2).

The backend matching service must run the Leshun LS2 SDK. Laravel will call it over HTTP. The POS device will send raw palm templates (Base64) to Laravel. Laravel forwards them to the matching service and returns matched user/payment methods.

## 1) Architecture Overview

1. POS device scans palm and generates raw template features (RGB/NIR).
2. POS sends raw template (Base64) to Laravel.
3. Laravel calls the Matching Service (Java/Kotlin) with the raw template.
4. Matching Service uses LS2 SDK to match and returns a stable `palm_id` / `user_id`.
5. Laravel uses `palm_id` to fetch payment methods and returns them to the POS.

## 2) Matching Service (Java/Kotlin) Setup

### 2.1 Dependencies

1. BaseLine-1.00.aar
2. ShunPalm-LS2-2.10.aar (or your vendor version)
3. Any native `.so` libs and model files required by LS2

### 2.2 Service Endpoints

Implement a simple HTTP service with two endpoints:

1. `POST /palm/enroll`
2. `POST /palm/recognize`

### 2.3 Request/Response Contracts

Enrollment request:
```
{
  "user_id": "string",
  "feature_rgb": "base64",
  "feature_nir": "base64",
  "palm_type": 0,
  "score": 0.0
}
```

Enrollment response:
```
{
  "success": true,
  "palm_id": "uuid-string"
}
```

Recognition request:
```
{
  "feature_rgb": "base64",
  "feature_nir": "base64",
  "similar_rgb": 0.75,
  "similar_nir": 0.75
}
```

Recognition response (match found):
```
{
  "success": true,
  "palm_id": "uuid-string",
  "user_id": "string",
  "similar_rgb": 0.83,
  "similar_nir": 0.81
}
```

Recognition response (no match):
```
{
  "success": false,
  "error": "NO_MATCH"
}
```

### 2.4 Matching Service Logic (high level)

1. Initialize SDK once:
   - `ShunPalm.init(new ShunPalmWorker(getApplicationContext()));`
2. Enrollment:
   - Convert Base64 -> byte[]
   - Build `FeatureData(user_id, palm_id, voucher, rgb, nir, palm_type, score)`
   - Call `ShunPalm.featureInsert(featureData)`
3. Recognition:
   - Set params:
     - `similar_rgb = 0.75`
     - `similar_nir = 0.75`
     - `inquire_thread_size = 4`
     - `inquire_search_size = 2000`
   - Call `ShunPalm.discernStart(params, callback)`
   - Use returned `InquireData` to get matched `palm_id` / `user_id`.

Note: The LS2 SDK uses its own internal feature database for matching. The matching service must keep this database populated (either in memory or persistent per vendor SDK design).

## 3) Laravel Integration

### 3.1 Add a Matching Service client

Add a simple HTTP client in Laravel (Guzzle or Laravel HTTP client):

1. `POST /palm/enroll` to matching service
2. `POST /palm/recognize` to matching service

### 3.2 Backend Endpoints (Laravel)

Create or update these endpoints:

1. `POST /api/palm/enroll`
   - Validate input
   - Forward to matching service enroll
   - Store returned `palm_id` with the user

2. `POST /api/palm/recognize`
   - Forward to matching service recognize
   - If match found, return `palm_id`
   - Use `palm_id` to fetch payment methods

### 3.3 Data Model

Store at minimum:

1. `user_id`
2. `palm_id`
3. `device_id`
4. `created_at`

If you also persist feature bytes:

1. `feature_rgb` (Base64)
2. `feature_nir` (Base64)
3. `palm_type`
4. `score`

## 4) Flutter POS Changes (Option 2)

### 4.1 Enrollment Flow

1. On palm enrollment success, send the **raw template** (Base64) to Laravel:
   - `feature_rgb`, `feature_nir`, `palm_type`, `score`
2. Laravel calls matching service and returns a `palm_id`.
3. Store `palm_id` on backend for the user.

### 4.2 Payment Flow

1. After palm scan, send **raw template** to Laravel:
   - `feature_rgb`, `feature_nir`, `palm_type`, `score`
2. Laravel calls matching service and returns `palm_id`.
3. Call:
   - `POST /api/palm/payment-methods-by-template`
   - with `palm_template_id = palm_id`
4. Show payment methods to user.

### 4.3 Do NOT compare raw templates on client

Raw template strings change on every scan. Always rely on backend matching.

## 5) Suggested API Paths (Laravel)

1. `POST /api/palm/enroll`  
2. `POST /api/palm/recognize`  
3. `POST /api/palm/payment-methods-by-template`

## 6) Required Changes in Current Flutter Code

1. Switch palm scan response to include feature bytes and palm type.
2. Send these fields to the backend endpoints.
3. Do not use raw template id for matching in Flutter.

## 7) Notes

1. The LS2 SDK threshold defaults from the docs are:
   - `similar_rgb = 0.75`
   - `similar_nir = 0.75`
2. If recognition fails, increase thresholds or adjust `inquire_search_size`.
3. If matching service restarts, it must reload all enrolled features into the LS2 DB.
