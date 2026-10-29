// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AImesis';

  @override
  String get forFamilies => 'For families';

  @override
  String get welcomeIntro =>
      'Log how your child feels with one tap, and keep the medicine plan close by.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get demoAccounts => 'Demo accounts';

  @override
  String demoPasswordHint(String password) {
    return 'Demo password: $password';
  }

  @override
  String get clinicianNotAllowed =>
      'This app is for families; the care team uses the AImesis web app.';

  @override
  String get loginFailed => 'Could not sign in. Check your email and password.';

  @override
  String get networkError =>
      'No connection to AImesis. Check your internet and try again.';

  @override
  String get language => 'Language';

  @override
  String get demoFooter => 'Demo app — not for medical use';

  @override
  String get roleParent => 'Parent';

  @override
  String get rolePatient => 'Teen';

  @override
  String get pairTitle => 'Connect your child';

  @override
  String get pairIntro =>
      'Type the code you got from the ward. You can find it on the Passport.';

  @override
  String get pairCodeLabel => 'Code from the ward';

  @override
  String pairCodeHint(String example) {
    return 'e.g. $example';
  }

  @override
  String get pairButton => 'Connect';

  @override
  String pairSuccess(String alias) {
    return '$alias is now connected';
  }

  @override
  String get pairFailed =>
      'That code doesn\'t work. Please check it with the ward.';

  @override
  String get navToday => 'Today';

  @override
  String get navLog => 'Log';

  @override
  String get navHistory => 'History';

  @override
  String get navPassport => 'Passport';

  @override
  String get settings => 'Settings';

  @override
  String dayOfCycle(int day, String cycle) {
    return 'Day $day of cycle $cycle';
  }

  @override
  String get todayMedicines => 'Today\'s medicines';

  @override
  String get medicinesSubtitle =>
      'Medicines against feeling sick, from your Passport';

  @override
  String get noMedicinesToday => 'No sickness medicines planned for today.';

  @override
  String planRunsDays(String days) {
    return 'The plan covers days $days.';
  }

  @override
  String get next => 'Next';

  @override
  String get given => 'Given';

  @override
  String get markGiven => 'Tick when given';

  @override
  String get howFeelingTeen => 'How are you feeling?';

  @override
  String howFeelingParent(String alias) {
    return 'How is $alias feeling?';
  }

  @override
  String get logSickTeen => 'I feel sick';

  @override
  String get logVomitedTeen => 'I vomited';

  @override
  String get logSickParent => 'Feeling sick';

  @override
  String get logVomitedParent => 'Vomited';

  @override
  String get oneTapHint => 'One tap is enough. The care team sees every log.';

  @override
  String get severityTitle => 'How bad is it?';

  @override
  String get severityOptional =>
      'Optional — already saved when you close this.';

  @override
  String get severity1 => 'A little';

  @override
  String get severity2 => 'Some';

  @override
  String get severity3 => 'Quite bad';

  @override
  String get severity4 => 'Bad';

  @override
  String get severity5 => 'Very bad';

  @override
  String get skip => 'Skip';

  @override
  String savingIn(int seconds) {
    return 'Saving in $seconds s';
  }

  @override
  String loggedAt(String time) {
    return 'Logged at $time — the care team will see this';
  }

  @override
  String get savedOffline => 'Saved on phone, will send when online';

  @override
  String pendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logs waiting to send',
      one: '1 log waiting to send',
    );
    return '$_temp0';
  }

  @override
  String get sendNow => 'Send now';

  @override
  String get loggedToday => 'Logged today';

  @override
  String get nothingLoggedToday => 'Nothing logged today.';

  @override
  String get historyEmpty =>
      'No logs yet. When your child feels sick, tap Log.';

  @override
  String dayN(int day) {
    return 'Day $day';
  }

  @override
  String get nausea => 'Feeling sick';

  @override
  String get vomiting => 'Vomited';

  @override
  String severityShort(int value) {
    return '$value/5';
  }

  @override
  String get waitingToSend => 'Waiting to send';

  @override
  String get loggedByYou => 'by you';

  @override
  String get loggedByCareTeam => 'by the care team';

  @override
  String get loggedByFamily => 'by family';

  @override
  String get scheduleTitle => 'Medicine schedule';

  @override
  String get warningSignsTitle => 'Call the ward if…';

  @override
  String get callWard => 'Call the ward';

  @override
  String get resourcesTitle => 'Good to read';

  @override
  String get noResources => 'No extra reading in this language yet.';

  @override
  String get openLink => 'Open';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get numberCopied => 'Number copied';

  @override
  String get signedOffYes => 'Checked by the care team';

  @override
  String get signedOffNo =>
      'Not yet checked by the care team. Ask the ward before following this plan.';

  @override
  String get account => 'Account';

  @override
  String get child => 'Child';

  @override
  String get addChild => 'Connect another child';

  @override
  String get logOut => 'Log out';

  @override
  String get retry => 'Try again';

  @override
  String get errorLoading => 'Something went wrong while loading.';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get server => 'Server';

  @override
  String ageYears(int age) {
    return '$age years';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get pairingCodeLabel => 'Pairing code';

  @override
  String get showDay => 'Show day';

  @override
  String get today => 'today';

  @override
  String get perDayTitle => 'Logs per day of the cycle';

  @override
  String get sentToCareTeam =>
      'The care team sees these logs and uses them to plan the next cycle.';
}
