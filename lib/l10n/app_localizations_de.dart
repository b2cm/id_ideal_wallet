// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settings => 'Über';

  @override
  String get lastPayments => 'Letzte Zahlungen';

  @override
  String get showMore => 'Weitere Anzeigen';

  @override
  String get noPayments => 'Keine getätigten Zahlungen';

  @override
  String get scan => 'Scannen';

  @override
  String get openWallet => 'Wallet öffnen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get ok => 'OK';

  @override
  String get verifyIdentity => 'Bitte verifizieren Sie Ihre Identität';

  @override
  String get localizedReason =>
      'Zum Öffnen des Wallets ist Ihre Authentifizierung nötig';

  @override
  String get sellCredentialTitle => 'Nachweis verkaufen';

  @override
  String get forSale => 'zum Kauf anbieten';

  @override
  String get forShow => 'zum Vorzeigen anbieten';

  @override
  String get delete => 'Löschen';

  @override
  String get deletionNote1 =>
      'Sind Sie sicher, dass Sie diesen Nachweis löschen möchten?';

  @override
  String get deletionNote2 =>
      'Dieser Vorgang kann nicht rückgängig gemacht werden.';

  @override
  String get deletionNoteApp =>
      'Sind Sie sicher, dass Sie diese Anwendung löschen möchten?';

  @override
  String get issuer => 'Aussteller';

  @override
  String get otherData => 'Sonstige Daten';

  @override
  String get personnelData => 'Persönliche Daten';

  @override
  String get invoice => 'Rechnung';

  @override
  String get invoiceNumber => 'Rechnungsnummer';

  @override
  String get selfIssued => 'Selbstausgestellt';

  @override
  String get verifiedBy => 'verifiziert von: ';

  @override
  String get verified => 'verifiziert';

  @override
  String get notVerified => 'nicht verfiziert';

  @override
  String get state => 'Status';

  @override
  String get valid => 'Gültig';

  @override
  String get expired => 'Abgelaufen';

  @override
  String get inactive => 'Inaktiv';

  @override
  String get revoked => 'Zurückgezogen';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get issuanceDate => 'Ausstelldatum';

  @override
  String get expirationDate => 'Ablaufdatum';

  @override
  String get history => 'Aktivitäten';

  @override
  String get issued => 'Ausgestellt';

  @override
  String get presented => 'Vorgezeigt';

  @override
  String get presentedError => 'Vorzeigen fehlgeschlagen';

  @override
  String get presentCredential => 'Nachweis vorzeigen';

  @override
  String get contextCredentialTitle => 'Kontext hinzufügen';

  @override
  String get create => 'Anlegen';

  @override
  String get credentialPageTitle => 'Meine Nachweise';

  @override
  String get show => 'Anzeigen';

  @override
  String get preview => 'Vorschau';

  @override
  String get anonymousIssuer => 'Anonymer Aussteller';

  @override
  String get anonymous => 'anonym';

  @override
  String get total => 'Gesamt';

  @override
  String payments(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en',
      zero: '',
    );
    return 'Zahlung$_temp0';
  }

  @override
  String get paymentMethod => 'Zahlungsmethode';

  @override
  String get noteShownCredentials => 'Diese Nachweise wurden soeben vorgezeigt';

  @override
  String get noteOtherShowCredentials =>
      'Ihr Gegenüber bietet Ihnen an, einen Nachweis mit folgenden Daten vorzuzeigen:';

  @override
  String get request => 'Anfragen';

  @override
  String get requestTitle => 'Anfrage';

  @override
  String get ignore => 'Ignorieren';

  @override
  String get dataFor => 'Die Daten werden übermittelt an:';

  @override
  String get reasonForRequest => 'Grund der Anfrage';

  @override
  String get selfIssueAllowed =>
      'Der Anfragende erlaubt, Daten selbst einzutragen';

  @override
  String get enterData => 'Daten eintragen';

  @override
  String get presentationSuccessful => 'Nachweise erfolgreich vorgezeigt';

  @override
  String get presentationFailed => 'Nachweise konnten nicht vorgezeigt werden';

  @override
  String get reject => 'Ablehnen';

  @override
  String get send => 'Senden';

  @override
  String get sendPresentation => 'Nachweise senden';

  @override
  String get username => 'Nutzername im gewählten Netzwerk';

  @override
  String get mailAddress => 'E-Mail Adresse';

  @override
  String get selfIssuable => 'Selbstausstellbare Nachweise';

  @override
  String get deviceInformation => 'Geräteinformationen';

  @override
  String get stored => 'Nachweis gespeichert';

  @override
  String get selfIssuance => 'Selbstausstellung';

  @override
  String get noCredentialsTitle => 'Fehlerhafte Anfrage';

  @override
  String get noCredentialsNote =>
      ' Sie haben soeben eine Anfrage erhalten, die nicht verarbeitet werden kann. Entweder werden Funktionen verlangt, die Ihre Anwendung aktuell noch nicht unterstützt oder Ihr Gegenüber hat bei der Erstellung einen Fehler begangen.';

  @override
  String get paymentSuccessful => 'Zahlung erfolgreich';

  @override
  String get paymentReceived => 'Zahlung eingegangen';

  @override
  String get paymentFailed => 'Zahlung fehlgeschlagen';

  @override
  String get paymentFailedNote => 'Zahlung konnte nicht durchgeführt werden';

  @override
  String get noPaymentMethod => 'Zahlung nicht möglich';

  @override
  String get requestPayment => 'Zahlung anfordern';

  @override
  String get noPaymentNote => 'Keine passende Zahlungsmethode gefunden';

  @override
  String get selectPaymentMethod => 'Lightning Account auswählen';

  @override
  String get chargeMoney => 'Aufladen';

  @override
  String get noPaymentMethodNote =>
      'Sie besitzen keine Geldbörse. \nBitte legen Sie sich eine an und\nsorgen für ausreichend Deckung';

  @override
  String get credentialReceived => 'Nachweis empfangen';

  @override
  String get amountSatoshi => 'Betrag in Satoshi';

  @override
  String get amountEuro => 'Betrag in Euro';

  @override
  String get pay => 'Bezahlen';

  @override
  String get back => 'Zurück';

  @override
  String get receive => 'Empfangen';

  @override
  String get orderWithPayment => 'Zahlungspflichtig bestellen';

  @override
  String get credentialOffer => 'Nachweis-Angebot';

  @override
  String get balance => 'Kontostand';

  @override
  String get noteGetInformation => 'möchte folgende Informationen von Ihnen';

  @override
  String get notePresentationPurpose =>
      'gibt an, die Daten für folgendes zu verwenden';

  @override
  String get missingDataTitle => 'Fehlende Daten';

  @override
  String get missingDataNote =>
      'Der Anfragende bittet um eine Selbstauskunft. Bitte tragen Sie die geforderten Daten ein.';

  @override
  String get downloadFailed => 'Download fehlgeschlagen';

  @override
  String get downloadFailedExplanation =>
      'Die Anfrage des Gegenübers kann nicht herunterladen werden.';

  @override
  String get unexpectedMessage => 'Unerwartete Nachricht';

  @override
  String get malformedMessage => 'Fehlerhafte Nachricht';

  @override
  String get malformedOOBExplanation =>
      'Die Nachricht kann nicht gelesen werden.\n Sie können versuchen, den QR-Code ein weiteres mal zu scannen. \n Sollte der Fehler bestehen bleiben, kontaktieren Sie den Support des Anfrage-Erstellers.';

  @override
  String get unknownMessageExplanation =>
      'Diese Nachricht wird derzeit nicht unterstützt.\n Die Interaktion kann daher nicht fortgesetzt werden.';

  @override
  String get malformedEncryptedMessage =>
      'Beim Entschlüsseln einer Nachricht ist ein Fehler aufgetreten.';

  @override
  String get waiting => 'Einen kleinen Moment bitte.';

  @override
  String get waitingSendPresentation => 'Ihre Antwort wird gesendet.';

  @override
  String get waitingQrData => 'Die Daten werden verarbeitet.';

  @override
  String get errorNotEnoughCredentials =>
      'Sie können die Anfrage ihres Gegenübers nicht erfüllen, da Sie nicht die nötigen Nachweise besitzen.\nInformieren Sie sich, wie Sie die fehlenden Nachweise erlangen können.';

  @override
  String get errorNotEnoughSelected =>
      'Sie haben nicht genügend Nachweise ausgewählt, um die Anfrage zu beantworten. \nBitte wählen Sie die nötigen Nachweise.';

  @override
  String get attention => 'Achtung';

  @override
  String get cancelWarning => 'Zum Beenden \'Abbrechen\' verwenden';

  @override
  String get accept => 'Annehmen';

  @override
  String get noteNoCredentials => 'Keine Nachweise vorhanden';

  @override
  String get allCredentials => 'Alle Nachweise';

  @override
  String get sendFailed => 'Es gibt ein Problem';

  @override
  String get sendFailedNote =>
      'Der Vorgang kann nicht beendet werden. Bitte probieren Sie es erneut.';

  @override
  String get wrongCredential => 'Fehlerhafter Nachweis';

  @override
  String get wrongCredentialNote =>
      'Ihr Gegenüber hat einen Nachweis ausgestellt, der eine fehlerhafte Signatur trägt. \nTeilen Sie ihm dies mit.';

  @override
  String get wrongCredentialNote2 =>
      'Ihr Gegenüber hat einen Nachweis ausgestellt, der nicht für Sie bestimmt ist';

  @override
  String get familyName => 'Nachname';

  @override
  String get givenName => 'Vorname';

  @override
  String get birthDate => 'Geburtsdatum';

  @override
  String get countryName => 'Staat';

  @override
  String get stateOrProvinceName => '(Bundes)land';

  @override
  String get localityName => 'Stadt';

  @override
  String get organizationName => 'Organisation';

  @override
  String get commonName => 'Allgemeiner Name';

  @override
  String get loadIssuerData => 'Lade Informationen';

  @override
  String get errorOpen =>
      'Das Wallet kann nicht geöffnet werden.\nIst auf Ihrem Gerät ein Sicherheitsmechanismus (Pin, Passwort, Muster, Fingerabdruck,...) hinterlegt?\nWenn nicht, sichern Sie Ihr Gerät über Ihre Geräteeinstellungen.';

  @override
  String get credential => 'Nachweis';

  @override
  String get add => 'Hinzufügen';

  @override
  String get hashNotMatch => 'Hash stimmt nicht überein';

  @override
  String get hashNotMatchNote =>
      'Dies kann ein Betrugsversuch sein,\ndaher wird die Zahlung abgebrochen.';

  @override
  String get otherValue => 'Anderer Betrag';

  @override
  String get otherValueNote =>
      'Der Betrag stimmt nicht mit dem von Ihnen angeforderten überein.\nDie Zahlung wird abgebrochen.';

  @override
  String get copy => 'Kopieren';

  @override
  String get copyNote => 'Invoice wurde in die Zwischenablage kopiert.';

  @override
  String get enterAmount => 'Betrag eingeben';

  @override
  String get description => 'Beschreibung';

  @override
  String get favorites => 'Favoriten';

  @override
  String get amount => 'Betrag';

  @override
  String get termsOfService => 'AGBs und Datenschutzbestimmungen';

  @override
  String get termsOfServiceNote =>
      'Ausgewählte Kontexte haben zusätzliche Nutzungsbedingungen. Bitte lesen Sie diese sorgfälltig durch und wählen die aus, denen Sie zustimmen. Kontexte, deren Nutzungsbedingungen Sie nicht zustimmen, werden nicht hinzugefügt.';

  @override
  String get termsOfServiceButton => 'Hinzufügen wie ausgewählt';

  @override
  String get termsOfServiceNote1 =>
      'Ich habe die AGBs und Datenschutzbestimmungen unter ';

  @override
  String get termsOfServiceNote2 => ' gelesen und akzeptiere diese.';

  @override
  String get pleaseAccept =>
      'Bitte stimmen Sie unseren AGBs und Datenschutzbestimmungen zu.';

  @override
  String get addNewApp => 'Füge einen neuen Kontext hinzu';

  @override
  String get invoiceLimit =>
      'Aus Sicherheitsgründen darf dein Kontostand umgerechnet nicht mehr als 10€ betragen. Die Invoice überschreitet diesen Betrag.';

  @override
  String get creationFailed => 'Erstellen Fehlgeschlagen';

  @override
  String get license => 'Lizenzen';

  @override
  String get welcome => 'Willkommen bei Hidy';

  @override
  String get welcomeNote =>
      'Bevor Ihnen ihre persönliche Wallet zur Verfügung steht, müssen noch ein paar Dinge geklärt werden.';

  @override
  String get technic => 'Technische Vorraussetzungen';

  @override
  String get technicNoteOk =>
      'Ihr Smartphone ist mit Pin, Muster, Passwort oder Biometrie geschützt.';

  @override
  String get technicNoteBad =>
      'Ihr Smartphone ist nicht mit Pin, Muster, Passwort oder Biometrie geschützt.';

  @override
  String get noteGoToSettings =>
      'Bitte schützen Sie ihr Gerät in den System-Einstellungen.';

  @override
  String get openSettings => 'System-Einstellungen öffnen';

  @override
  String get recheck => 'Erneut prüfen';

  @override
  String get start => 'Los geht\'s';

  @override
  String get favoriteExplanation =>
      'Füge einen Kontext zu deiner Favoriten-Liste hinzu, indem Du den Stern auf der Karte berührst.';

  @override
  String get addCardExplanation =>
      'Fügen Sie eine Karte durch Scannen Ihres QR- oder Strichcodes hinzu';

  @override
  String importSuccess(String passType) {
    return '$passType erfolgreich importiert';
  }

  @override
  String get importFailed => 'Import fehlgeschlagen';

  @override
  String get saveError => 'Fehler beim Speichern';

  @override
  String get saveErrorNote =>
      'Speichern des Nachweises nicht möglich.\nBitte wiederholen Sie den Vorgang.';

  @override
  String get paymentInformation => 'Zahlungsinformation';

  @override
  String get paymentInformationDetail =>
      'Für die Weiterverarbeitung der Daten fallen folgende Kosten an: ';

  @override
  String get funding1 => 'Für das Freigeben Ihrer Daten werden Ihnen';

  @override
  String get funding2 => 'gutgeschrieben';

  @override
  String get oidcTan => 'Vorgangsnummer';

  @override
  String get oidcTanInfo =>
      'Der Aussteller hat Ihnen für diesen Vorgang eine Vorgangsnummer übermittelt. Bitte tragen Sie diese hier ein.';

  @override
  String get noAppNote => 'Sie haben noch keine Anwendungen hinzugefügt';

  @override
  String get newAppTitle => 'Neue Anwendungen';

  @override
  String get newAppNote => 'Keine Anwendungen gefunden';

  @override
  String get unknownQrCode => 'Unbekannter Qr-Code';

  @override
  String get unknownQrCodeNote =>
      'Der gescannte Qr-Code enthält Daten, die nicht verarbeitet werden können.';

  @override
  String get subscribe => 'Abonieren';

  @override
  String get sendSatoshi => 'Satoshi senden';

  @override
  String get backgroundPresentation => 'Hintergrundabfragen';

  @override
  String backgroundPresentationNote(String otherParty) {
    return 'Hiermit erlaube ich $otherParty, diesen Nachweis zukünftig ohne meine explizite Zustimmung abzufragen';
  }

  @override
  String get finishProcess => 'Prozess abgeschlossen';

  @override
  String get finishProcessNote =>
      'Dieser Nachweis wurde bereits an Sie ausgestellt';

  @override
  String get authFailed => 'Authentifizierung fehlgeschlagen';

  @override
  String get credentialDownloadFailed =>
      'Der Nachweis kann nicht heruntergeladen werden';

  @override
  String get issuanceInfoNotFound =>
      'Wir haben leider nicht herausgefunden, wie Sie sich die fehlenden Nachweise besorgen können.';

  @override
  String get issuanceInfoFound =>
      'Hier kannst Du Dir die fehlenden Nachweise besorgen:';

  @override
  String get hsmwEmployeeCard => 'Mitarbeiterausweis (HSMW)';

  @override
  String get hsmwStudentCard => 'Studierendenausweis (HSMW)';

  @override
  String get pictureProcess => 'Ihr Bild wird erstellt';

  @override
  String get pictureProcessNote => 'Bitte haben Sie einen Moment Geduld';

  @override
  String get prepareWallet => 'Ihr persönliches Wallet wird geladen';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get restoreMenu => 'Backup Wiederherstellen';

  @override
  String get restoreQuestion =>
      'Beim Wiederherstellen werden alle bisherigen Daten überschrieben. Sind Sie sich sicher, dass Sie ein Backup einlesen wollen?';

  @override
  String get restoreMnemonic =>
      'Bitte geben Sie die Wortfolge ein, die Ihnen beim Erstellen eines Backups angezeigt wurde:';

  @override
  String get restoreSuccess => 'Backup erfolgrech wiederhergestellt';

  @override
  String get backup => 'Backup';

  @override
  String get backupUpload => 'Ihr Backup wird erstellt';

  @override
  String get backupSuccess => 'Backup abgeschlossen';

  @override
  String get backupFailed => 'Backup fehlgeschlagen';

  @override
  String get backupFailedNote => 'Bitte versuchen Sie es erneut';

  @override
  String get backupWriteDownPassword =>
      'Bitte notieren Sie sich diese Wortfolge! Ohne diese Wörter kann ihr Backup nicht wiederhergestellt werden!';

  @override
  String get backupNotFound =>
      'Kein passendes Backup gefunden! Falsche Wortfolge?';

  @override
  String get noteNotInBackup =>
      'Folgende Nachweise können aus technischen Gründen nicht gesichert werden, da ein späteres Wiederherstellen nicht möglich ist:';

  @override
  String get backupRestoreError => 'Es ist ein Fehler aufgetreten';

  @override
  String get backupRestoreErrorNote => 'Bitte versuchen Sie es erneut';

  @override
  String get askContinue => 'Möchten Sie fortfahren?';

  @override
  String get note => 'Hinweis';

  @override
  String get oidMetadataError => 'Fehlerhafte Metadaten';

  @override
  String get oidMetadataErrorNote =>
      'Wichtige Informationen über den Aussteller oder den angefragten Nachweis können nicht gefunden werden oder sind fehlerhaft';

  @override
  String get unknownAuthServer => 'Unbekannter Aussteller';

  @override
  String get oidAuthFailed => 'Autorisierung fehlgeschlagen';

  @override
  String get oidAuthFailedNote =>
      'Das Ausstellen ihres Nachweises ist nicht möglich, da die dafür nötige Autorisierung fehlgeschalgen ist.\nBitte versuchen Sie es später erneut.';

  @override
  String get authorization => 'Autorisierung';

  @override
  String get loadRequest => 'Anfrage wird geladen';

  @override
  String get continueWithPin => 'Weiter zur PIN-Eingabe';

  @override
  String get identify => 'Ausweisen';

  @override
  String get requestedData => 'Angefragte Daten:';

  @override
  String get providerInfo => 'Anbieterinformationen';

  @override
  String get reason => 'Grund der Anfrage';

  @override
  String get validity => 'Gültigkeit';

  @override
  String get certificateIssuer => 'Aussteller des Berechtigungszertifikats';

  @override
  String get provider => 'Anfragender';

  @override
  String get insertCard =>
      'Bitte halten Sie ihren Ausweis an die NFC-Schnittstelle ihres Gerätes. Diese befindet sich meistens an der Rückseite des Gerätes.';

  @override
  String get readCard => 'Ausweis lesen';

  @override
  String get processFailed => 'Vorgang fehlgeschlagen';

  @override
  String get enterPuk => 'PUK-Eingabe';

  @override
  String get enterPukNote =>
      'Bitte geben Sie die 10-stellige PUK des Ausweises ein:';

  @override
  String get pukLengthNote => 'Die PUK muss genau 10 Stellen haben';

  @override
  String get enterPin => 'PIN-Eingabe';

  @override
  String get enterPinNote =>
      'Bitte geben Sie die 6-stellige PIN des Ausweises ein:';

  @override
  String get pinLengthNote => 'Die PIN muss genau 6 Stellen haben';

  @override
  String get remainingTry => 'Verbleibende Versuche';

  @override
  String get retryNote2 =>
      'Sollten Sie auch bei diesem Versuch eine falsche PIN eingeben, muss vor dem letzten Versuch die CAN eingegeben werden. Das ist die 6-stellige Zahlenfolge auf der Vorderseite des Ausweises.';

  @override
  String get retryNote1 =>
      'Das ist Ihr letzter Versuch, eine korrekte PIN einzugeben. Sollte auch dieser fehlschlagen, wird die Online-Ausweis-Funktion gesperrt.';

  @override
  String get note5digit =>
      'Sie haben nur eine 5-stellige PIN? Dann brechen Sie den Vorgang bitte ab und nutzen Sie die Funktion \"PIN ändern\" der offiziellen Ausweis-App.';

  @override
  String get enterCan => 'CAN-Eingabe';

  @override
  String get enterCanNote =>
      'Bitte geben Sie die 6-stellige CAN von der Vorderseite des Ausweises ein:';

  @override
  String get canLengthNote => 'Die CAN muss genau 6 Stellen haben';

  @override
  String get storeAsCredential => 'Als Nachweis speichern';

  @override
  String get cardData => 'Ausweisdaten';

  @override
  String get address => 'Adresse';

  @override
  String get birthName => 'Geburtsname';

  @override
  String get birthPlace => 'Geburtsort';

  @override
  String get doctoralDegree => 'Doktorgrad';

  @override
  String get artisticName => 'Künstlername';

  @override
  String get nationality => 'Staatsangehörigkeit';

  @override
  String get issuingCountry => 'Aussteller-Land';

  @override
  String get documentType => 'Dokumententyp';

  @override
  String get residencePermit1 => 'Aufenthaltserlaubnis 1';

  @override
  String get residencePermit2 => 'Aufenthaltserlaubnis 2';

  @override
  String get communityId => 'Wohnort-ID';

  @override
  String get addressVerification => 'Adress-Verifikation';

  @override
  String get ageVerification => 'Altersverifikation';

  @override
  String get bleOff => 'Bluetooth ist nicht aktiv. Bitte aktivieren Sie es.';

  @override
  String get bleTransmissionStart => 'Vorbereitung';

  @override
  String get bleTransmissionPrepare => 'Daten werden erstellt';

  @override
  String get bleTransmissionConnected =>
      'Erfolgreich verbunden. Warte auf Anfrage';

  @override
  String get bleTransmissionSend => 'Daten gesendet';

  @override
  String get bleTransmissionFinished =>
      'Übertragung beendet und Verbindung getrennt';

  @override
  String get bleButton => 'Neustart';

  @override
  String get bleError =>
      'Es ist ein Fehler aufgetreten. Bitte starten Sie den Vorgang mittels des Buttons neu.\nSollten Sie diese Meldung zum wiederholten Mal sehen, versuchen Sie Bluetooth aus und wieder an zu schalten oder Hidy neu zu starten';

  @override
  String get biometricPromptTitle => 'Signaturerstellung';

  @override
  String get biometricPromptSubtitle =>
      'Bitte authentifizieren Sie sich für die Nutzung Ihres Schlüssels';

  @override
  String get verifiedMail => 'Bereits verifizierte E-Mail-Adressen:';

  @override
  String get noMailAddress => 'Sie haben noch keine E-Mail-Adressen hinterlegt';

  @override
  String get newMailAddress => 'Neue E-Mail Adresse hinzufügen';

  @override
  String get deleteMail =>
      'Sind Sie sicher, dass Sie diese E-Mail-Adresse löschen möchten?';

  @override
  String get sendMailFailed => 'Senden der E-Mail fehlgeschlagen';

  @override
  String get checkMails => 'Bitte überprüfen Sie Ihr E-Mail Postfach';

  @override
  String get sendSuccess => 'Senden Erfolgreich';

  @override
  String get finish => 'Fertig';

  @override
  String get frontside => 'Vorderseite';

  @override
  String get backside => 'Rückseite';

  @override
  String get failedLoad => 'Laden fehlgeschlagen';

  @override
  String get failedLoadNote =>
      'Die Anwendung kann nicht geöffnet werden. Kann es sein, dass ihr Gerät keine Internetverbindung hat?';
}
