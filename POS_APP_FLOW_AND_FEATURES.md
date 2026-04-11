# AmenPay Cashier POS App Guide

## Purpose
AmenPay Cashier is a POS application for cashier-operated payment collection. It is designed to let a cashier authenticate on a registered device, enroll payment methods to biometric or NFC identity flows, collect payments using multiple identification methods, view transaction history, and print or reprint receipts.

## Core Value of the App
This app is built for fast cashier-side payment collection with multiple customer identification methods:
- QR-based session flows
- Palm vein identification and enrollment
- NFC card identification and enrollment
- Card-linked payment execution through the backend/payment gateway

It is intended for POS usage, not for general consumer self-service.

## Main User Flows

### 1. App Launch
When the app opens:
- the loading screen starts
- device and session state are checked
- if the cashier is already authenticated, the app opens the home screen
- if not authenticated, the app opens the welcome/login flow

### 2. Authentication Flow
The app supports:
- sign in
- sign up
- forgot password via security questions
- reset password
- remember me for login

#### Sign Up
The cashier/user enters:
- full name
- email
- phone number
- password
- confirm password
- answer to security question 1
- answer to security question 2

After successful signup:
- the app navigates to the sign-in screen
- device registration is triggered there
- the user sees the device registration result message

#### Sign In
The user can:
- log in with email and password
- optionally use remember me so credentials are auto-filled next time

#### Forgot Password
The user enters:
- registered email
- answer to security question 1
- answer to security question 2

If verified:
- the app opens the reset password screen
- the user can set a new password

## Home Screen
The home screen acts as the POS dashboard.

It provides:
- live total balance based on transaction data
- quick access to new payment
- quick access to palm enrollment
- quick access to NFC enrollment
- access to transactions
- access to settings

It is intentionally simplified for POS operations and avoids non-essential profile UI.

## Enrollment Flows

### 1. Palm Vein Enrollment
Palm enrollment is session-based.

#### Step 1
- cashier scans the enrollment QR code
- the app claims the enrollment session from the backend

#### Step 2
- the app starts palm enrollment through the local palm matcher/service
- the service captures the palm and returns a stable `palm_id`
- the app submits the enrollment result to the backend session endpoint

#### Step 3
- the app shows enrollment completion information

Palm enrollment is designed so the POS cashier app does not directly own the palm SDK. The local palm service handles palm capture and matching responsibilities.

### 2. NFC Card Enrollment
NFC enrollment is also session-based.

#### Step 1
- cashier scans the enrollment QR code
- the app claims the NFC enrollment session from the backend

#### Step 2
- cashier taps the physical NFC card on the POS
- the app reads NFC card UID information from the hardware
- the app submits the NFC result to the backend

#### Step 3
- the app shows successful enrollment summary

If the NFC card is already linked to another payment method:
- the app shows the conflict message
- the flow returns to step 1

## New Payment Flow
The app supports multiple payment entry methods.

### 1. QR Payment
Typical flow:
- cashier starts a new payment
- customer presents QR/session payload
- backend identifies the linked payment method
- cashier proceeds to payment processing

### 2. Palm Payment
Typical flow:
- cashier starts a new payment
- palm scan is triggered through the local matcher/service
- the local service recognizes the palm and returns a `palm_id`
- the app sends `palm_id` to backend lookup APIs
- backend returns linked payment method(s)
- cashier selects the desired card if multiple are linked
- app moves to payment processing

### 3. NFC Payment
Typical flow:
- cashier starts a new payment
- customer taps NFC card
- app reads `uid_hex` and `uid_dec`
- app sends NFC identify request to backend
- backend returns the linked payment method and customer details
- app moves to payment processing

## Payment Processing Screen
Once a payment method is identified:
- the app displays processing state
- the app sends the payment request to the backend
- the backend initiates the gateway charge
- the app shows success or failure outcome

### If Payment Succeeds
The app shows a payment success screen with:
- transaction status
- transaction summary
- card/payment reference information
- print receipt option
- back to home option

### If Payment Fails
The app shows failure state and a retry action.

Retry behavior:
- retry takes the cashier back to step 1 of the new payment flow
- this avoids resuming from a stale partially processed state

## Receipts and Printing
The app supports receipt preview before printing.

Receipt flow:
- after a successful payment, the cashier can open a receipt preview
- from transaction details, the cashier can reprint a receipt
- a receipt preview screen is shown first
- the cashier can then print from that preview

## Transactions Module
The transactions area lets the cashier review historical payment activity.

Features include:
- transaction list view
- transaction details view
- reprint receipt from transaction details
- time filters:
  - all
  - today
  - this week
  - this month

The UI is tailored for POS revenue collection and avoids expense-focused reporting.

## Settings and Operational Screens
The app includes operational tools under settings:
- device status
- support logs
- language switching

### Device Status
Shows hardware/device-related operational information relevant for POS use.

### Support Logs
Provides a support-oriented operational snapshot useful for diagnostics and troubleshooting.

## Language Support
The app supports:
- English
- Arabic

Operational screens, payment flows, enrollment flows, and auth flows are localized so the POS can be used in bilingual environments.

## Security and Session Behavior
The app includes:
- token-based authenticated sessions
- local logout that clears stored auth tokens
- remember-me credential persistence on the sign-in screen
- security-question-based password recovery flow

## Main Features Summary
The app provides:
- cashier login and signup
- device registration flow
- remember me login support
- forgot/reset password via security questions
- live POS home dashboard
- palm vein enrollment
- NFC card enrollment
- new payment flow using QR, palm, and NFC identification
- transaction history and filtering
- receipt preview and printing
- support logs and device status
- Arabic and English localization

## Benefits of Using This App

### 1. Multiple Payment Identity Methods
The app supports multiple customer identification paths:
- palm vein
- NFC card
- QR

This reduces cashier dependency on a single payment entry method.

### 2. POS-Optimized Workflow
The app is designed for cashier operation:
- focused home screen
- fast access to payment and enrollment actions
- reduced unnecessary consumer-facing UI

### 3. Session-Based Enrollment Design
Palm and NFC enrollment flows are session-driven:
- better mapping to the target payment method
- safer enrollment handling
- clearer backend ownership of enrollment state

### 4. Faster Repeat Payments
Once a payment method is enrolled:
- palm or NFC can identify the linked payment method quickly
- the cashier can move faster at checkout

### 5. Operational Simplicity
The app gives the cashier and support team access to:
- device status
- support logs
- transaction review
- receipt reprint

### 6. Better Localization Support
Arabic and English support makes the POS practical for bilingual operational environments.

## Practical Usage Notes
- Palm flows depend on the local palm service being available and ready.
- NFC flows depend on the POS NFC reader being available.
- QR enrollment/payment steps depend on scanner readiness and valid session data.
- Payment processing depends on backend APIs and gateway availability.

## Recommended Operator Usage Pattern
For daily usage, the cashier typically works in this order:
1. Sign in on the POS
2. Confirm device readiness if needed
3. Start a new payment or perform enrollment
4. Complete payment
5. Print receipt if requested
6. Review transactions when needed

## Conclusion
AmenPay Cashier is a multi-method POS payment app built around cashier-driven payment collection, enrollment workflows, and operational visibility. Its main strength is the combination of palm, NFC, and QR identity/payment flows in a single POS-focused interface.
