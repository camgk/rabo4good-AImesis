// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AImesis';

  @override
  String get forFamilies => 'Pour les familles';

  @override
  String get welcomeIntro =>
      'Notez d\'un seul geste comment se sent votre enfant et gardez le plan des médicaments à portée de main.';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get demoAccounts => 'Comptes de démo';

  @override
  String demoPasswordHint(String password) {
    return 'Mot de passe de démo : $password';
  }

  @override
  String get clinicianNotAllowed =>
      'Cette application est destinée aux familles ; l\'équipe soignante utilise l\'application web AImesis.';

  @override
  String get loginFailed =>
      'Connexion impossible. Vérifiez votre e-mail et votre mot de passe.';

  @override
  String get networkError =>
      'Pas de connexion à AImesis. Vérifiez votre connexion Internet et réessayez.';

  @override
  String get language => 'Langue';

  @override
  String get roleParent => 'Parent';

  @override
  String get rolePatient => 'Ado';

  @override
  String get pairTitle => 'Associer votre enfant';

  @override
  String get pairIntro =>
      'Tapez le code reçu du service. Vous le trouverez sur le Passeport.';

  @override
  String get pairCodeLabel => 'Code du service';

  @override
  String pairCodeHint(String example) {
    return 'p. ex. $example';
  }

  @override
  String get pairButton => 'Associer';

  @override
  String pairSuccess(String alias) {
    return '$alias est maintenant associé(e)';
  }

  @override
  String get pairFailed =>
      'Ce code ne fonctionne pas. Vérifiez-le auprès du service.';

  @override
  String get navToday => 'Aujourd\'hui';

  @override
  String get navLog => 'Noter';

  @override
  String get navHistory => 'Historique';

  @override
  String get navPassport => 'Passeport';

  @override
  String get settings => 'Réglages';

  @override
  String dayOfCycle(int day, String cycle) {
    return 'Jour $day de la cure $cycle';
  }

  @override
  String get todayMedicines => 'Médicaments du jour';

  @override
  String get medicinesSubtitle =>
      'Médicaments contre les nausées, selon votre Passeport';

  @override
  String get noMedicinesToday =>
      'Aucun médicament contre les nausées prévu aujourd\'hui.';

  @override
  String planRunsDays(String days) {
    return 'Le plan couvre les jours $days.';
  }

  @override
  String get next => 'Suivant';

  @override
  String get given => 'Donné';

  @override
  String get markGiven => 'Cocher une fois donné';

  @override
  String get howFeelingTeen => 'Comment te sens-tu ?';

  @override
  String howFeelingParent(String alias) {
    return 'Comment se sent $alias ?';
  }

  @override
  String get logSickTeen => 'J\'ai la nausée';

  @override
  String get logVomitedTeen => 'J\'ai vomi';

  @override
  String get logSickParent => 'Nausée';

  @override
  String get logVomitedParent => 'A vomi';

  @override
  String get oneTapHint =>
      'Un seul geste suffit. L\'équipe soignante voit chaque note.';

  @override
  String get severityTitle => 'C\'est grave comment ?';

  @override
  String get severityOptional =>
      'Facultatif — c\'est enregistré dès que vous fermez.';

  @override
  String get severity1 => 'Un peu';

  @override
  String get severity2 => 'Un peu plus';

  @override
  String get severity3 => 'Assez fort';

  @override
  String get severity4 => 'Fort';

  @override
  String get severity5 => 'Très fort';

  @override
  String get skip => 'Passer';

  @override
  String savingIn(int seconds) {
    return 'Enregistrement dans $seconds s';
  }

  @override
  String loggedAt(String time) {
    return 'Noté à $time — l\'équipe soignante le verra';
  }

  @override
  String get savedOffline =>
      'Enregistré sur le téléphone, sera envoyé dès que possible';

  @override
  String pendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes en attente d\'envoi',
      one: '1 note en attente d\'envoi',
    );
    return '$_temp0';
  }

  @override
  String get sendNow => 'Envoyer';

  @override
  String get loggedToday => 'Noté aujourd\'hui';

  @override
  String get nothingLoggedToday => 'Rien de noté aujourd\'hui.';

  @override
  String get historyEmpty =>
      'Pas encore de notes. Si votre enfant a la nausée, appuyez sur Noter.';

  @override
  String dayN(int day) {
    return 'Jour $day';
  }

  @override
  String get nausea => 'Nausée';

  @override
  String get vomiting => 'Vomissement';

  @override
  String severityShort(int value) {
    return '$value/5';
  }

  @override
  String get waitingToSend => 'En attente d\'envoi';

  @override
  String get loggedByYou => 'par vous';

  @override
  String get loggedByCareTeam => 'par l\'équipe soignante';

  @override
  String get loggedByFamily => 'par la famille';

  @override
  String get scheduleTitle => 'Horaire des médicaments';

  @override
  String get warningSignsTitle => 'Appelez le service si…';

  @override
  String get callWard => 'Appeler le service';

  @override
  String get resourcesTitle => 'Bon à lire';

  @override
  String get noResources => 'Pas encore d\'infos dans cette langue.';

  @override
  String get openLink => 'Ouvrir';

  @override
  String get linkCopied => 'Lien copié';

  @override
  String get numberCopied => 'Numéro copié';

  @override
  String get signedOffYes => 'Vérifié par l\'équipe soignante';

  @override
  String get signedOffNo =>
      'Pas encore vérifié par l\'équipe soignante. Demandez au service avant de suivre ce plan.';

  @override
  String get account => 'Compte';

  @override
  String get child => 'Enfant';

  @override
  String get addChild => 'Associer un autre enfant';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get retry => 'Réessayer';

  @override
  String get errorLoading => 'Un problème est survenu lors du chargement.';

  @override
  String get chooseLanguage => 'Choisissez votre langue';

  @override
  String get server => 'Serveur';

  @override
  String ageYears(int age) {
    return '$age ans';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get pairingCodeLabel => 'Code d\'association';

  @override
  String get showDay => 'Voir le jour';

  @override
  String get today => 'aujourd\'hui';

  @override
  String get perDayTitle => 'Notes par jour de la cure';

  @override
  String get sentToCareTeam =>
      'L\'équipe soignante voit ces notes et s\'en sert pour préparer la prochaine cure.';
}
