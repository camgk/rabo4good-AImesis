// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'AImesis';

  @override
  String get forFamilies => 'Voor gezinnen';

  @override
  String get welcomeIntro =>
      'Noteer met één tik hoe je kind zich voelt en heb het medicijnschema altijd bij de hand.';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Wachtwoord';

  @override
  String get signIn => 'Aanmelden';

  @override
  String get demoAccounts => 'Demo-accounts';

  @override
  String demoPasswordHint(String password) {
    return 'Demo-wachtwoord: $password';
  }

  @override
  String get clinicianNotAllowed =>
      'Deze app is voor gezinnen; het zorgteam gebruikt de AImesis-webapp.';

  @override
  String get loginFailed =>
      'Aanmelden lukt niet. Controleer je e-mail en wachtwoord.';

  @override
  String get networkError =>
      'Geen verbinding met AImesis. Controleer je internet en probeer opnieuw.';

  @override
  String get language => 'Taal';

  @override
  String get roleParent => 'Ouder';

  @override
  String get rolePatient => 'Tiener';

  @override
  String get pairTitle => 'Je kind koppelen';

  @override
  String get pairIntro =>
      'Typ de code die je van de afdeling kreeg. Je vindt hem op het Paspoort.';

  @override
  String get pairCodeLabel => 'Code van de afdeling';

  @override
  String pairCodeHint(String example) {
    return 'bv. $example';
  }

  @override
  String get pairButton => 'Koppelen';

  @override
  String pairSuccess(String alias) {
    return '$alias is nu gekoppeld';
  }

  @override
  String get pairFailed =>
      'Die code werkt niet. Controleer hem met de afdeling.';

  @override
  String get navToday => 'Vandaag';

  @override
  String get navLog => 'Noteren';

  @override
  String get navHistory => 'Verloop';

  @override
  String get navPassport => 'Paspoort';

  @override
  String get settings => 'Instellingen';

  @override
  String dayOfCycle(int day, String cycle) {
    return 'Dag $day van kuur $cycle';
  }

  @override
  String get todayMedicines => 'Medicijnen van vandaag';

  @override
  String get medicinesSubtitle =>
      'Medicijnen tegen misselijkheid, uit je Paspoort';

  @override
  String get noMedicinesToday =>
      'Vandaag staan er geen medicijnen tegen misselijkheid gepland.';

  @override
  String planRunsDays(String days) {
    return 'Het schema loopt op dag $days.';
  }

  @override
  String get next => 'Volgende';

  @override
  String get given => 'Gegeven';

  @override
  String get markGiven => 'Aanvinken als gegeven';

  @override
  String get howFeelingTeen => 'Hoe voel je je?';

  @override
  String howFeelingParent(String alias) {
    return 'Hoe voelt $alias zich?';
  }

  @override
  String get logSickTeen => 'Ik ben misselijk';

  @override
  String get logVomitedTeen => 'Ik heb overgegeven';

  @override
  String get logSickParent => 'Misselijk';

  @override
  String get logVomitedParent => 'Overgegeven';

  @override
  String get oneTapHint => 'Eén tik is genoeg. Het zorgteam ziet elke melding.';

  @override
  String get severityTitle => 'Hoe erg is het?';

  @override
  String get severityOptional =>
      'Niet verplicht — wordt bewaard als je dit sluit.';

  @override
  String get severity1 => 'Een beetje';

  @override
  String get severity2 => 'Wat';

  @override
  String get severity3 => 'Best erg';

  @override
  String get severity4 => 'Erg';

  @override
  String get severity5 => 'Heel erg';

  @override
  String get skip => 'Overslaan';

  @override
  String savingIn(int seconds) {
    return 'Bewaren over $seconds s';
  }

  @override
  String loggedAt(String time) {
    return 'Genoteerd om $time — het zorgteam ziet dit';
  }

  @override
  String get savedOffline =>
      'Bewaard op de telefoon, wordt verstuurd zodra er internet is';

  @override
  String pendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meldingen wachten om verstuurd te worden',
      one: '1 melding wacht om verstuurd te worden',
    );
    return '$_temp0';
  }

  @override
  String get sendNow => 'Nu versturen';

  @override
  String get loggedToday => 'Vandaag genoteerd';

  @override
  String get nothingLoggedToday => 'Vandaag nog niets genoteerd.';

  @override
  String get historyEmpty =>
      'Nog geen meldingen. Is je kind misselijk? Tik op Noteren.';

  @override
  String dayN(int day) {
    return 'Dag $day';
  }

  @override
  String get nausea => 'Misselijk';

  @override
  String get vomiting => 'Overgegeven';

  @override
  String severityShort(int value) {
    return '$value/5';
  }

  @override
  String get waitingToSend => 'Wacht om te versturen';

  @override
  String get loggedByYou => 'door jou';

  @override
  String get loggedByCareTeam => 'door het zorgteam';

  @override
  String get loggedByFamily => 'door het gezin';

  @override
  String get scheduleTitle => 'Medicijnschema';

  @override
  String get warningSignsTitle => 'Bel de afdeling als…';

  @override
  String get callWard => 'Bel de afdeling';

  @override
  String get resourcesTitle => 'Goed om te lezen';

  @override
  String get noResources => 'Nog geen extra info in deze taal.';

  @override
  String get openLink => 'Openen';

  @override
  String get linkCopied => 'Link gekopieerd';

  @override
  String get numberCopied => 'Nummer gekopieerd';

  @override
  String get signedOffYes => 'Nagekeken door het zorgteam';

  @override
  String get signedOffNo =>
      'Nog niet nagekeken door het zorgteam. Vraag het eerst aan de afdeling.';

  @override
  String get account => 'Account';

  @override
  String get child => 'Kind';

  @override
  String get addChild => 'Nog een kind koppelen';

  @override
  String get logOut => 'Afmelden';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get errorLoading => 'Er ging iets mis bij het laden.';

  @override
  String get chooseLanguage => 'Kies je taal';

  @override
  String get server => 'Server';

  @override
  String ageYears(int age) {
    return '$age jaar';
  }

  @override
  String get cancel => 'Annuleren';

  @override
  String get close => 'Sluiten';

  @override
  String get pairingCodeLabel => 'Koppelcode';

  @override
  String get showDay => 'Toon dag';

  @override
  String get today => 'vandaag';

  @override
  String get perDayTitle => 'Meldingen per dag van de kuur';

  @override
  String get sentToCareTeam =>
      'Het zorgteam ziet deze meldingen en gebruikt ze voor de volgende kuur.';
}
