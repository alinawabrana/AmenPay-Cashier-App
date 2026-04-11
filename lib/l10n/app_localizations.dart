import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'AmenPay'**
  String get brandName;

  /// No description provided for @cashierAppName.
  ///
  /// In en, this message translates to:
  /// **'AmenPay Cashier'**
  String get cashierAppName;

  /// No description provided for @posSystem.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale System'**
  String get posSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'AR'**
  String get languageArabic;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'AmenPay'**
  String get welcomeTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AmenPay'**
  String get welcomeMessage;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Secure · Fast · Smooth'**
  String get welcomeTagline;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your cashier dashboard'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @secureLogin.
  ///
  /// In en, this message translates to:
  /// **'Secure Login'**
  String get secureLogin;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? Contact your store manager'**
  String get needHelp;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Answer your security questions'**
  String get forgotPasswordSubtitle;

  /// No description provided for @registeredEmail.
  ///
  /// In en, this message translates to:
  /// **'Registered Email'**
  String get registeredEmail;

  /// No description provided for @securityQuestionsSection.
  ///
  /// In en, this message translates to:
  /// **'Security Questions (for password recovery)'**
  String get securityQuestionsSection;

  /// No description provided for @securityQuestion1.
  ///
  /// In en, this message translates to:
  /// **'What is the name of your primary school?'**
  String get securityQuestion1;

  /// No description provided for @securityQuestion1Hint.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get securityQuestion1Hint;

  /// No description provided for @securityQuestion2.
  ///
  /// In en, this message translates to:
  /// **'What is your favorite subject?'**
  String get securityQuestion2;

  /// No description provided for @securityQuestion2Hint.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get securityQuestion2Hint;

  /// No description provided for @verifyAndResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Verify & Reset Password'**
  String get verifyAndResetPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set your new account password'**
  String get resetPasswordSubtitle;

  /// No description provided for @resetPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password'**
  String get resetPasswordHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// No description provided for @submitNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Submit New Password'**
  String get submitNewPassword;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password has been reset successfully.'**
  String get resetPasswordSuccess;

  /// No description provided for @validationFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter full name'**
  String get validationFullNameRequired;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get validationEmailInvalid;

  /// No description provided for @validationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone'**
  String get validationPhoneRequired;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 chars'**
  String get validationPasswordLength;

  /// No description provided for @validationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm password'**
  String get validationConfirmPasswordRequired;

  /// No description provided for @validationPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordsDoNotMatch;

  /// No description provided for @validationSecurityAnswerRequired.
  ///
  /// In en, this message translates to:
  /// **'Please answer this security question'**
  String get validationSecurityAnswerRequired;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupTitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully. Please log in.'**
  String get signupSuccess;

  /// No description provided for @deviceRegistrationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Device registration completed.'**
  String get deviceRegistrationCompleted;

  /// No description provided for @support247.
  ///
  /// In en, this message translates to:
  /// **'24/7 Support'**
  String get support247;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @appTitleShort.
  ///
  /// In en, this message translates to:
  /// **'PalmPay'**
  String get appTitleShort;

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceIdLabel;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @balanceTrend.
  ///
  /// In en, this message translates to:
  /// **'+\$1,250.00  •  +12.5% this month'**
  String get balanceTrend;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @newPayment.
  ///
  /// In en, this message translates to:
  /// **'New Payment'**
  String get newPayment;

  /// No description provided for @palmEnroll.
  ///
  /// In en, this message translates to:
  /// **'Palm Enroll'**
  String get palmEnroll;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// No description provided for @totalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get totalExpense;

  /// No description provided for @trendUpWeek.
  ///
  /// In en, this message translates to:
  /// **'+12.5% this week'**
  String get trendUpWeek;

  /// No description provided for @trendDownWeek.
  ///
  /// In en, this message translates to:
  /// **'+8.2% this week'**
  String get trendDownWeek;

  /// No description provided for @searchByReference.
  ///
  /// In en, this message translates to:
  /// **'Search by reference...'**
  String get searchByReference;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @refLabel.
  ///
  /// In en, this message translates to:
  /// **'Ref'**
  String get refLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(Object count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(Object count);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @transactionDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetailsTitle;

  /// No description provided for @transactionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Failed'**
  String get transactionFailedTitle;

  /// No description provided for @transactionFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be processed'**
  String get transactionFailedBody;

  /// No description provided for @transactionPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Pending'**
  String get transactionPendingTitle;

  /// No description provided for @transactionPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Processing is in progress'**
  String get transactionPendingBody;

  /// No description provided for @transactionCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Completed'**
  String get transactionCompletedTitle;

  /// No description provided for @transactionCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Payment processed successfully'**
  String get transactionCompletedBody;

  /// No description provided for @currencyUsd.
  ///
  /// In en, this message translates to:
  /// **'USD'**
  String get currencyUsd;

  /// No description provided for @transactionInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Information'**
  String get transactionInformationTitle;

  /// No description provided for @transactionIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionIdLabel;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTimeLabel;

  /// No description provided for @merchantLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchantLabel;

  /// No description provided for @referenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get referenceLabel;

  /// No description provided for @failureReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Failure Reason'**
  String get failureReasonTitle;

  /// No description provided for @failureReasonBody.
  ///
  /// In en, this message translates to:
  /// **'Insufficient funds available on the selected payment method.'**
  String get failureReasonBody;

  /// No description provided for @errorCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Error Code'**
  String get errorCodeLabel;

  /// No description provided for @declinedInsufficientFundsCode.
  ///
  /// In en, this message translates to:
  /// **'DECLINED_INSUFFICIENT_FUNDS'**
  String get declinedInsufficientFundsCode;

  /// No description provided for @amountBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Amount Breakdown'**
  String get amountBreakdownTitle;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// No description provided for @serviceFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Fee'**
  String get serviceFeeLabel;

  /// No description provided for @taxLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get taxLabel;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @reprintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reprint Receipt'**
  String get reprintReceipt;

  /// No description provided for @shareDetails.
  ///
  /// In en, this message translates to:
  /// **'Share Details'**
  String get shareDetails;

  /// No description provided for @needHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get needHelpTitle;

  /// No description provided for @needHelpBody.
  ///
  /// In en, this message translates to:
  /// **'If you continue to experience issues, please contact support.'**
  String get needHelpBody;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support →'**
  String get contactSupport;

  /// No description provided for @txnPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment Received'**
  String get txnPaymentReceived;

  /// No description provided for @txnSubscriptionPayment.
  ///
  /// In en, this message translates to:
  /// **'Subscription Payment'**
  String get txnSubscriptionPayment;

  /// No description provided for @txnOnlinePurchase.
  ///
  /// In en, this message translates to:
  /// **'Online Purchase'**
  String get txnOnlinePurchase;

  /// No description provided for @txnFreelancePayment.
  ///
  /// In en, this message translates to:
  /// **'Freelance Payment'**
  String get txnFreelancePayment;

  /// No description provided for @txnRestaurantPayment.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Payment'**
  String get txnRestaurantPayment;

  /// No description provided for @txnTransferToSavings.
  ///
  /// In en, this message translates to:
  /// **'Transfer to Savings'**
  String get txnTransferToSavings;

  /// No description provided for @txnRefundReceived.
  ///
  /// In en, this message translates to:
  /// **'Refund Received'**
  String get txnRefundReceived;

  /// No description provided for @txnPalmPayment.
  ///
  /// In en, this message translates to:
  /// **'Palm Payment'**
  String get txnPalmPayment;

  /// No description provided for @palmBiometricStatus.
  ///
  /// In en, this message translates to:
  /// **'Palm Biometric Status'**
  String get palmBiometricStatus;

  /// No description provided for @palmStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Your palm is enrolled and active'**
  String get palmStatusActive;

  /// No description provided for @managePalmData.
  ///
  /// In en, this message translates to:
  /// **'Manage Palm Data'**
  String get managePalmData;

  /// No description provided for @spendingThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Spending This Week'**
  String get spendingThisWeek;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get totalSpent;

  /// No description provided for @foodAndDining.
  ///
  /// In en, this message translates to:
  /// **'Food & Dining'**
  String get foodAndDining;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @transportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get transportation;

  /// No description provided for @deviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Device Status'**
  String get deviceStatus;

  /// No description provided for @supportLogs.
  ///
  /// In en, this message translates to:
  /// **'Support Logs'**
  String get supportLogs;

  /// No description provided for @endShift.
  ///
  /// In en, this message translates to:
  /// **'End Shift'**
  String get endShift;

  /// No description provided for @endShiftAndLogout.
  ///
  /// In en, this message translates to:
  /// **'End Shift & Logout'**
  String get endShiftAndLogout;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @stepMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get stepMethod;

  /// No description provided for @stepAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get stepAmount;

  /// No description provided for @stepPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get stepPay;

  /// No description provided for @selectPaymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethodTitle;

  /// No description provided for @selectPaymentMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred payment option'**
  String get selectPaymentMethodSubtitle;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @qrCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to pay instantly'**
  String get qrCodeSubtitle;

  /// No description provided for @palmScan.
  ///
  /// In en, this message translates to:
  /// **'Palm Scan'**
  String get palmScan;

  /// No description provided for @palmScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication'**
  String get palmScanSubtitle;

  /// No description provided for @nfcTap.
  ///
  /// In en, this message translates to:
  /// **'NFC Tap'**
  String get nfcTap;

  /// No description provided for @nfcTapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contactless payment'**
  String get nfcTapSubtitle;

  /// No description provided for @quickAndSecure.
  ///
  /// In en, this message translates to:
  /// **'Quick & Secure'**
  String get quickAndSecure;

  /// No description provided for @highlySecure.
  ///
  /// In en, this message translates to:
  /// **'Highly Secure'**
  String get highlySecure;

  /// No description provided for @lightningFast.
  ///
  /// In en, this message translates to:
  /// **'Lightning Fast'**
  String get lightningFast;

  /// No description provided for @hardwareSupport.
  ///
  /// In en, this message translates to:
  /// **'Hardware Support'**
  String get hardwareSupport;

  /// No description provided for @hardwareSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Payment methods shown are based on your device hardware.'**
  String get hardwareSupportBody;

  /// No description provided for @enterAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get enterAmountTitle;

  /// No description provided for @enterAmountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How much would you like to send?'**
  String get enterAmountSubtitle;

  /// No description provided for @referenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Reference (Optional)'**
  String get referenceOptional;

  /// No description provided for @referenceHint.
  ///
  /// In en, this message translates to:
  /// **'Invoice or order ID'**
  String get referenceHint;

  /// No description provided for @transactionFeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Fee'**
  String get transactionFeeTitle;

  /// No description provided for @transactionFeeBody.
  ///
  /// In en, this message translates to:
  /// **'A fee of \$1.50 will be applied to this transaction.'**
  String get transactionFeeBody;

  /// No description provided for @placeYourPalm.
  ///
  /// In en, this message translates to:
  /// **'Place Your Palm'**
  String get placeYourPalm;

  /// No description provided for @placeYourPalmBody.
  ///
  /// In en, this message translates to:
  /// **'Position your palm over the scanner to complete payment.'**
  String get placeYourPalmBody;

  /// No description provided for @scanningProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanning Progress'**
  String get scanningProgress;

  /// No description provided for @positionDetected.
  ///
  /// In en, this message translates to:
  /// **'Position Detected'**
  String get positionDetected;

  /// No description provided for @positionDetectedBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your palm steady'**
  String get positionDetectedBody;

  /// No description provided for @scanningInProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanning in Progress'**
  String get scanningInProgress;

  /// No description provided for @scanningInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we verify your palm'**
  String get scanningInProgressBody;

  /// No description provided for @transactionAmount.
  ///
  /// In en, this message translates to:
  /// **'Transaction Amount'**
  String get transactionAmount;

  /// No description provided for @cancelPayment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Payment'**
  String get cancelPayment;

  /// No description provided for @tapYourCard.
  ///
  /// In en, this message translates to:
  /// **'Tap Your Card'**
  String get tapYourCard;

  /// No description provided for @tapYourCardBody.
  ///
  /// In en, this message translates to:
  /// **'Hold your NFC-enabled card near your device to read the UID.'**
  String get tapYourCardBody;

  /// No description provided for @cardInformation.
  ///
  /// In en, this message translates to:
  /// **'Card Information'**
  String get cardInformation;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @uid.
  ///
  /// In en, this message translates to:
  /// **'UID'**
  String get uid;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get token;

  /// No description provided for @cardType.
  ///
  /// In en, this message translates to:
  /// **'Card Type'**
  String get cardType;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @startNewScan.
  ///
  /// In en, this message translates to:
  /// **'Start New Scan'**
  String get startNewScan;

  /// No description provided for @qrPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get qrPaymentTitle;

  /// No description provided for @qrPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer to open their app and show the enrollment/payment QR.'**
  String get qrPaymentBody;

  /// No description provided for @scanningActive.
  ///
  /// In en, this message translates to:
  /// **'Scanning Active'**
  String get scanningActive;

  /// No description provided for @waitingForQr.
  ///
  /// In en, this message translates to:
  /// **'Waiting for QR code...'**
  String get waitingForQr;

  /// No description provided for @qrPaymentResultTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Payment'**
  String get qrPaymentResultTitle;

  /// No description provided for @qrPayloadShort.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get qrPayloadShort;

  /// No description provided for @customerIdentified.
  ///
  /// In en, this message translates to:
  /// **'Customer Identified'**
  String get customerIdentified;

  /// No description provided for @qrScannedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'QR code successfully scanned'**
  String get qrScannedSuccessfully;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @customerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer ID:'**
  String get customerIdLabel;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account Balance'**
  String get accountBalance;

  /// No description provided for @proceedToPayment.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get proceedToPayment;

  /// No description provided for @scanAnotherQr.
  ///
  /// In en, this message translates to:
  /// **'Scan Another QR'**
  String get scanAnotherQr;

  /// No description provided for @todoScanAnotherQr.
  ///
  /// In en, this message translates to:
  /// **'TODO: Scan another QR'**
  String get todoScanAnotherQr;

  /// No description provided for @processingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processingTitle;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @requestReceived.
  ///
  /// In en, this message translates to:
  /// **'Request received'**
  String get requestReceived;

  /// No description provided for @analyzingData.
  ///
  /// In en, this message translates to:
  /// **'Analyzing data'**
  String get analyzingData;

  /// No description provided for @preparingResults.
  ///
  /// In en, this message translates to:
  /// **'Preparing results'**
  String get preparingResults;

  /// No description provided for @processingNote.
  ///
  /// In en, this message translates to:
  /// **'This process typically takes 10-30 seconds'**
  String get processingNote;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @paymentResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Result'**
  String get paymentResultTitle;

  /// No description provided for @paymentSuccessfulTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessfulTitle;

  /// No description provided for @paymentSuccessfulBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment has been processed successfully'**
  String get paymentSuccessfulBody;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// No description provided for @referenceId.
  ///
  /// In en, this message translates to:
  /// **'Reference ID'**
  String get referenceId;

  /// No description provided for @transactionTime.
  ///
  /// In en, this message translates to:
  /// **'Transaction Time'**
  String get transactionTime;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodLabel;

  /// No description provided for @downloadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Download Receipt'**
  String get downloadReceipt;

  /// No description provided for @shareReceipt.
  ///
  /// In en, this message translates to:
  /// **'Share Receipt'**
  String get shareReceipt;

  /// No description provided for @emailReceipt.
  ///
  /// In en, this message translates to:
  /// **'Email Receipt'**
  String get emailReceipt;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @todoDownloadReceipt.
  ///
  /// In en, this message translates to:
  /// **'TODO: Download receipt'**
  String get todoDownloadReceipt;

  /// No description provided for @todoShareReceipt.
  ///
  /// In en, this message translates to:
  /// **'TODO: Share receipt'**
  String get todoShareReceipt;

  /// No description provided for @todoEmailReceipt.
  ///
  /// In en, this message translates to:
  /// **'TODO: Email receipt'**
  String get todoEmailReceipt;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get scanFailed;

  /// No description provided for @scanSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Scan successful'**
  String get scanSuccessful;

  /// No description provided for @readyToProceed.
  ///
  /// In en, this message translates to:
  /// **'Ready to proceed'**
  String get readyToProceed;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @qrScanTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out waiting for QR code'**
  String get qrScanTimedOut;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @tapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @amountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get amountHint;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get amountRequired;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get amountInvalid;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (Optional)'**
  String get noteOptional;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a reference or note'**
  String get noteHint;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @todoPaymentMethodSelection.
  ///
  /// In en, this message translates to:
  /// **'TODO: Payment method selection screen'**
  String get todoPaymentMethodSelection;

  /// No description provided for @todoTransactions.
  ///
  /// In en, this message translates to:
  /// **'TODO: Transactions screen'**
  String get todoTransactions;

  /// No description provided for @todoSettings.
  ///
  /// In en, this message translates to:
  /// **'TODO: Settings screen'**
  String get todoSettings;

  /// No description provided for @todoSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Add app settings and admin tools here.'**
  String get todoSettingsHint;

  /// No description provided for @todoDeviceStatus.
  ///
  /// In en, this message translates to:
  /// **'TODO: Device status / diagnostics screen'**
  String get todoDeviceStatus;

  /// No description provided for @todoSupportLogs.
  ///
  /// In en, this message translates to:
  /// **'TODO: Support logs screen'**
  String get todoSupportLogs;

  /// No description provided for @todoEndShift.
  ///
  /// In en, this message translates to:
  /// **'TODO: End shift flow screen'**
  String get todoEndShift;

  /// No description provided for @enrollPalmVein.
  ///
  /// In en, this message translates to:
  /// **'Enroll Palm Vein'**
  String get enrollPalmVein;

  /// No description provided for @testQrScanner.
  ///
  /// In en, this message translates to:
  /// **'Test QR Scanner'**
  String get testQrScanner;

  /// No description provided for @testPalmVeinScanner.
  ///
  /// In en, this message translates to:
  /// **'Test Palm Vein Scanner'**
  String get testPalmVeinScanner;

  /// No description provided for @testNfcCardScanner.
  ///
  /// In en, this message translates to:
  /// **'Test NFC Card Scanner'**
  String get testNfcCardScanner;

  /// No description provided for @testersHint.
  ///
  /// In en, this message translates to:
  /// **'Use each tester first, confirm scanner output in logs, then continue app integration.'**
  String get testersHint;

  /// No description provided for @enrollNfcCard.
  ///
  /// In en, this message translates to:
  /// **'Enroll NFC Card'**
  String get enrollNfcCard;

  /// No description provided for @stepClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get stepClaim;

  /// No description provided for @stepNfcScan.
  ///
  /// In en, this message translates to:
  /// **'NFC Scan'**
  String get stepNfcScan;

  /// No description provided for @stepComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get stepComplete;

  /// No description provided for @scanEnrollmentQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the enrollment QR from the customer device.'**
  String get scanEnrollmentQrTitle;

  /// No description provided for @scanEnrollmentQrBody.
  ///
  /// In en, this message translates to:
  /// **'The POS app will claim the NFC enrollment session from backend. After a successful claim it will move to live NFC card scanning.'**
  String get scanEnrollmentQrBody;

  /// No description provided for @scanEnrollmentQrButton.
  ///
  /// In en, this message translates to:
  /// **'Scan Enrollment QR'**
  String get scanEnrollmentQrButton;

  /// No description provided for @step2Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3'**
  String get step2Of3;

  /// No description provided for @tapNfcCardOnReader.
  ///
  /// In en, this message translates to:
  /// **'Tap NFC card on the reader'**
  String get tapNfcCardOnReader;

  /// No description provided for @nfcEnrollmentClaimCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'The claim is complete. This POS now knows which payment method the NFC enrollment belongs to and will submit the scanned card to backend.'**
  String get nfcEnrollmentClaimCompleteBody;

  /// No description provided for @sessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionLabel;

  /// No description provided for @paymentMethodIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method ID'**
  String get paymentMethodIdLabel;

  /// No description provided for @waitingForCard.
  ///
  /// In en, this message translates to:
  /// **'Waiting for card...'**
  String get waitingForCard;

  /// No description provided for @startNfcScan.
  ///
  /// In en, this message translates to:
  /// **'Start NFC Scan'**
  String get startNfcScan;

  /// No description provided for @nfcEnrollmentComplete.
  ///
  /// In en, this message translates to:
  /// **'NFC enrollment complete'**
  String get nfcEnrollmentComplete;

  /// No description provided for @nfcFlowCompletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'NFC flow completed successfully.'**
  String get nfcFlowCompletedSuccessfully;

  /// No description provided for @nfcStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'NFC Status'**
  String get nfcStatusLabel;

  /// No description provided for @qrPayloadLabel.
  ///
  /// In en, this message translates to:
  /// **'QR Payload'**
  String get qrPayloadLabel;

  /// No description provided for @uidHexLabel.
  ///
  /// In en, this message translates to:
  /// **'UID (HEX)'**
  String get uidHexLabel;

  /// No description provided for @uidDecLabel.
  ///
  /// In en, this message translates to:
  /// **'UID (DEC)'**
  String get uidDecLabel;

  /// No description provided for @actionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionLabel;

  /// No description provided for @scannedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Scanned At'**
  String get scannedAtLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @startNewNfcEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Start New NFC Enrollment'**
  String get startNewNfcEnrollment;

  /// No description provided for @enrollPalmVeinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enroll Palm Vein'**
  String get enrollPalmVeinTitle;

  /// No description provided for @stepQrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get stepQrCode;

  /// No description provided for @stepScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get stepScanning;

  /// No description provided for @scannerActive.
  ///
  /// In en, this message translates to:
  /// **'SCANNER ACTIVE'**
  String get scannerActive;

  /// No description provided for @scannerReady.
  ///
  /// In en, this message translates to:
  /// **'SCANNER READY'**
  String get scannerReady;

  /// No description provided for @scannerIdle.
  ///
  /// In en, this message translates to:
  /// **'SCANNER IDLE'**
  String get scannerIdle;

  /// No description provided for @palmEnrollQrBody.
  ///
  /// In en, this message translates to:
  /// **'Show the enrollment QR to the scanner window. Status updates below indicate readiness.'**
  String get palmEnrollQrBody;

  /// No description provided for @scanEnrollmentQrHint.
  ///
  /// In en, this message translates to:
  /// **'Waiting for QR payload... (tap to focus scanner)'**
  String get scanEnrollmentQrHint;

  /// No description provided for @deviceIdNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Device ID not loaded'**
  String get deviceIdNotLoaded;

  /// No description provided for @deviceIdPrefix.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdPrefix;

  /// No description provided for @claimEnrollmentSession.
  ///
  /// In en, this message translates to:
  /// **'Claim Enrollment Session'**
  String get claimEnrollmentSession;

  /// No description provided for @biometricDataSecureBody.
  ///
  /// In en, this message translates to:
  /// **'Your biometric data is securely processed for POS authentication.'**
  String get biometricDataSecureBody;

  /// No description provided for @loadingPaymentMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading payment methods'**
  String get loadingPaymentMethodsTitle;

  /// No description provided for @loadingPaymentMethodsBody.
  ///
  /// In en, this message translates to:
  /// **'Checking cards linked to this palm...'**
  String get loadingPaymentMethodsBody;

  /// No description provided for @cardHolderLabel.
  ///
  /// In en, this message translates to:
  /// **'CARD HOLDER'**
  String get cardHolderLabel;

  /// No description provided for @expiryLabel.
  ///
  /// In en, this message translates to:
  /// **'EXPIRY'**
  String get expiryLabel;

  /// No description provided for @paymentMethodIdPrefix.
  ///
  /// In en, this message translates to:
  /// **'Payment Method ID'**
  String get paymentMethodIdPrefix;

  /// No description provided for @identifyingCard.
  ///
  /// In en, this message translates to:
  /// **'Identifying card...'**
  String get identifyingCard;

  /// No description provided for @cardIdentified.
  ///
  /// In en, this message translates to:
  /// **'Card identified'**
  String get cardIdentified;

  /// No description provided for @waitingForNfcCard.
  ///
  /// In en, this message translates to:
  /// **'Waiting for NFC card...'**
  String get waitingForNfcCard;

  /// No description provided for @readyToScan.
  ///
  /// In en, this message translates to:
  /// **'Ready to scan'**
  String get readyToScan;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerLabel;

  /// No description provided for @unknownPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownPlaceholder;

  /// No description provided for @identifyingCardProgress.
  ///
  /// In en, this message translates to:
  /// **'Identifying Card...'**
  String get identifyingCardProgress;

  /// No description provided for @scanningProgressShort.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanningProgressShort;

  /// No description provided for @paymentMethodShort.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodShort;

  /// No description provided for @uidDecShort.
  ///
  /// In en, this message translates to:
  /// **'UID DEC'**
  String get uidDecShort;

  /// No description provided for @sessionClaimedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Session claimed successfully'**
  String get sessionClaimedSuccessfully;

  /// No description provided for @missingSessionIdClaimFirst.
  ///
  /// In en, this message translates to:
  /// **'Missing session id. Claim session first.'**
  String get missingSessionIdClaimFirst;

  /// No description provided for @deviceIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Device ID is required.'**
  String get deviceIdRequired;

  /// No description provided for @scanningPalmVeinTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanning palm vein'**
  String get scanningPalmVeinTitle;

  /// No description provided for @scanningPalmVeinBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your palm steady over the scanner while the capture is in progress.'**
  String get scanningPalmVeinBody;

  /// No description provided for @waitingForLocalMatcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for local matcher'**
  String get waitingForLocalMatcherTitle;

  /// No description provided for @waitingForLocalMatcherBody.
  ///
  /// In en, this message translates to:
  /// **'The local palm service app will capture and enroll the palm on this POS device.'**
  String get waitingForLocalMatcherBody;

  /// No description provided for @submittingEnrollmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting enrollment'**
  String get submittingEnrollmentTitle;

  /// No description provided for @submittingEnrollmentBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the server to finish processing this enrollment session.'**
  String get submittingEnrollmentBody;

  /// No description provided for @enrollmentSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Enrollment submitted successfully'**
  String get enrollmentSubmittedSuccessfully;

  /// No description provided for @matcherUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Matcher unavailable'**
  String get matcherUnavailableTitle;

  /// No description provided for @enrollmentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Enrollment failed'**
  String get enrollmentFailedTitle;

  /// No description provided for @missingNfcEnrollmentSession.
  ///
  /// In en, this message translates to:
  /// **'Missing NFC enrollment session. Please restart the flow.'**
  String get missingNfcEnrollmentSession;

  /// No description provided for @fetchingPaymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Fetching payment method'**
  String get fetchingPaymentMethodTitle;

  /// No description provided for @pleaseWaitShort.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWaitShort;

  /// No description provided for @paymentMethodDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodDetailsTitle;

  /// No description provided for @cardNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumberLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @paymentStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatusLabel;

  /// No description provided for @processingSubmittingPayment.
  ///
  /// In en, this message translates to:
  /// **'Submitting payment'**
  String get processingSubmittingPayment;

  /// No description provided for @paymentSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Payment submitted successfully'**
  String get paymentSubmittedSuccessfully;

  /// No description provided for @authenticationUrl.
  ///
  /// In en, this message translates to:
  /// **'Authentication URL'**
  String get authenticationUrl;

  /// No description provided for @authenticationUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Authentication URL copied'**
  String get authenticationUrlCopied;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @completeAuthenticationBody.
  ///
  /// In en, this message translates to:
  /// **'Complete authentication with the provided URL, then verify the transaction result.'**
  String get completeAuthenticationBody;

  /// No description provided for @fixPaymentIssueBody.
  ///
  /// In en, this message translates to:
  /// **'Fix the payment issue and try again.'**
  String get fixPaymentIssueBody;

  /// No description provided for @recheckPayment.
  ///
  /// In en, this message translates to:
  /// **'Recheck Payment'**
  String get recheckPayment;

  /// No description provided for @missingCustomerIdPayment.
  ///
  /// In en, this message translates to:
  /// **'Missing customer id for this payment.'**
  String get missingCustomerIdPayment;

  /// No description provided for @missingCustomerIdLookup.
  ///
  /// In en, this message translates to:
  /// **'Missing customer id for transaction lookup.'**
  String get missingCustomerIdLookup;

  /// No description provided for @failedFetchLatestTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch latest transaction.'**
  String get failedFetchLatestTransaction;

  /// No description provided for @paymentPendingFurtherAction.
  ///
  /// In en, this message translates to:
  /// **'Payment is pending further action.'**
  String get paymentPendingFurtherAction;

  /// No description provided for @latestTransactionFetched.
  ///
  /// In en, this message translates to:
  /// **'Latest transaction fetched.'**
  String get latestTransactionFetched;

  /// No description provided for @latestTransactionStatus.
  ///
  /// In en, this message translates to:
  /// **'Latest transaction status: {status}'**
  String latestTransactionStatus(Object status);

  /// No description provided for @paymentReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Receipt'**
  String get paymentReceiptTitle;

  /// No description provided for @defaultCustomerName.
  ///
  /// In en, this message translates to:
  /// **'AmenPay Customer'**
  String get defaultCustomerName;

  /// No description provided for @defaultCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card payment'**
  String get defaultCardPayment;

  /// No description provided for @moyasarIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Moyasar ID'**
  String get moyasarIdLabel;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @refreshTransaction.
  ///
  /// In en, this message translates to:
  /// **'Refresh Transaction'**
  String get refreshTransaction;

  /// No description provided for @palmStep2Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3'**
  String get palmStep2Of3;

  /// No description provided for @palmSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get palmSessionLabel;

  /// No description provided for @palmScanningInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Scanning in progress. Keep your palm steady.'**
  String get palmScanningInProgressBody;

  /// No description provided for @palmPressStartBody.
  ///
  /// In en, this message translates to:
  /// **'Press start when your palm is aligned over the scanner.'**
  String get palmPressStartBody;

  /// No description provided for @startPalmEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Start Palm Enrollment'**
  String get startPalmEnrollment;

  /// No description provided for @scanningInProgressShort.
  ///
  /// In en, this message translates to:
  /// **'Scanning in progress'**
  String get scanningInProgressShort;

  /// No description provided for @awaitingEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting enrollment'**
  String get awaitingEnrollment;

  /// No description provided for @enrollmentComplete.
  ///
  /// In en, this message translates to:
  /// **'Enrollment complete'**
  String get enrollmentComplete;

  /// No description provided for @palmEnrollmentCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Palm vein enrollment completed successfully for this cashier profile.'**
  String get palmEnrollmentCompletedBody;

  /// No description provided for @homeNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions found for the current user.'**
  String get homeNoTransactions;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @noTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found.'**
  String get noTransactionsFound;

  /// No description provided for @cardReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Card / Reference'**
  String get cardReferenceLabel;

  /// No description provided for @loadingInitializingConnection.
  ///
  /// In en, this message translates to:
  /// **'Initializing secure connection...'**
  String get loadingInitializingConnection;

  /// No description provided for @loadingEncryption.
  ///
  /// In en, this message translates to:
  /// **'256-bit Encryption'**
  String get loadingEncryption;

  /// No description provided for @loadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get loadingVersion;

  /// No description provided for @liveBalanceFromTransactions.
  ///
  /// In en, this message translates to:
  /// **'Updated from {count} transactions'**
  String liveBalanceFromTransactions(Object count);

  /// No description provided for @settingsOperationsTitle.
  ///
  /// In en, this message translates to:
  /// **'POS Operations'**
  String get settingsOperationsTitle;

  /// No description provided for @settingsOperationsBody.
  ///
  /// In en, this message translates to:
  /// **'Use settings to verify hardware readiness, pull support diagnostics, and adjust cashier preferences without leaving the terminal flow.'**
  String get settingsOperationsBody;

  /// No description provided for @settingsMetricDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get settingsMetricDevice;

  /// No description provided for @settingsMetricSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsMetricSupport;

  /// No description provided for @settingsMetricReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get settingsMetricReady;

  /// No description provided for @settingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get settingsUnavailable;

  /// No description provided for @settingsSectionOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get settingsSectionOperations;

  /// No description provided for @settingsSectionOperationsBody.
  ///
  /// In en, this message translates to:
  /// **'Quick entry points for live device validation and operational troubleshooting.'**
  String get settingsSectionOperationsBody;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsSectionPreferencesBody.
  ///
  /// In en, this message translates to:
  /// **'Cashier-facing interface controls for this device session.'**
  String get settingsSectionPreferencesBody;

  /// No description provided for @settingsDeviceStatusBody.
  ///
  /// In en, this message translates to:
  /// **'Run scanner, NFC, display, and hardware checks.'**
  String get settingsDeviceStatusBody;

  /// No description provided for @settingsSupportLogsBody.
  ///
  /// In en, this message translates to:
  /// **'Review support snapshot, diagnostics, and recovery steps.'**
  String get settingsSupportLogsBody;

  /// No description provided for @settingsBadgeHardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get settingsBadgeHardware;

  /// No description provided for @settingsBadgeDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsBadgeDiagnostics;

  /// No description provided for @settingsLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Switch cashier-facing labels without affecting enrollment or payment flows.'**
  String get settingsLanguageBody;

  /// No description provided for @supportSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Snapshot'**
  String get supportSnapshotTitle;

  /// No description provided for @supportSnapshotBody.
  ///
  /// In en, this message translates to:
  /// **'Use this page when support needs a quick operational summary of the POS device and session state.'**
  String get supportSnapshotBody;

  /// No description provided for @supportCopySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Copy Support Snapshot'**
  String get supportCopySnapshot;

  /// No description provided for @supportSnapshotCopied.
  ///
  /// In en, this message translates to:
  /// **'Support snapshot copied'**
  String get supportSnapshotCopied;

  /// No description provided for @supportSectionSessionState.
  ///
  /// In en, this message translates to:
  /// **'Session State'**
  String get supportSectionSessionState;

  /// No description provided for @supportSectionDeviceState.
  ///
  /// In en, this message translates to:
  /// **'Device State'**
  String get supportSectionDeviceState;

  /// No description provided for @supportSectionRecommendedChecks.
  ///
  /// In en, this message translates to:
  /// **'Recommended Checks'**
  String get supportSectionRecommendedChecks;

  /// No description provided for @supportSectionRawDisplayDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Raw Display Diagnostics'**
  String get supportSectionRawDisplayDiagnostics;

  /// No description provided for @supportLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Logged In'**
  String get supportLoggedIn;

  /// No description provided for @supportYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get supportYes;

  /// No description provided for @supportNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get supportNo;

  /// No description provided for @supportUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get supportUserId;

  /// No description provided for @supportCapturedAt.
  ///
  /// In en, this message translates to:
  /// **'Captured At'**
  String get supportCapturedAt;

  /// No description provided for @supportDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get supportDeviceId;

  /// No description provided for @supportDisplayCount.
  ///
  /// In en, this message translates to:
  /// **'Display Count'**
  String get supportDisplayCount;

  /// No description provided for @supportPrimaryDisplay.
  ///
  /// In en, this message translates to:
  /// **'Primary Display'**
  String get supportPrimaryDisplay;

  /// No description provided for @supportCheckRegistration.
  ///
  /// In en, this message translates to:
  /// **'Verify the POS device is registered and the cashier remains logged in.'**
  String get supportCheckRegistration;

  /// No description provided for @supportCheckHardware.
  ///
  /// In en, this message translates to:
  /// **'Use Device Status to test QR, NFC, palm, and display hardware independently.'**
  String get supportCheckHardware;

  /// No description provided for @supportCheckSnapshot.
  ///
  /// In en, this message translates to:
  /// **'If payments fail unexpectedly, copy the support snapshot before restarting the app.'**
  String get supportCheckSnapshot;

  /// No description provided for @supportCheckScanner.
  ///
  /// In en, this message translates to:
  /// **'If a scanner appears idle, reconnect the hardware and retry from Device Status.'**
  String get supportCheckScanner;

  /// No description provided for @deviceDisplayDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Display Diagnostics'**
  String get deviceDisplayDiagnostics;

  /// No description provided for @deviceClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get deviceClose;

  /// No description provided for @deviceDisplayDiagnosticsError.
  ///
  /// In en, this message translates to:
  /// **'Display diagnostics error: {error}'**
  String deviceDisplayDiagnosticsError(Object error);

  /// No description provided for @deviceDisplayTestShown.
  ///
  /// In en, this message translates to:
  /// **'Display test shown'**
  String get deviceDisplayTestShown;

  /// No description provided for @deviceDisplayTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Display test failed'**
  String get deviceDisplayTestFailed;

  /// No description provided for @deviceDisplayTestError.
  ///
  /// In en, this message translates to:
  /// **'Display test error: {error}'**
  String deviceDisplayTestError(Object error);

  /// No description provided for @deviceDisplayTestDismissed.
  ///
  /// In en, this message translates to:
  /// **'Display test dismissed'**
  String get deviceDisplayTestDismissed;

  /// No description provided for @deviceStatusQrBody.
  ///
  /// In en, this message translates to:
  /// **'Verify serial/broadcast QR input'**
  String get deviceStatusQrBody;

  /// No description provided for @deviceStatusPalmBody.
  ///
  /// In en, this message translates to:
  /// **'Check palm SDK and enrollment'**
  String get deviceStatusPalmBody;

  /// No description provided for @deviceStatusNfcBody.
  ///
  /// In en, this message translates to:
  /// **'Read NFC card UID'**
  String get deviceStatusNfcBody;

  /// No description provided for @deviceStatusDisplayBody.
  ///
  /// In en, this message translates to:
  /// **'List all detected displays'**
  String get deviceStatusDisplayBody;

  /// No description provided for @deviceStatusShowSecondary.
  ///
  /// In en, this message translates to:
  /// **'Show Display Test (Secondary)'**
  String get deviceStatusShowSecondary;

  /// No description provided for @deviceStatusShowSecondaryBody.
  ///
  /// In en, this message translates to:
  /// **'Render test screen on non-default display'**
  String get deviceStatusShowSecondaryBody;

  /// No description provided for @deviceStatusDismissTest.
  ///
  /// In en, this message translates to:
  /// **'Dismiss Display Test'**
  String get deviceStatusDismissTest;

  /// No description provided for @deviceStatusDismissTestBody.
  ///
  /// In en, this message translates to:
  /// **'Close the test presentation'**
  String get deviceStatusDismissTestBody;

  /// No description provided for @receiptPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt Preview'**
  String get receiptPreviewTitle;

  /// No description provided for @receiptPrintButton.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get receiptPrintButton;

  /// No description provided for @receiptPrinting.
  ///
  /// In en, this message translates to:
  /// **'Printing...'**
  String get receiptPrinting;

  /// No description provided for @receiptPrintJobSent.
  ///
  /// In en, this message translates to:
  /// **'Print job sent'**
  String get receiptPrintJobSent;

  /// No description provided for @receiptPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to print receipt.'**
  String get receiptPrintFailed;

  /// No description provided for @receiptBrandHeader.
  ///
  /// In en, this message translates to:
  /// **'AMENPAY POS'**
  String get receiptBrandHeader;

  /// No description provided for @receiptPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This is the receipt preview that will be sent to the printer.'**
  String get receiptPreviewBody;

  /// No description provided for @receiptTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Receipt'**
  String get receiptTransactionTitle;

  /// No description provided for @receiptPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Receipt'**
  String get receiptPaymentTitle;

  /// No description provided for @receiptStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get receiptStatusLabel;

  /// No description provided for @receiptCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get receiptCardLabel;

  /// No description provided for @receiptCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get receiptCustomerLabel;

  /// No description provided for @receiptAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get receiptAmountLabel;

  /// No description provided for @receiptTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get receiptTimeLabel;

  /// No description provided for @receiptMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get receiptMethodLabel;

  /// No description provided for @receiptMerchantLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get receiptMerchantLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
