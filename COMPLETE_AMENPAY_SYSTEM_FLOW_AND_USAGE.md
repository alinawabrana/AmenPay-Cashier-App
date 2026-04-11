# Complete AmenPay System Flow And Usage Guide

## Overview
The AmenPay platform works as a coordinated three-part system:
- `User App`: used by the customer
- `Cashier POS App`: used by the cashier on the POS device
- `Palm Service App`: runs locally on the scanner-attached Android device and manages palm biometric hardware

These three parts work together with the Laravel backend to support account creation, payment method management, biometric/NFC enrollment, assisted payments, transaction history, and receipts.

This document explains the complete system flow step by step, how each app is used, and how the parts interact.

## System Components

### 1. User App
The customer-facing app is used to:
- create an account
- sign in
- add cards
- manage payment methods
- start palm and NFC enrollment sessions
- show QR codes for payments and enrollments
- view notifications and transaction history

### 2. Cashier POS App
The cashier app is used to:
- authenticate the cashier on a registered POS device
- claim enrollment sessions
- scan QR codes
- run NFC enrollment from POS hardware
- call the local palm service for palm capture
- process payments after identifying a user/payment method
- show transaction details and print receipts

### 3. Palm Service App
The palm service app is used to:
- own the LS2 palm SDK and scanner hardware
- capture palm scans
- enroll new palms into the local matcher database
- recognize existing palms during payment flow
- return a stable `palm_id` to the cashier app
- sync local palm data with the backend

### 4. Backend
The backend is responsible for:
- authentication and account management
- payment method records
- session creation and claim validation
- linking `palm_id` and NFC data to payment methods
- transaction storage
- gateway payment initiation
- notifications and status APIs

## End-To-End High-Level Flow

The complete AmenPay system normally operates in this order:
1. Customer creates account in the user app
2. Customer adds one or more cards
3. Customer optionally enrolls NFC and/or palm for a payment method
4. Cashier uses the POS app to claim enrollment and perform physical scans
5. Backend stores the enrollment linkage
6. Later, during payment, cashier starts a new payment in the POS app
7. Customer identifies with QR, NFC, or palm
8. Backend resolves the linked payment method
9. Payment is processed through backend/gateway
10. POS shows success and offers receipt printing
11. Customer and cashier can both review transaction history later

## Detailed Step-By-Step Usage

## Part 1: Customer Account And First Setup

### Step 1: Customer Opens User App
When the customer launches the user app:
- existing authentication is checked
- if already signed in, the app opens the main dashboard
- if not signed in, the app shows sign in / sign up options

### Step 2: Customer Creates Account
During signup, the customer enters:
- full name
- email
- phone number
- password
- confirm password
- answer to security question 1
- answer to security question 2

These security answers are used in forgot-password recovery later.

### Step 3: Customer Signs In
After account creation:
- customer signs in
- if `Remember me` is enabled, credentials can be prefilled next time

### Step 4: Customer Adds First Card
If the user has no registered card yet, the app moves them into card setup.

The customer enters:
- card number
- expiry date
- CVV
- cardholder name

After successful card registration:
- the card becomes available as a payment method
- the user can use it for QR, NFC, or palm-related flows depending on enrollment status

## Part 2: User App Main Usage

### Home Screen
The user app home screen gives the customer:
- quick actions
- recent transactions
- live payment method status preview
- access to notifications and settings/profile

### Payment Methods Area
The customer can open payment methods and view available channels:
- QR Code
- NFC Card
- Palm Vein

Each method shows status such as:
- active
- inactive
- enrolled
- not enrolled

### QR Code Usage In User App
For QR payments, the customer:
1. opens QR code screen
2. selects the relevant card/payment method
3. shows the QR code to the cashier

### Notification And History Usage In User App
The customer can:
- open notifications
- see unread items
- mark items as read
- view recent and full transaction history
- open transaction details

## Part 3: Palm Vein Enrollment Complete Flow

Palm enrollment requires all three major components:
- user app
- cashier POS app
- palm service app

### Step 1: Customer Starts Palm Enrollment In User App
The customer:
1. opens payment methods or palm area in the user app
2. selects a card/payment method for palm enrollment
3. creates a palm enrollment session
4. sees QR/session data on screen

### Step 2: Cashier Opens Palm Enrollment In POS App
The cashier:
1. opens palm enrollment in the cashier app
2. goes to step 1 of the POS enrollment flow
3. scans the QR shown on the customer device

### Step 3: POS App Claims Backend Enrollment Session
The cashier app:
- sends the QR/session payload to backend claim API
- receives claim/session details
- moves to step 2 of palm enrollment

### Step 4: POS App Calls Palm Service App
When step 2 starts:
- the cashier app does not talk directly to the LS2 SDK
- instead it calls the local palm service over localhost
- the palm service initializes the scanner and capture flow

### Step 5: Palm Service Captures And Matches Palm
The palm service app:
1. starts the LS2 capture flow
2. checks the local matcher database
3. if the palm already exists locally, it reuses the existing `palm_id`
4. if the palm is new, it creates a new `palm_id`
5. stores or reuses the biometric entry locally
6. returns the stable `palm_id` to the cashier app

### Step 6: POS App Submits Palm Enrollment Result To Backend
The cashier app submits the enrollment result to backend.

Backend then:
- links the selected payment method with the returned `palm_id`
- marks enrollment completed

### Step 7: Success State
The customer and cashier now have a palm-enabled payment method.

From then on:
- future palm scans do not need re-enrollment
- payment lookup can be done through `palm_id`

## Part 4: NFC Enrollment Complete Flow

### Step 1: Customer Starts NFC Enrollment In User App
The customer:
1. selects a payment method for NFC enrollment
2. creates an NFC enrollment session
3. sees QR/session data in the user app

### Step 2: Cashier Opens NFC Enrollment In POS App
The cashier:
1. opens NFC enrollment flow in the cashier app
2. scans the enrollment QR from the user app

### Step 3: POS App Claims NFC Session
The cashier app claims the NFC session from backend.

Backend returns the session context needed to continue.

### Step 4: Cashier Taps NFC Card On POS
At step 2 of NFC enrollment:
- cashier/customer taps the physical NFC card on the POS device
- POS hardware reads the card UID values such as:
  - `uid_hex`
  - `uid_dec`

### Step 5: POS App Submits NFC Scan Result
The cashier app sends the NFC scan result to backend.

Backend then:
- checks for conflicts
- prevents reuse if the same NFC card is already linked elsewhere
- links the NFC data to the selected payment method if valid

### Step 6: Success State
The NFC-enabled payment method is now ready for later payment identification.

## Part 5: QR Payment Flow

QR payment is the simplest identification path.

### Step 1: Customer Opens QR In User App
The customer:
1. opens QR payment section
2. selects the relevant card
3. presents the QR to the cashier

### Step 2: Cashier Starts New Payment In POS App
The cashier:
1. opens `New Payment`
2. chooses QR-based flow
3. scans the QR payload

### Step 3: Backend Resolves Payment Method
The POS app sends the QR/session data to backend.

Backend returns:
- linked payment method
- customer/payment data needed to continue

### Step 4: Payment Processing
The POS app opens payment processing screen.

Backend:
- creates transaction
- initiates payment through the payment gateway
- updates transaction status

### Step 5: Success Or Failure
If successful:
- POS shows payment success screen
- receipt preview/printing is available

If failed:
- POS shows failure state
- retry returns the cashier to step 1 of new payment

## Part 6: Palm Payment Flow

Palm payment combines the POS app and palm service app.

### Step 1: Cashier Starts New Payment
The cashier:
1. opens `New Payment`
2. chooses palm payment flow

### Step 2: POS Calls Local Palm Service
The cashier app calls the localhost palm recognition endpoint.

### Step 3: Palm Service Recognizes Customer
The palm service:
1. initializes scanner capture
2. captures the palm
3. matches it against the local LS2 database
4. returns a stable `palm_id` if matched

### Step 4: POS App Sends `palm_id` To Backend
The cashier app sends the returned `palm_id` to backend.

Backend responds with:
- linked payment method(s)
- customer context

If multiple payment methods are linked:
- cashier selects one from the POS screen

### Step 5: Payment Processing
The POS app sends the chosen payment method and amount to backend.

Backend:
- creates transaction
- sends gateway payment request
- returns success or failure outcome

### Step 6: Completion
If successful:
- POS shows success screen
- cashier can print receipt
- cashier can return to home screen

## Part 7: NFC Payment Flow

### Step 1: Cashier Starts New Payment
The cashier:
1. opens `New Payment`
2. chooses NFC payment flow

### Step 2: Customer Taps NFC Card
The NFC card is scanned on the POS device.

The POS app reads:
- `uid_hex`
- `uid_dec`

### Step 3: POS Identifies The Payment Method
The POS app sends NFC identify request to backend.

Backend finds the payment method linked to the scanned NFC data and returns:
- `payment_method_id`
- customer details
- card summary
- NFC status

### Step 4: Payment Processing
The POS app proceeds to the shared payment processing flow.

Backend processes the payment through the same payment backend/gateway pattern used for other methods.

### Step 5: Completion
If successful:
- POS shows success
- receipt preview and printing are available

## Part 8: Payment Processing And Receipts

### Shared Processing Behavior
Once a valid payment method has been identified through QR, palm, or NFC:
- POS opens payment processing screen
- backend validates the payment method and customer
- backend creates a transaction record
- backend initiates the payment gateway request
- POS shows success or failure response

### Payment Success Screen
On successful payment, POS shows:
- transaction summary
- status
- card/payment references
- print receipt action
- back to home action

### Receipt Printing Flow
Receipt handling works like this:
1. cashier taps print receipt on success screen, or reprint receipt from transaction details
2. receipt preview screen opens
3. cashier reviews the receipt
4. cashier taps print

## Part 9: Transaction Visibility Across The System

### In User App
Customer can:
- see recent transactions on home screen
- open full history
- review transaction details

### In POS App
Cashier can:
- see transaction list
- filter by:
  - all
  - today
  - this week
  - this month
- open transaction details
- reprint receipts

## Part 10: Settings, Support, And Operations

### In POS App
The settings area provides:
- device status
- support logs
- language switching
- logout

These are operational tools for cashier/support usage.

### In User App
The settings/profile area provides:
- profile access
- profile editing
- payment methods
- notifications
- terms/privacy/about
- logout

## Part 11: Security And Recovery

### Authentication
Both apps use authenticated sessions backed by tokens.

### Forgot Password
The forgot password flow works with:
- registered email
- security answer 1
- security answer 2

If verified:
- reset token is issued
- reset password screen is opened
- user sets a new password

### Remember Me
Where enabled:
- saved credentials are prefilled for easier next login

## Part 12: Palm Service Operational Flow

The palm service app has its own internal lifecycle.

### Startup Flow
When the palm service app starts:
1. it initializes the LS2 SDK layer
2. it syncs active palm enrollment data from backend
3. it rebuilds the local matcher database
4. it exposes localhost HTTP endpoints to the cashier app

### Readiness Check
Before POS uses palm features, the cashier app should confirm the service is ready through:
- `GET /health`

Important readiness values:
- `sdk_ready`
- `sync_ready`

### Capture Lifecycle
For each palm capture operation, the service is expected to:
1. initialize scanner engine
2. start preview and collect flow
3. capture palm data
4. stop capture flow
5. stop preview
6. clear engine and return scanner to idle

This isolates hardware ownership inside the service app.

## Main Features Provided By The Full System

The combined AmenPay system provides:
- secure signup and login
- remember me support
- forgot/reset password using security questions
- first-card setup and card management
- QR payment flows
- palm enrollment and payment flows
- NFC enrollment and payment flows
- multilingual interface in English and Arabic
- live transaction review
- notifications and analytics in the user app
- receipt preview and printing in the POS app
- device diagnostics and support logs in the POS app
- local on-device palm biometric matching through the palm service app

## Pros Of Using The Full AmenPay System

### 1. Three-Channel Payment Identity Support
The system supports three practical assisted-payment identity methods:
- QR
- NFC
- Palm Vein

This gives operational flexibility at checkout.

### 2. Better Separation Of Responsibility
Each system part has a clear role:
- user app manages customer-side actions
- cashier app manages POS actions
- palm service app manages scanner hardware and biometric processing
- backend manages business logic and payment processing

This is a cleaner and safer architecture than combining everything into one app.

### 3. Faster Repeat Checkout
Once a user has enrolled palm or NFC:
- identification becomes faster
- checkout becomes more consistent
- cashier work is reduced during repeat visits

### 4. Session-Based Enrollment Control
Palm and NFC enrollment are session-driven, which improves:
- correctness of payment method mapping
- backend ownership of enrollment state
- cashier-side enrollment safety

### 5. Improved Device Management
The POS app provides operational tooling such as:
- device status
- support logs
- transaction review
- receipt printing

### 6. Palm Matching Performance
The palm service performs matching locally on-device, which improves:
- biometric response time
- resilience against scanner/backend coupling issues
- stable `palm_id` reuse

### 7. Customer Visibility
The user app gives customers visibility into:
- payment method status
- enrollment readiness
- notifications
- transaction history
- analytics

## Recommended Real-World Usage Pattern

### For A New Customer
1. Create account in user app
2. Add first card
3. Open payment methods
4. Enroll palm and/or NFC as needed
5. Use QR, palm, or NFC for later assisted payments

### For A Cashier During Checkout
1. Sign in to POS app
2. Start new payment
3. Use QR, palm, or NFC based on customer choice
4. Confirm returned payment method
5. Process payment
6. Print receipt if needed

### For Enrollment At POS
1. Customer starts enrollment from user app
2. Cashier opens matching enrollment flow in POS app
3. Cashier scans enrollment QR
4. POS claims session
5. Physical palm or NFC capture happens on POS side
6. Backend finalizes enrollment link

## Conclusion
AmenPay is not just one app. It is a coordinated payment platform made of the user app, cashier POS app, palm service app, and backend. The full system is designed to support assisted checkout with QR, NFC, and palm identity methods, while keeping customer actions, cashier operations, and biometric hardware responsibilities properly separated.
