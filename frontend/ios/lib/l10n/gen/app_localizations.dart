import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('fr'),
    Locale('nl')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AImesis'**
  String get appTitle;

  /// No description provided for @forFamilies.
  ///
  /// In en, this message translates to:
  /// **'For families'**
  String get forFamilies;

  /// No description provided for @welcomeIntro.
  ///
  /// In en, this message translates to:
  /// **'Log how your child feels with one tap, and keep the medicine plan close by.'**
  String get welcomeIntro;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @demoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Demo accounts'**
  String get demoAccounts;

  /// No description provided for @demoPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Demo password: {password}'**
  String demoPasswordHint(String password);

  /// No description provided for @clinicianNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This app is for families; the care team uses the AImesis web app.'**
  String get clinicianNotAllowed;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Check your email and password.'**
  String get loginFailed;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'No connection to AImesis. Check your internet and try again.'**
  String get networkError;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @demoFooter.
  ///
  /// In en, this message translates to:
  /// **'Demo app — not for medical use'**
  String get demoFooter;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Teen'**
  String get rolePatient;

  /// No description provided for @pairTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your child'**
  String get pairTitle;

  /// No description provided for @pairIntro.
  ///
  /// In en, this message translates to:
  /// **'Type the code you got from the ward. You can find it on the Passport.'**
  String get pairIntro;

  /// No description provided for @pairCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code from the ward'**
  String get pairCodeLabel;

  /// No description provided for @pairCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}'**
  String pairCodeHint(String example);

  /// No description provided for @pairButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get pairButton;

  /// No description provided for @pairSuccess.
  ///
  /// In en, this message translates to:
  /// **'{alias} is now connected'**
  String pairSuccess(String alias);

  /// No description provided for @pairFailed.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t work. Please check it with the ward.'**
  String get pairFailed;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get navLog;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get navPassport;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @dayOfCycle.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of cycle {cycle}'**
  String dayOfCycle(int day, String cycle);

  /// No description provided for @todayMedicines.
  ///
  /// In en, this message translates to:
  /// **'Today\'s medicines'**
  String get todayMedicines;

  /// No description provided for @medicinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines against feeling sick, from your Passport'**
  String get medicinesSubtitle;

  /// No description provided for @noMedicinesToday.
  ///
  /// In en, this message translates to:
  /// **'No sickness medicines planned for today.'**
  String get noMedicinesToday;

  /// No description provided for @planRunsDays.
  ///
  /// In en, this message translates to:
  /// **'The plan covers days {days}.'**
  String planRunsDays(String days);

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @given.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get given;

  /// No description provided for @markGiven.
  ///
  /// In en, this message translates to:
  /// **'Tick when given'**
  String get markGiven;

  /// No description provided for @howFeelingTeen.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get howFeelingTeen;

  /// No description provided for @howFeelingParent.
  ///
  /// In en, this message translates to:
  /// **'How is {alias} feeling?'**
  String howFeelingParent(String alias);

  /// No description provided for @logSickTeen.
  ///
  /// In en, this message translates to:
  /// **'I feel sick'**
  String get logSickTeen;

  /// No description provided for @logVomitedTeen.
  ///
  /// In en, this message translates to:
  /// **'I vomited'**
  String get logVomitedTeen;

  /// No description provided for @logSickParent.
  ///
  /// In en, this message translates to:
  /// **'Feeling sick'**
  String get logSickParent;

  /// No description provided for @logVomitedParent.
  ///
  /// In en, this message translates to:
  /// **'Vomited'**
  String get logVomitedParent;

  /// No description provided for @oneTapHint.
  ///
  /// In en, this message translates to:
  /// **'One tap is enough. The care team sees every log.'**
  String get oneTapHint;

  /// No description provided for @severityTitle.
  ///
  /// In en, this message translates to:
  /// **'How bad is it?'**
  String get severityTitle;

  /// No description provided for @severityOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional — already saved when you close this.'**
  String get severityOptional;

  /// No description provided for @severity1.
  ///
  /// In en, this message translates to:
  /// **'A little'**
  String get severity1;

  /// No description provided for @severity2.
  ///
  /// In en, this message translates to:
  /// **'Some'**
  String get severity2;

  /// No description provided for @severity3.
  ///
  /// In en, this message translates to:
  /// **'Quite bad'**
  String get severity3;

  /// No description provided for @severity4.
  ///
  /// In en, this message translates to:
  /// **'Bad'**
  String get severity4;

  /// No description provided for @severity5.
  ///
  /// In en, this message translates to:
  /// **'Very bad'**
  String get severity5;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @savingIn.
  ///
  /// In en, this message translates to:
  /// **'Saving in {seconds} s'**
  String savingIn(int seconds);

  /// No description provided for @loggedAt.
  ///
  /// In en, this message translates to:
  /// **'Logged at {time} — the care team will see this'**
  String loggedAt(String time);

  /// No description provided for @savedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on phone, will send when online'**
  String get savedOffline;

  /// No description provided for @pendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 log waiting to send} other{{count} logs waiting to send}}'**
  String pendingCount(int count);

  /// No description provided for @sendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sendNow;

  /// No description provided for @loggedToday.
  ///
  /// In en, this message translates to:
  /// **'Logged today'**
  String get loggedToday;

  /// No description provided for @nothingLoggedToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged today.'**
  String get nothingLoggedToday;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet. When your child feels sick, tap Log.'**
  String get historyEmpty;

  /// No description provided for @dayN.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String dayN(int day);

  /// No description provided for @nausea.
  ///
  /// In en, this message translates to:
  /// **'Feeling sick'**
  String get nausea;

  /// No description provided for @vomiting.
  ///
  /// In en, this message translates to:
  /// **'Vomited'**
  String get vomiting;

  /// No description provided for @severityShort.
  ///
  /// In en, this message translates to:
  /// **'{value}/5'**
  String severityShort(int value);

  /// No description provided for @waitingToSend.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get waitingToSend;

  /// No description provided for @loggedByYou.
  ///
  /// In en, this message translates to:
  /// **'by you'**
  String get loggedByYou;

  /// No description provided for @loggedByCareTeam.
  ///
  /// In en, this message translates to:
  /// **'by the care team'**
  String get loggedByCareTeam;

  /// No description provided for @loggedByFamily.
  ///
  /// In en, this message translates to:
  /// **'by family'**
  String get loggedByFamily;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine schedule'**
  String get scheduleTitle;

  /// No description provided for @warningSignsTitle.
  ///
  /// In en, this message translates to:
  /// **'Call the ward if…'**
  String get warningSignsTitle;

  /// No description provided for @callWard.
  ///
  /// In en, this message translates to:
  /// **'Call the ward'**
  String get callWard;

  /// No description provided for @resourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Good to read'**
  String get resourcesTitle;

  /// No description provided for @noResources.
  ///
  /// In en, this message translates to:
  /// **'No extra reading in this language yet.'**
  String get noResources;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @numberCopied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get numberCopied;

  /// No description provided for @signedOffYes.
  ///
  /// In en, this message translates to:
  /// **'Checked by the care team'**
  String get signedOffYes;

  /// No description provided for @signedOffNo.
  ///
  /// In en, this message translates to:
  /// **'Not yet checked by the care team. Ask the ward before following this plan.'**
  String get signedOffNo;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Connect another child'**
  String get addChild;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while loading.'**
  String get errorLoading;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String ageYears(int age);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @pairingCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairingCodeLabel;

  /// No description provided for @showDay.
  ///
  /// In en, this message translates to:
  /// **'Show day'**
  String get showDay;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @perDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs per day of the cycle'**
  String get perDayTitle;

  /// No description provided for @sentToCareTeam.
  ///
  /// In en, this message translates to:
  /// **'The care team sees these logs and uses them to plan the next cycle.'**
  String get sentToCareTeam;
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
      <String>['en', 'fr', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
