// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get brandName => 'AmenPay';

  @override
  String get cashierAppName => 'AmenPay Cashier';

  @override
  String get posSystem => 'Point of Sale System';

  @override
  String get languageEnglish => 'EN';

  @override
  String get languageArabic => 'AR';

  @override
  String get welcomeTitle => 'AmenPay';

  @override
  String get welcomeMessage => 'Welcome to AmenPay';

  @override
  String get welcomeTagline => 'Secure · Fast · Smooth';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get loginTitle => 'Welcome Back';

  @override
  String get loginSubtitle => 'Sign in to access your cashier dashboard';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get secureLogin => 'Secure Login';

  @override
  String get needHelp => 'Need help? Contact your store manager';

  @override
  String get forgotPasswordTitle => 'Forgot Password?';

  @override
  String get forgotPasswordSubtitle => 'Answer your security questions';

  @override
  String get registeredEmail => 'Registered Email';

  @override
  String get securityQuestionsSection =>
      'Security Questions (for password recovery)';

  @override
  String get securityQuestion1 => 'What is the name of your primary school?';

  @override
  String get securityQuestion1Hint => 'Your answer';

  @override
  String get securityQuestion2 => 'What is your favorite subject?';

  @override
  String get securityQuestion2Hint => 'Your answer';

  @override
  String get verifyAndResetPassword => 'Verify & Reset Password';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get resetPasswordSubtitle => 'Set your new account password';

  @override
  String get resetPasswordHint => 'Enter your new password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get submitNewPassword => 'Submit New Password';

  @override
  String get resetPasswordSuccess => 'Password has been reset successfully.';

  @override
  String get validationFullNameRequired => 'Please enter full name';

  @override
  String get validationEmailRequired => 'Please enter email';

  @override
  String get validationEmailInvalid => 'Enter valid email';

  @override
  String get validationPhoneRequired => 'Please enter phone';

  @override
  String get validationPasswordRequired => 'Please enter password';

  @override
  String get validationPasswordLength => 'Password must be at least 8 chars';

  @override
  String get validationConfirmPasswordRequired => 'Please confirm password';

  @override
  String get validationPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get validationSecurityAnswerRequired =>
      'Please answer this security question';

  @override
  String get signupTitle => 'Create Account';

  @override
  String get fullName => 'Full Name';

  @override
  String get phone => 'Phone';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signupSuccess => 'Account created successfully. Please log in.';

  @override
  String get deviceRegistrationCompleted => 'Device registration completed.';

  @override
  String get support247 => '24/7 Support';

  @override
  String get homeTitle => 'Home';

  @override
  String get logout => 'Logout';

  @override
  String get appTitleShort => 'PalmPay';

  @override
  String get cashier => 'Cashier';

  @override
  String get deviceIdLabel => 'Device';

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get balanceTrend => '+\$1,250.00  •  +12.5% this month';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get newPayment => 'New Payment';

  @override
  String get palmEnroll => 'Palm Enroll';

  @override
  String get transactions => 'Transactions';

  @override
  String get settings => 'Settings';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get viewAll => 'View All';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get totalExpense => 'Total Expense';

  @override
  String get trendUpWeek => '+12.5% this week';

  @override
  String get trendDownWeek => '+8.2% this week';

  @override
  String get searchByReference => 'Search by reference...';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get completed => 'Completed';

  @override
  String get pending => 'Pending';

  @override
  String get failed => 'Failed';

  @override
  String get refLabel => 'Ref';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String minutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String hoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get transactionDetailsTitle => 'Transaction Details';

  @override
  String get transactionFailedTitle => 'Transaction Failed';

  @override
  String get transactionFailedBody => 'Payment could not be processed';

  @override
  String get transactionPendingTitle => 'Transaction Pending';

  @override
  String get transactionPendingBody => 'Processing is in progress';

  @override
  String get transactionCompletedTitle => 'Transaction Completed';

  @override
  String get transactionCompletedBody => 'Payment processed successfully';

  @override
  String get currencyUsd => 'USD';

  @override
  String get transactionInformationTitle => 'Transaction Information';

  @override
  String get transactionIdLabel => 'Transaction ID';

  @override
  String get dateTimeLabel => 'Date & Time';

  @override
  String get merchantLabel => 'Merchant';

  @override
  String get referenceLabel => 'Reference';

  @override
  String get failureReasonTitle => 'Failure Reason';

  @override
  String get failureReasonBody =>
      'Insufficient funds available on the selected payment method.';

  @override
  String get errorCodeLabel => 'Error Code';

  @override
  String get declinedInsufficientFundsCode => 'DECLINED_INSUFFICIENT_FUNDS';

  @override
  String get amountBreakdownTitle => 'Amount Breakdown';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String get serviceFeeLabel => 'Service Fee';

  @override
  String get taxLabel => 'Tax';

  @override
  String get totalLabel => 'Total';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get reprintReceipt => 'Reprint Receipt';

  @override
  String get shareDetails => 'Share Details';

  @override
  String get needHelpTitle => 'Need Help?';

  @override
  String get needHelpBody =>
      'If you continue to experience issues, please contact support.';

  @override
  String get contactSupport => 'Contact Support →';

  @override
  String get txnPaymentReceived => 'Payment Received';

  @override
  String get txnSubscriptionPayment => 'Subscription Payment';

  @override
  String get txnOnlinePurchase => 'Online Purchase';

  @override
  String get txnFreelancePayment => 'Freelance Payment';

  @override
  String get txnRestaurantPayment => 'Restaurant Payment';

  @override
  String get txnTransferToSavings => 'Transfer to Savings';

  @override
  String get txnRefundReceived => 'Refund Received';

  @override
  String get txnPalmPayment => 'Palm Payment';

  @override
  String get palmBiometricStatus => 'Palm Biometric Status';

  @override
  String get palmStatusActive => 'Your palm is enrolled and active';

  @override
  String get managePalmData => 'Manage Palm Data';

  @override
  String get spendingThisWeek => 'Spending This Week';

  @override
  String get totalSpent => 'Total Spent';

  @override
  String get foodAndDining => 'Food & Dining';

  @override
  String get shopping => 'Shopping';

  @override
  String get transportation => 'Transportation';

  @override
  String get deviceStatus => 'Device Status';

  @override
  String get supportLogs => 'Support Logs';

  @override
  String get endShift => 'End Shift';

  @override
  String get endShiftAndLogout => 'End Shift & Logout';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get stepMethod => 'Method';

  @override
  String get stepAmount => 'Amount';

  @override
  String get stepPay => 'Pay';

  @override
  String get selectPaymentMethodTitle => 'Select Payment Method';

  @override
  String get selectPaymentMethodSubtitle =>
      'Choose your preferred payment option';

  @override
  String get qrCode => 'QR Code';

  @override
  String get qrCodeSubtitle => 'Scan to pay instantly';

  @override
  String get palmScan => 'Palm Scan';

  @override
  String get palmScanSubtitle => 'Biometric authentication';

  @override
  String get nfcTap => 'NFC Tap';

  @override
  String get nfcTapSubtitle => 'Contactless payment';

  @override
  String get quickAndSecure => 'Quick & Secure';

  @override
  String get highlySecure => 'Highly Secure';

  @override
  String get lightningFast => 'Lightning Fast';

  @override
  String get hardwareSupport => 'Hardware Support';

  @override
  String get hardwareSupportBody =>
      'Payment methods shown are based on your device hardware.';

  @override
  String get enterAmountTitle => 'Enter Amount';

  @override
  String get enterAmountSubtitle => 'How much would you like to send?';

  @override
  String get referenceOptional => 'Reference (Optional)';

  @override
  String get referenceHint => 'Invoice or order ID';

  @override
  String get transactionFeeTitle => 'Transaction Fee';

  @override
  String get transactionFeeBody =>
      'A fee of \$1.50 will be applied to this transaction.';

  @override
  String get placeYourPalm => 'Place Your Palm';

  @override
  String get placeYourPalmBody =>
      'Position your palm over the scanner to complete payment.';

  @override
  String get scanningProgress => 'Scanning Progress';

  @override
  String get positionDetected => 'Position Detected';

  @override
  String get positionDetectedBody => 'Keep your palm steady';

  @override
  String get scanningInProgress => 'Scanning in Progress';

  @override
  String get scanningInProgressBody => 'Please wait while we verify your palm';

  @override
  String get transactionAmount => 'Transaction Amount';

  @override
  String get cancelPayment => 'Cancel Payment';

  @override
  String get tapYourCard => 'Tap Your Card';

  @override
  String get tapYourCardBody =>
      'Hold your NFC-enabled card near your device to read the UID.';

  @override
  String get cardInformation => 'Card Information';

  @override
  String get waiting => 'Waiting';

  @override
  String get uid => 'UID';

  @override
  String get token => 'Token';

  @override
  String get cardType => 'Card Type';

  @override
  String get unknown => 'Unknown';

  @override
  String get startNewScan => 'Start New Scan';

  @override
  String get qrPaymentTitle => 'Scan QR Code';

  @override
  String get qrPaymentBody =>
      'Ask the customer to open their app and show the enrollment/payment QR.';

  @override
  String get scanningActive => 'Scanning Active';

  @override
  String get waitingForQr => 'Waiting for QR code...';

  @override
  String get qrPaymentResultTitle => 'QR Payment';

  @override
  String get qrPayloadShort => 'QR';

  @override
  String get customerIdentified => 'Customer Identified';

  @override
  String get qrScannedSuccessfully => 'QR code successfully scanned';

  @override
  String get verified => 'Verified';

  @override
  String get customerIdLabel => 'Customer ID:';

  @override
  String get accountBalance => 'Account Balance';

  @override
  String get proceedToPayment => 'Proceed to Payment';

  @override
  String get scanAnotherQr => 'Scan Another QR';

  @override
  String get todoScanAnotherQr => 'TODO: Scan another QR';

  @override
  String get processingTitle => 'Processing';

  @override
  String get pleaseWait => 'Please wait';

  @override
  String get requestReceived => 'Request received';

  @override
  String get analyzingData => 'Analyzing data';

  @override
  String get preparingResults => 'Preparing results';

  @override
  String get processingNote => 'This process typically takes 10-30 seconds';

  @override
  String get cancelRequest => 'Cancel Request';

  @override
  String get paymentResultTitle => 'Payment Result';

  @override
  String get paymentSuccessfulTitle => 'Payment Successful!';

  @override
  String get paymentSuccessfulBody =>
      'Your payment has been processed successfully';

  @override
  String get amountPaid => 'Amount Paid';

  @override
  String get referenceId => 'Reference ID';

  @override
  String get transactionTime => 'Transaction Time';

  @override
  String get paymentMethodLabel => 'Payment Method';

  @override
  String get downloadReceipt => 'Download Receipt';

  @override
  String get shareReceipt => 'Share Receipt';

  @override
  String get emailReceipt => 'Email Receipt';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get todoDownloadReceipt => 'TODO: Download receipt';

  @override
  String get todoShareReceipt => 'TODO: Share receipt';

  @override
  String get todoEmailReceipt => 'TODO: Email receipt';

  @override
  String get scanFailed => 'Scan failed';

  @override
  String get scanSuccessful => 'Scan successful';

  @override
  String get readyToProceed => 'Ready to proceed';

  @override
  String get startScan => 'Start Scan';

  @override
  String get retry => 'Retry';

  @override
  String get qrScanTimedOut => 'Timed out waiting for QR code';

  @override
  String get sourceLabel => 'Source';

  @override
  String get tapToRetry => 'Tap to retry';

  @override
  String get amount => 'Amount';

  @override
  String get amountHint => 'Enter amount';

  @override
  String get amountRequired => 'Amount is required';

  @override
  String get amountInvalid => 'Enter a valid amount';

  @override
  String get noteOptional => 'Note (Optional)';

  @override
  String get noteHint => 'Add a reference or note';

  @override
  String get continueLabel => 'Continue';

  @override
  String get language => 'Language';

  @override
  String get todoPaymentMethodSelection =>
      'TODO: Payment method selection screen';

  @override
  String get todoTransactions => 'TODO: Transactions screen';

  @override
  String get todoSettings => 'TODO: Settings screen';

  @override
  String get todoSettingsHint => 'Add app settings and admin tools here.';

  @override
  String get todoDeviceStatus => 'TODO: Device status / diagnostics screen';

  @override
  String get todoSupportLogs => 'TODO: Support logs screen';

  @override
  String get todoEndShift => 'TODO: End shift flow screen';

  @override
  String get enrollPalmVein => 'Enroll Palm Vein';

  @override
  String get testQrScanner => 'Test QR Scanner';

  @override
  String get testPalmVeinScanner => 'Test Palm Vein Scanner';

  @override
  String get testNfcCardScanner => 'Test NFC Card Scanner';

  @override
  String get testersHint =>
      'Use each tester first, confirm scanner output in logs, then continue app integration.';

  @override
  String get enrollNfcCard => 'Enroll NFC Card';

  @override
  String get stepClaim => 'Claim';

  @override
  String get stepNfcScan => 'NFC Scan';

  @override
  String get stepComplete => 'Complete';

  @override
  String get scanEnrollmentQrTitle =>
      'Scan the enrollment QR from the customer device.';

  @override
  String get scanEnrollmentQrBody =>
      'The POS app will claim the NFC enrollment session from backend. After a successful claim it will move to live NFC card scanning.';

  @override
  String get scanEnrollmentQrButton => 'Scan Enrollment QR';

  @override
  String get step2Of3 => 'Step 2 of 3';

  @override
  String get tapNfcCardOnReader => 'Tap NFC card on the reader';

  @override
  String get nfcEnrollmentClaimCompleteBody =>
      'The claim is complete. This POS now knows which payment method the NFC enrollment belongs to and will submit the scanned card to backend.';

  @override
  String get sessionLabel => 'Session';

  @override
  String get paymentMethodIdLabel => 'Payment Method ID';

  @override
  String get waitingForCard => 'Waiting for card...';

  @override
  String get startNfcScan => 'Start NFC Scan';

  @override
  String get nfcEnrollmentComplete => 'NFC enrollment complete';

  @override
  String get nfcFlowCompletedSuccessfully => 'NFC flow completed successfully.';

  @override
  String get nfcStatusLabel => 'NFC Status';

  @override
  String get qrPayloadLabel => 'QR Payload';

  @override
  String get uidHexLabel => 'UID (HEX)';

  @override
  String get uidDecLabel => 'UID (DEC)';

  @override
  String get actionLabel => 'Action';

  @override
  String get scannedAtLabel => 'Scanned At';

  @override
  String get done => 'Done';

  @override
  String get startNewNfcEnrollment => 'Start New NFC Enrollment';

  @override
  String get enrollPalmVeinTitle => 'Enroll Palm Vein';

  @override
  String get stepQrCode => 'QR Code';

  @override
  String get stepScanning => 'Scanning';

  @override
  String get scannerActive => 'SCANNER ACTIVE';

  @override
  String get scannerReady => 'SCANNER READY';

  @override
  String get scannerIdle => 'SCANNER IDLE';

  @override
  String get palmEnrollQrBody =>
      'Show the enrollment QR to the scanner window. Status updates below indicate readiness.';

  @override
  String get scanEnrollmentQrHint =>
      'Waiting for QR payload... (tap to focus scanner)';

  @override
  String get deviceIdNotLoaded => 'Device ID not loaded';

  @override
  String get deviceIdPrefix => 'Device ID';

  @override
  String get claimEnrollmentSession => 'Claim Enrollment Session';

  @override
  String get biometricDataSecureBody =>
      'Your biometric data is securely processed for POS authentication.';

  @override
  String get loadingPaymentMethodsTitle => 'Loading payment methods';

  @override
  String get loadingPaymentMethodsBody =>
      'Checking cards linked to this palm...';

  @override
  String get cardHolderLabel => 'CARD HOLDER';

  @override
  String get expiryLabel => 'EXPIRY';

  @override
  String get paymentMethodIdPrefix => 'Payment Method ID';

  @override
  String get identifyingCard => 'Identifying card...';

  @override
  String get cardIdentified => 'Card identified';

  @override
  String get waitingForNfcCard => 'Waiting for NFC card...';

  @override
  String get readyToScan => 'Ready to scan';

  @override
  String get customerLabel => 'Customer';

  @override
  String get unknownPlaceholder => 'Unknown';

  @override
  String get identifyingCardProgress => 'Identifying Card...';

  @override
  String get scanningProgressShort => 'Scanning...';

  @override
  String get paymentMethodShort => 'Payment Method';

  @override
  String get uidDecShort => 'UID DEC';

  @override
  String get sessionClaimedSuccessfully => 'Session claimed successfully';

  @override
  String get missingSessionIdClaimFirst =>
      'Missing session id. Claim session first.';

  @override
  String get deviceIdRequired => 'Device ID is required.';

  @override
  String get scanningPalmVeinTitle => 'Scanning palm vein';

  @override
  String get scanningPalmVeinBody =>
      'Keep your palm steady over the scanner while the capture is in progress.';

  @override
  String get waitingForLocalMatcherTitle => 'Waiting for local matcher';

  @override
  String get waitingForLocalMatcherBody =>
      'The local palm service app will capture and enroll the palm on this POS device.';

  @override
  String get submittingEnrollmentTitle => 'Submitting enrollment';

  @override
  String get submittingEnrollmentBody =>
      'Waiting for the server to finish processing this enrollment session.';

  @override
  String get enrollmentSubmittedSuccessfully =>
      'Enrollment submitted successfully';

  @override
  String get matcherUnavailableTitle => 'Matcher unavailable';

  @override
  String get enrollmentFailedTitle => 'Enrollment failed';

  @override
  String get missingNfcEnrollmentSession =>
      'Missing NFC enrollment session. Please restart the flow.';

  @override
  String get fetchingPaymentMethodTitle => 'Fetching payment method';

  @override
  String get pleaseWaitShort => 'Please wait...';

  @override
  String get paymentMethodDetailsTitle => 'Payment Method';

  @override
  String get cardNumberLabel => 'Card Number';

  @override
  String get statusLabel => 'Status';

  @override
  String get paymentStatusLabel => 'Payment Status';

  @override
  String get processingSubmittingPayment => 'Submitting payment';

  @override
  String get paymentSubmittedSuccessfully => 'Payment submitted successfully';

  @override
  String get authenticationUrl => 'Authentication URL';

  @override
  String get authenticationUrlCopied => 'Authentication URL copied';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get completeAuthenticationBody =>
      'Complete authentication with the provided URL, then verify the transaction result.';

  @override
  String get fixPaymentIssueBody => 'Fix the payment issue and try again.';

  @override
  String get recheckPayment => 'Recheck Payment';

  @override
  String get missingCustomerIdPayment =>
      'Missing customer id for this payment.';

  @override
  String get missingCustomerIdLookup =>
      'Missing customer id for transaction lookup.';

  @override
  String get failedFetchLatestTransaction =>
      'Failed to fetch latest transaction.';

  @override
  String get paymentPendingFurtherAction =>
      'Payment is pending further action.';

  @override
  String get latestTransactionFetched => 'Latest transaction fetched.';

  @override
  String latestTransactionStatus(Object status) {
    return 'Latest transaction status: $status';
  }

  @override
  String get paymentReceiptTitle => 'Payment Receipt';

  @override
  String get defaultCustomerName => 'AmenPay Customer';

  @override
  String get defaultCardPayment => 'Card payment';

  @override
  String get moyasarIdLabel => 'Moyasar ID';

  @override
  String get printReceipt => 'Print Receipt';

  @override
  String get refreshTransaction => 'Refresh Transaction';

  @override
  String get palmStep2Of3 => 'Step 2 of 3';

  @override
  String get palmSessionLabel => 'Session';

  @override
  String get palmScanningInProgressBody =>
      'Scanning in progress. Keep your palm steady.';

  @override
  String get palmPressStartBody =>
      'Press start when your palm is aligned over the scanner.';

  @override
  String get startPalmEnrollment => 'Start Palm Enrollment';

  @override
  String get scanningInProgressShort => 'Scanning in progress';

  @override
  String get awaitingEnrollment => 'Awaiting enrollment';

  @override
  String get enrollmentComplete => 'Enrollment complete';

  @override
  String get palmEnrollmentCompletedBody =>
      'Palm vein enrollment completed successfully for this cashier profile.';

  @override
  String get homeNoTransactions =>
      'No transactions found for the current user.';

  @override
  String get allFilter => 'All';

  @override
  String get noTransactionsFound => 'No transactions found.';

  @override
  String get cardReferenceLabel => 'Card / Reference';

  @override
  String get loadingInitializingConnection =>
      'Initializing secure connection...';

  @override
  String get loadingEncryption => '256-bit Encryption';

  @override
  String get loadingVersion => 'Version 1.0.0';

  @override
  String liveBalanceFromTransactions(Object count) {
    return 'Updated from $count transactions';
  }

  @override
  String get settingsOperationsTitle => 'POS Operations';

  @override
  String get settingsOperationsBody =>
      'Use settings to verify hardware readiness, pull support diagnostics, and adjust cashier preferences without leaving the terminal flow.';

  @override
  String get settingsMetricDevice => 'Device';

  @override
  String get settingsMetricSupport => 'Support';

  @override
  String get settingsMetricReady => 'Ready';

  @override
  String get settingsUnavailable => 'Unavailable';

  @override
  String get settingsSectionOperations => 'Operations';

  @override
  String get settingsSectionOperationsBody =>
      'Quick entry points for live device validation and operational troubleshooting.';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionPreferencesBody =>
      'Cashier-facing interface controls for this device session.';

  @override
  String get settingsDeviceStatusBody =>
      'Run scanner, NFC, display, and hardware checks.';

  @override
  String get settingsSupportLogsBody =>
      'Review support snapshot, diagnostics, and recovery steps.';

  @override
  String get settingsBadgeHardware => 'Hardware';

  @override
  String get settingsBadgeDiagnostics => 'Diagnostics';

  @override
  String get settingsLanguageBody =>
      'Switch cashier-facing labels without affecting enrollment or payment flows.';

  @override
  String get supportSnapshotTitle => 'Support Snapshot';

  @override
  String get supportSnapshotBody =>
      'Use this page when support needs a quick operational summary of the POS device and session state.';

  @override
  String get supportCopySnapshot => 'Copy Support Snapshot';

  @override
  String get supportSnapshotCopied => 'Support snapshot copied';

  @override
  String get supportSectionSessionState => 'Session State';

  @override
  String get supportSectionDeviceState => 'Device State';

  @override
  String get supportSectionRecommendedChecks => 'Recommended Checks';

  @override
  String get supportSectionRawDisplayDiagnostics => 'Raw Display Diagnostics';

  @override
  String get supportLoggedIn => 'Logged In';

  @override
  String get supportYes => 'Yes';

  @override
  String get supportNo => 'No';

  @override
  String get supportUserId => 'User ID';

  @override
  String get supportCapturedAt => 'Captured At';

  @override
  String get supportDeviceId => 'Device ID';

  @override
  String get supportDisplayCount => 'Display Count';

  @override
  String get supportPrimaryDisplay => 'Primary Display';

  @override
  String get supportCheckRegistration =>
      'Verify the POS device is registered and the cashier remains logged in.';

  @override
  String get supportCheckHardware =>
      'Use Device Status to test QR, NFC, palm, and display hardware independently.';

  @override
  String get supportCheckSnapshot =>
      'If payments fail unexpectedly, copy the support snapshot before restarting the app.';

  @override
  String get supportCheckScanner =>
      'If a scanner appears idle, reconnect the hardware and retry from Device Status.';

  @override
  String get deviceDisplayDiagnostics => 'Display Diagnostics';

  @override
  String get deviceClose => 'Close';

  @override
  String deviceDisplayDiagnosticsError(Object error) {
    return 'Display diagnostics error: $error';
  }

  @override
  String get deviceDisplayTestShown => 'Display test shown';

  @override
  String get deviceDisplayTestFailed => 'Display test failed';

  @override
  String deviceDisplayTestError(Object error) {
    return 'Display test error: $error';
  }

  @override
  String get deviceDisplayTestDismissed => 'Display test dismissed';

  @override
  String get deviceStatusQrBody => 'Verify serial/broadcast QR input';

  @override
  String get deviceStatusPalmBody => 'Check palm SDK and enrollment';

  @override
  String get deviceStatusNfcBody => 'Read NFC card UID';

  @override
  String get deviceStatusDisplayBody => 'List all detected displays';

  @override
  String get deviceStatusShowSecondary => 'Show Display Test (Secondary)';

  @override
  String get deviceStatusShowSecondaryBody =>
      'Render test screen on non-default display';

  @override
  String get deviceStatusDismissTest => 'Dismiss Display Test';

  @override
  String get deviceStatusDismissTestBody => 'Close the test presentation';

  @override
  String get receiptPreviewTitle => 'Receipt Preview';

  @override
  String get receiptPrintButton => 'Print Receipt';

  @override
  String get receiptPrinting => 'Printing...';

  @override
  String get receiptPrintJobSent => 'Print job sent';

  @override
  String get receiptPrintFailed => 'Failed to print receipt.';

  @override
  String get receiptBrandHeader => 'AMENPAY POS';

  @override
  String get receiptPreviewBody =>
      'This is the receipt preview that will be sent to the printer.';

  @override
  String get receiptTransactionTitle => 'Transaction Receipt';

  @override
  String get receiptPaymentTitle => 'Payment Receipt';

  @override
  String get receiptStatusLabel => 'Status';

  @override
  String get receiptCardLabel => 'Card';

  @override
  String get receiptCustomerLabel => 'Customer';

  @override
  String get receiptAmountLabel => 'Amount';

  @override
  String get receiptTimeLabel => 'Time';

  @override
  String get receiptMethodLabel => 'Method';

  @override
  String get receiptMerchantLabel => 'Merchant';
}
