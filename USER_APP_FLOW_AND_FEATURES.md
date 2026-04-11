# AmenPay User App Flow And Features

## Overview
AmenPay is a customer-facing payment application built to let users manage their payment methods and complete assisted payments through a secure digital experience.

The AmenPay platform includes two apps:
- `User App`: the current app, used by customers
- `Cashier App`: used by the cashier or merchant side for enrollments, scanning, and payment processing

This app is focused on giving the user a simple and secure way to:
- register payment cards
- manage payment methods
- enroll biometric and NFC-based payment options
- generate and show QR codes
- track payment history
- manage profile and account information

## Main User Flow

### 1. Launch And Authentication
When the user opens the app, the app checks whether the user is already authenticated.

If not authenticated, the user can:
- sign in
- create a new account
- use forgot password with security questions

If the user selects `Remember me`, the sign-in screen will preload the saved email and password next time.

### 2. Account Creation
During signup, the user provides:
- full name
- email
- phone number
- password
- two security answers

The security answers are used later in the forgot-password flow.

### 3. First-Time Card Setup
After successful login, if the account has no registered card, the app forces the user into the add-card flow.

In this step, the user:
- enters card number
- enters expiry date
- enters CVV
- enters cardholder name

The app validates the card and submits it to the backend. Once the card is added successfully, the user is taken into the main app.

### 4. Home Screen
The home screen acts as the main dashboard.

It provides:
- welcome section with user name
- quick actions
- live payment method status preview
- recent transactions
- app bar access to notifications and profile/settings

Quick actions open key payment experiences directly:
- Palm Vein
- QR Code
- History

### 5. Payment Method Management
The Payment Methods area is where the user can see and manage the available payment channels.

Supported methods:
- QR Code
- NFC Card
- Palm Vein

Each method displays live status from backend data, such as:
- active
- inactive
- enrolled
- not enrolled

### 6. QR Code Flow
The QR Code screen shows QR codes for the user’s registered payment methods.

The user can:
- see all available cards
- tap a specific card
- open the QR code tied to that exact card

This lets the cashier scan the correct QR code for payment.

### 7. NFC Enrollment Flow
The NFC flow allows a user to enroll a physical NFC card for payment.

Typical flow:
1. user selects a payment method
2. app creates an NFC enrollment session
3. app shows QR/session data for the POS
4. cashier POS claims the session
5. POS scans the NFC card
6. app polls session state until it is completed, failed, or expired

The user can also see whether NFC is:
- not enrolled
- active
- inactive

### 8. Palm Vein Enrollment Flow
The Palm Vein flow lets the user enroll biometric palm-based payment for a specific payment method.

Typical flow:
1. user selects a card that is not yet enrolled
2. app creates an enrollment session
3. app shows a QR code for the scanner
4. cashier device scans the QR code
5. user places palm on the scanner
6. app polls backend status
7. success screen is shown after enrollment completes

The Palm Vein screen also shows which cards are already enrolled.

### 9. Notifications
The app includes a notifications screen backed by API data.

The user can:
- see all notifications
- view unread count
- mark notifications as read

Unread notifications are highlighted with:
- a red dot on the notifications tile in settings
- a red dot on the notification icon in the home app bar

### 10. Transaction History
The app fetches customer transactions from backend APIs and displays:
- recent transactions on the home screen
- full transaction history in a separate history screen
- transaction details on tap

This helps the user monitor:
- completed payments
- initiated payments
- failed transactions

### 11. Analytics
The analytics tab gives the user a visual summary of payment activity and method readiness.

It includes:
- activity charts
- status mix charts
- method readiness metrics
- processed amount
- success rate

This helps the user understand usage trends and payment activity over time.

### 12. Settings And Profile
The settings/profile area allows the user to:
- view profile information
- edit profile
- open payment methods
- open notifications
- view terms and privacy
- read about the app
- log out

## Core Features Provided To The User

### Secure Authentication
- sign in
- sign up
- remember me
- forgot password with security questions

### Card Management
- add payment cards
- see registered payment methods
- card-specific QR assignment

### Multi-Method Payment Support
- QR code based payment support
- NFC card enrollment and status handling
- Palm Vein enrollment and status handling

### Live Backend Synchronization
- payment method statuses are fetched from backend
- unread notification count is live
- enrollment status updates after successful scan
- transactions update from backend APIs

### Notifications
- list notifications from backend
- unread count
- mark as read

### Transaction Visibility
- recent transactions on home screen
- full history screen
- detailed transaction view

### Analytics
- charts and graphs for activity
- payment success insights
- payment method readiness indicators

### Localization
- English and Arabic support
- translated user interface across major screens

## How A User Should Use The App

### For A New User
1. Create an account
2. Answer the two security questions
3. Sign in
4. Add the first payment card
5. Open Payment Methods
6. Enroll Palm Vein or NFC if needed
7. Use QR code or enrolled methods for assisted payments

### For A Returning User
1. Open the app
2. Sign in, or use the prefilled credentials if `Remember me` was enabled
3. Check the home screen for quick actions and latest transactions
4. Open the required payment method
5. Use QR, NFC, or Palm flow as needed

### For Monitoring Activity
1. Open Home for recent transactions
2. Open History to view full transactions
3. Open Analytics to review usage trends
4. Open Notifications to see alerts and updates

## Pros Of Using This App

### 1. Multiple Payment Methods In One App
The user does not depend on a single payment channel. The app supports QR, NFC, and Palm Vein flows in one place.

### 2. Better Security
The app supports secure authentication, card tokenization, protected account handling, and guided enrollment flows.

### 3. Assisted Enrollment And Payment Experience
The user app works together with the cashier app, which reduces complexity on the customer side while still allowing advanced payment methods.

### 4. Clear Status Visibility
The user can immediately see whether a method is:
- available
- active
- inactive
- enrolled
- not enrolled

### 5. Faster Repeat Usage
With remembered sign-in, quick actions, and direct access to recent methods, repeat usage becomes faster.

### 6. Transparent Payment Tracking
The user can easily view:
- recent transactions
- full transaction history
- transaction details
- notifications

### 7. Strong User Guidance
The app guides the user through enrollment steps instead of expecting them to understand technical backend flows.

### 8. Bilingual Experience
The app supports Arabic and English, which improves accessibility for a wider user base.

## Summary
AmenPay User App is a customer payment-management app designed to work alongside the cashier-side payment infrastructure. It gives the user a secure and guided way to:
- manage cards
- use QR payments
- enroll and monitor NFC
- enroll and monitor Palm Vein
- track transactions
- receive notifications
- view analytics

Its main strength is that it combines secure account management with multiple assisted payment methods in one clear user experience.
