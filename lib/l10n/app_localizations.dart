import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
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
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get settings;

  /// No description provided for @lastPayments.
  ///
  /// In de, this message translates to:
  /// **'Letzte Zahlungen'**
  String get lastPayments;

  /// No description provided for @showMore.
  ///
  /// In de, this message translates to:
  /// **'Weitere Anzeigen'**
  String get showMore;

  /// No description provided for @noPayments.
  ///
  /// In de, this message translates to:
  /// **'Keine getätigten Zahlungen'**
  String get noPayments;

  /// No description provided for @scan.
  ///
  /// In de, this message translates to:
  /// **'Scannen'**
  String get scan;

  /// No description provided for @openWallet.
  ///
  /// In de, this message translates to:
  /// **'Wallet öffnen'**
  String get openWallet;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @verifyIdentity.
  ///
  /// In de, this message translates to:
  /// **'Bitte verifizieren Sie Ihre Identität'**
  String get verifyIdentity;

  /// No description provided for @localizedReason.
  ///
  /// In de, this message translates to:
  /// **'Zum Öffnen des Wallets ist Ihre Authentifizierung nötig'**
  String get localizedReason;

  /// No description provided for @sellCredentialTitle.
  ///
  /// In de, this message translates to:
  /// **'Nachweis verkaufen'**
  String get sellCredentialTitle;

  /// No description provided for @forSale.
  ///
  /// In de, this message translates to:
  /// **'zum Kauf anbieten'**
  String get forSale;

  /// No description provided for @forShow.
  ///
  /// In de, this message translates to:
  /// **'zum Vorzeigen anbieten'**
  String get forShow;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @deletionNote1.
  ///
  /// In de, this message translates to:
  /// **'Sind Sie sicher, dass Sie diesen Nachweis löschen möchten?'**
  String get deletionNote1;

  /// No description provided for @deletionNote2.
  ///
  /// In de, this message translates to:
  /// **'Dieser Vorgang kann nicht rückgängig gemacht werden.'**
  String get deletionNote2;

  /// No description provided for @deletionNoteApp.
  ///
  /// In de, this message translates to:
  /// **'Sind Sie sicher, dass Sie diese Anwendung löschen möchten?'**
  String get deletionNoteApp;

  /// No description provided for @issuer.
  ///
  /// In de, this message translates to:
  /// **'Aussteller'**
  String get issuer;

  /// No description provided for @otherData.
  ///
  /// In de, this message translates to:
  /// **'Sonstige Daten'**
  String get otherData;

  /// No description provided for @personnelData.
  ///
  /// In de, this message translates to:
  /// **'Persönliche Daten'**
  String get personnelData;

  /// No description provided for @invoice.
  ///
  /// In de, this message translates to:
  /// **'Rechnung'**
  String get invoice;

  /// No description provided for @invoiceNumber.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsnummer'**
  String get invoiceNumber;

  /// No description provided for @selfIssued.
  ///
  /// In de, this message translates to:
  /// **'Selbstausgestellt'**
  String get selfIssued;

  /// No description provided for @verifiedBy.
  ///
  /// In de, this message translates to:
  /// **'verifiziert von: '**
  String get verifiedBy;

  /// No description provided for @verified.
  ///
  /// In de, this message translates to:
  /// **'verifiziert'**
  String get verified;

  /// No description provided for @notVerified.
  ///
  /// In de, this message translates to:
  /// **'nicht verfiziert'**
  String get notVerified;

  /// No description provided for @state.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get state;

  /// No description provided for @valid.
  ///
  /// In de, this message translates to:
  /// **'Gültig'**
  String get valid;

  /// No description provided for @expired.
  ///
  /// In de, this message translates to:
  /// **'Abgelaufen'**
  String get expired;

  /// No description provided for @inactive.
  ///
  /// In de, this message translates to:
  /// **'Inaktiv'**
  String get inactive;

  /// No description provided for @revoked.
  ///
  /// In de, this message translates to:
  /// **'Zurückgezogen'**
  String get revoked;

  /// No description provided for @unknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get unknown;

  /// No description provided for @issuanceDate.
  ///
  /// In de, this message translates to:
  /// **'Ausstelldatum'**
  String get issuanceDate;

  /// No description provided for @expirationDate.
  ///
  /// In de, this message translates to:
  /// **'Ablaufdatum'**
  String get expirationDate;

  /// No description provided for @history.
  ///
  /// In de, this message translates to:
  /// **'Aktivitäten'**
  String get history;

  /// No description provided for @issued.
  ///
  /// In de, this message translates to:
  /// **'Ausgestellt'**
  String get issued;

  /// No description provided for @presented.
  ///
  /// In de, this message translates to:
  /// **'Vorgezeigt'**
  String get presented;

  /// No description provided for @presentedError.
  ///
  /// In de, this message translates to:
  /// **'Vorzeigen fehlgeschlagen'**
  String get presentedError;

  /// No description provided for @presentCredential.
  ///
  /// In de, this message translates to:
  /// **'Nachweis vorzeigen'**
  String get presentCredential;

  /// No description provided for @contextCredentialTitle.
  ///
  /// In de, this message translates to:
  /// **'Kontext hinzufügen'**
  String get contextCredentialTitle;

  /// No description provided for @create.
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get create;

  /// No description provided for @credentialPageTitle.
  ///
  /// In de, this message translates to:
  /// **'Meine Nachweise'**
  String get credentialPageTitle;

  /// No description provided for @show.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get show;

  /// No description provided for @preview.
  ///
  /// In de, this message translates to:
  /// **'Vorschau'**
  String get preview;

  /// No description provided for @anonymousIssuer.
  ///
  /// In de, this message translates to:
  /// **'Anonymer Aussteller'**
  String get anonymousIssuer;

  /// No description provided for @anonymous.
  ///
  /// In de, this message translates to:
  /// **'anonym'**
  String get anonymous;

  /// No description provided for @total.
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get total;

  /// No description provided for @payments.
  ///
  /// In de, this message translates to:
  /// **'Zahlung{count, plural, =0{} other{en}}'**
  String payments(num count);

  /// No description provided for @paymentMethod.
  ///
  /// In de, this message translates to:
  /// **'Zahlungsmethode'**
  String get paymentMethod;

  /// No description provided for @noteShownCredentials.
  ///
  /// In de, this message translates to:
  /// **'Diese Nachweise wurden soeben vorgezeigt'**
  String get noteShownCredentials;

  /// No description provided for @noteOtherShowCredentials.
  ///
  /// In de, this message translates to:
  /// **'Ihr Gegenüber bietet Ihnen an, einen Nachweis mit folgenden Daten vorzuzeigen:'**
  String get noteOtherShowCredentials;

  /// No description provided for @request.
  ///
  /// In de, this message translates to:
  /// **'Anfragen'**
  String get request;

  /// No description provided for @requestTitle.
  ///
  /// In de, this message translates to:
  /// **'Anfrage'**
  String get requestTitle;

  /// No description provided for @ignore.
  ///
  /// In de, this message translates to:
  /// **'Ignorieren'**
  String get ignore;

  /// No description provided for @dataFor.
  ///
  /// In de, this message translates to:
  /// **'Die Daten werden übermittelt an:'**
  String get dataFor;

  /// No description provided for @reasonForRequest.
  ///
  /// In de, this message translates to:
  /// **'Grund der Anfrage'**
  String get reasonForRequest;

  /// No description provided for @selfIssueAllowed.
  ///
  /// In de, this message translates to:
  /// **'Der Anfragende erlaubt, Daten selbst einzutragen'**
  String get selfIssueAllowed;

  /// No description provided for @enterData.
  ///
  /// In de, this message translates to:
  /// **'Daten eintragen'**
  String get enterData;

  /// No description provided for @presentationSuccessful.
  ///
  /// In de, this message translates to:
  /// **'Nachweise erfolgreich vorgezeigt'**
  String get presentationSuccessful;

  /// No description provided for @presentationFailed.
  ///
  /// In de, this message translates to:
  /// **'Nachweise konnten nicht vorgezeigt werden'**
  String get presentationFailed;

  /// No description provided for @reject.
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get reject;

  /// No description provided for @send.
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get send;

  /// No description provided for @sendPresentation.
  ///
  /// In de, this message translates to:
  /// **'Nachweise senden'**
  String get sendPresentation;

  /// No description provided for @username.
  ///
  /// In de, this message translates to:
  /// **'Nutzername im gewählten Netzwerk'**
  String get username;

  /// No description provided for @mailAddress.
  ///
  /// In de, this message translates to:
  /// **'E-Mail Adresse'**
  String get mailAddress;

  /// No description provided for @selfIssuable.
  ///
  /// In de, this message translates to:
  /// **'Selbstausstellbare Nachweise'**
  String get selfIssuable;

  /// No description provided for @deviceInformation.
  ///
  /// In de, this message translates to:
  /// **'Geräteinformationen'**
  String get deviceInformation;

  /// No description provided for @stored.
  ///
  /// In de, this message translates to:
  /// **'Nachweis gespeichert'**
  String get stored;

  /// No description provided for @selfIssuance.
  ///
  /// In de, this message translates to:
  /// **'Selbstausstellung'**
  String get selfIssuance;

  /// No description provided for @noCredentialsTitle.
  ///
  /// In de, this message translates to:
  /// **'Fehlerhafte Anfrage'**
  String get noCredentialsTitle;

  /// No description provided for @noCredentialsNote.
  ///
  /// In de, this message translates to:
  /// **' Sie haben soeben eine Anfrage erhalten, die nicht verarbeitet werden kann. Entweder werden Funktionen verlangt, die Ihre Anwendung aktuell noch nicht unterstützt oder Ihr Gegenüber hat bei der Erstellung einen Fehler begangen.'**
  String get noCredentialsNote;

  /// No description provided for @paymentSuccessful.
  ///
  /// In de, this message translates to:
  /// **'Zahlung erfolgreich'**
  String get paymentSuccessful;

  /// No description provided for @paymentReceived.
  ///
  /// In de, this message translates to:
  /// **'Zahlung eingegangen'**
  String get paymentReceived;

  /// No description provided for @paymentFailed.
  ///
  /// In de, this message translates to:
  /// **'Zahlung fehlgeschlagen'**
  String get paymentFailed;

  /// No description provided for @paymentFailedNote.
  ///
  /// In de, this message translates to:
  /// **'Zahlung konnte nicht durchgeführt werden'**
  String get paymentFailedNote;

  /// No description provided for @noPaymentMethod.
  ///
  /// In de, this message translates to:
  /// **'Zahlung nicht möglich'**
  String get noPaymentMethod;

  /// No description provided for @requestPayment.
  ///
  /// In de, this message translates to:
  /// **'Zahlung anfordern'**
  String get requestPayment;

  /// No description provided for @noPaymentNote.
  ///
  /// In de, this message translates to:
  /// **'Keine passende Zahlungsmethode gefunden'**
  String get noPaymentNote;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In de, this message translates to:
  /// **'Lightning Account auswählen'**
  String get selectPaymentMethod;

  /// No description provided for @chargeMoney.
  ///
  /// In de, this message translates to:
  /// **'Aufladen'**
  String get chargeMoney;

  /// No description provided for @noPaymentMethodNote.
  ///
  /// In de, this message translates to:
  /// **'Sie besitzen keine Geldbörse. \nBitte legen Sie sich eine an und\nsorgen für ausreichend Deckung'**
  String get noPaymentMethodNote;

  /// No description provided for @credentialReceived.
  ///
  /// In de, this message translates to:
  /// **'Nachweis empfangen'**
  String get credentialReceived;

  /// No description provided for @amountSatoshi.
  ///
  /// In de, this message translates to:
  /// **'Betrag in Satoshi'**
  String get amountSatoshi;

  /// No description provided for @amountEuro.
  ///
  /// In de, this message translates to:
  /// **'Betrag in Euro'**
  String get amountEuro;

  /// No description provided for @pay.
  ///
  /// In de, this message translates to:
  /// **'Bezahlen'**
  String get pay;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get back;

  /// No description provided for @receive.
  ///
  /// In de, this message translates to:
  /// **'Empfangen'**
  String get receive;

  /// No description provided for @orderWithPayment.
  ///
  /// In de, this message translates to:
  /// **'Zahlungspflichtig bestellen'**
  String get orderWithPayment;

  /// No description provided for @credentialOffer.
  ///
  /// In de, this message translates to:
  /// **'Nachweis-Angebot'**
  String get credentialOffer;

  /// No description provided for @balance.
  ///
  /// In de, this message translates to:
  /// **'Kontostand'**
  String get balance;

  /// No description provided for @noteGetInformation.
  ///
  /// In de, this message translates to:
  /// **'möchte folgende Informationen von Ihnen'**
  String get noteGetInformation;

  /// No description provided for @notePresentationPurpose.
  ///
  /// In de, this message translates to:
  /// **'gibt an, die Daten für folgendes zu verwenden'**
  String get notePresentationPurpose;

  /// No description provided for @missingDataTitle.
  ///
  /// In de, this message translates to:
  /// **'Fehlende Daten'**
  String get missingDataTitle;

  /// No description provided for @missingDataNote.
  ///
  /// In de, this message translates to:
  /// **'Der Anfragende bittet um eine Selbstauskunft. Bitte tragen Sie die geforderten Daten ein.'**
  String get missingDataNote;

  /// No description provided for @downloadFailed.
  ///
  /// In de, this message translates to:
  /// **'Download fehlgeschlagen'**
  String get downloadFailed;

  /// No description provided for @downloadFailedExplanation.
  ///
  /// In de, this message translates to:
  /// **'Die Anfrage des Gegenübers kann nicht herunterladen werden.'**
  String get downloadFailedExplanation;

  /// No description provided for @unexpectedMessage.
  ///
  /// In de, this message translates to:
  /// **'Unerwartete Nachricht'**
  String get unexpectedMessage;

  /// No description provided for @malformedMessage.
  ///
  /// In de, this message translates to:
  /// **'Fehlerhafte Nachricht'**
  String get malformedMessage;

  /// No description provided for @malformedOOBExplanation.
  ///
  /// In de, this message translates to:
  /// **'Die Nachricht kann nicht gelesen werden.\n Sie können versuchen, den QR-Code ein weiteres mal zu scannen. \n Sollte der Fehler bestehen bleiben, kontaktieren Sie den Support des Anfrage-Erstellers.'**
  String get malformedOOBExplanation;

  /// No description provided for @unknownMessageExplanation.
  ///
  /// In de, this message translates to:
  /// **'Diese Nachricht wird derzeit nicht unterstützt.\n Die Interaktion kann daher nicht fortgesetzt werden.'**
  String get unknownMessageExplanation;

  /// No description provided for @malformedEncryptedMessage.
  ///
  /// In de, this message translates to:
  /// **'Beim Entschlüsseln einer Nachricht ist ein Fehler aufgetreten.'**
  String get malformedEncryptedMessage;

  /// No description provided for @waiting.
  ///
  /// In de, this message translates to:
  /// **'Einen kleinen Moment bitte.'**
  String get waiting;

  /// No description provided for @waitingSendPresentation.
  ///
  /// In de, this message translates to:
  /// **'Ihre Antwort wird gesendet.'**
  String get waitingSendPresentation;

  /// No description provided for @waitingQrData.
  ///
  /// In de, this message translates to:
  /// **'Die Daten werden verarbeitet.'**
  String get waitingQrData;

  /// No description provided for @errorNotEnoughCredentials.
  ///
  /// In de, this message translates to:
  /// **'Sie können die Anfrage ihres Gegenübers nicht erfüllen, da Sie nicht die nötigen Nachweise besitzen.\nInformieren Sie sich, wie Sie die fehlenden Nachweise erlangen können.'**
  String get errorNotEnoughCredentials;

  /// No description provided for @errorNotEnoughSelected.
  ///
  /// In de, this message translates to:
  /// **'Sie haben nicht genügend Nachweise ausgewählt, um die Anfrage zu beantworten. \nBitte wählen Sie die nötigen Nachweise.'**
  String get errorNotEnoughSelected;

  /// No description provided for @attention.
  ///
  /// In de, this message translates to:
  /// **'Achtung'**
  String get attention;

  /// No description provided for @cancelWarning.
  ///
  /// In de, this message translates to:
  /// **'Zum Beenden \'Abbrechen\' verwenden'**
  String get cancelWarning;

  /// No description provided for @accept.
  ///
  /// In de, this message translates to:
  /// **'Annehmen'**
  String get accept;

  /// No description provided for @noteNoCredentials.
  ///
  /// In de, this message translates to:
  /// **'Keine Nachweise vorhanden'**
  String get noteNoCredentials;

  /// No description provided for @allCredentials.
  ///
  /// In de, this message translates to:
  /// **'Alle Nachweise'**
  String get allCredentials;

  /// No description provided for @sendFailed.
  ///
  /// In de, this message translates to:
  /// **'Es gibt ein Problem'**
  String get sendFailed;

  /// No description provided for @sendFailedNote.
  ///
  /// In de, this message translates to:
  /// **'Der Vorgang kann nicht beendet werden. Bitte probieren Sie es erneut.'**
  String get sendFailedNote;

  /// No description provided for @wrongCredential.
  ///
  /// In de, this message translates to:
  /// **'Fehlerhafter Nachweis'**
  String get wrongCredential;

  /// No description provided for @wrongCredentialNote.
  ///
  /// In de, this message translates to:
  /// **'Ihr Gegenüber hat einen Nachweis ausgestellt, der eine fehlerhafte Signatur trägt. \nTeilen Sie ihm dies mit.'**
  String get wrongCredentialNote;

  /// No description provided for @wrongCredentialNote2.
  ///
  /// In de, this message translates to:
  /// **'Ihr Gegenüber hat einen Nachweis ausgestellt, der nicht für Sie bestimmt ist'**
  String get wrongCredentialNote2;

  /// No description provided for @familyName.
  ///
  /// In de, this message translates to:
  /// **'Nachname'**
  String get familyName;

  /// No description provided for @givenName.
  ///
  /// In de, this message translates to:
  /// **'Vorname'**
  String get givenName;

  /// No description provided for @birthDate.
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum'**
  String get birthDate;

  /// No description provided for @countryName.
  ///
  /// In de, this message translates to:
  /// **'Staat'**
  String get countryName;

  /// No description provided for @stateOrProvinceName.
  ///
  /// In de, this message translates to:
  /// **'(Bundes)land'**
  String get stateOrProvinceName;

  /// No description provided for @localityName.
  ///
  /// In de, this message translates to:
  /// **'Stadt'**
  String get localityName;

  /// No description provided for @organizationName.
  ///
  /// In de, this message translates to:
  /// **'Organisation'**
  String get organizationName;

  /// No description provided for @commonName.
  ///
  /// In de, this message translates to:
  /// **'Allgemeiner Name'**
  String get commonName;

  /// No description provided for @loadIssuerData.
  ///
  /// In de, this message translates to:
  /// **'Lade Informationen'**
  String get loadIssuerData;

  /// No description provided for @errorOpen.
  ///
  /// In de, this message translates to:
  /// **'Das Wallet kann nicht geöffnet werden.\nIst auf Ihrem Gerät ein Sicherheitsmechanismus (Pin, Passwort, Muster, Fingerabdruck,...) hinterlegt?\nWenn nicht, sichern Sie Ihr Gerät über Ihre Geräteeinstellungen.'**
  String get errorOpen;

  /// No description provided for @credential.
  ///
  /// In de, this message translates to:
  /// **'Nachweis'**
  String get credential;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @hashNotMatch.
  ///
  /// In de, this message translates to:
  /// **'Hash stimmt nicht überein'**
  String get hashNotMatch;

  /// No description provided for @hashNotMatchNote.
  ///
  /// In de, this message translates to:
  /// **'Dies kann ein Betrugsversuch sein,\ndaher wird die Zahlung abgebrochen.'**
  String get hashNotMatchNote;

  /// No description provided for @otherValue.
  ///
  /// In de, this message translates to:
  /// **'Anderer Betrag'**
  String get otherValue;

  /// No description provided for @otherValueNote.
  ///
  /// In de, this message translates to:
  /// **'Der Betrag stimmt nicht mit dem von Ihnen angeforderten überein.\nDie Zahlung wird abgebrochen.'**
  String get otherValueNote;

  /// No description provided for @copy.
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get copy;

  /// No description provided for @copyNote.
  ///
  /// In de, this message translates to:
  /// **'Invoice wurde in die Zwischenablage kopiert.'**
  String get copyNote;

  /// No description provided for @enterAmount.
  ///
  /// In de, this message translates to:
  /// **'Betrag eingeben'**
  String get enterAmount;

  /// No description provided for @description.
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get description;

  /// No description provided for @favorites.
  ///
  /// In de, this message translates to:
  /// **'Favoriten'**
  String get favorites;

  /// No description provided for @amount.
  ///
  /// In de, this message translates to:
  /// **'Betrag'**
  String get amount;

  /// No description provided for @termsOfService.
  ///
  /// In de, this message translates to:
  /// **'AGBs und Datenschutzbestimmungen'**
  String get termsOfService;

  /// No description provided for @termsOfServiceNote.
  ///
  /// In de, this message translates to:
  /// **'Ausgewählte Kontexte haben zusätzliche Nutzungsbedingungen. Bitte lesen Sie diese sorgfälltig durch und wählen die aus, denen Sie zustimmen. Kontexte, deren Nutzungsbedingungen Sie nicht zustimmen, werden nicht hinzugefügt.'**
  String get termsOfServiceNote;

  /// No description provided for @termsOfServiceButton.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen wie ausgewählt'**
  String get termsOfServiceButton;

  /// No description provided for @termsOfServiceNote1.
  ///
  /// In de, this message translates to:
  /// **'Ich habe die AGBs und Datenschutzbestimmungen unter '**
  String get termsOfServiceNote1;

  /// No description provided for @termsOfServiceNote2.
  ///
  /// In de, this message translates to:
  /// **' gelesen und akzeptiere diese.'**
  String get termsOfServiceNote2;

  /// No description provided for @pleaseAccept.
  ///
  /// In de, this message translates to:
  /// **'Bitte stimmen Sie unseren AGBs und Datenschutzbestimmungen zu.'**
  String get pleaseAccept;

  /// No description provided for @addNewApp.
  ///
  /// In de, this message translates to:
  /// **'Füge einen neuen Kontext hinzu'**
  String get addNewApp;

  /// No description provided for @invoiceLimit.
  ///
  /// In de, this message translates to:
  /// **'Aus Sicherheitsgründen darf dein Kontostand umgerechnet nicht mehr als 10€ betragen. Die Invoice überschreitet diesen Betrag.'**
  String get invoiceLimit;

  /// No description provided for @creationFailed.
  ///
  /// In de, this message translates to:
  /// **'Erstellen Fehlgeschlagen'**
  String get creationFailed;

  /// No description provided for @license.
  ///
  /// In de, this message translates to:
  /// **'Lizenzen'**
  String get license;

  /// No description provided for @welcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei Hidy'**
  String get welcome;

  /// No description provided for @welcomeNote.
  ///
  /// In de, this message translates to:
  /// **'Bevor Ihnen ihre persönliche Wallet zur Verfügung steht, müssen noch ein paar Dinge geklärt werden.'**
  String get welcomeNote;

  /// No description provided for @technic.
  ///
  /// In de, this message translates to:
  /// **'Technische Vorraussetzungen'**
  String get technic;

  /// No description provided for @technicNoteOk.
  ///
  /// In de, this message translates to:
  /// **'Ihr Smartphone ist mit Pin, Muster, Passwort oder Biometrie geschützt.'**
  String get technicNoteOk;

  /// No description provided for @technicNoteBad.
  ///
  /// In de, this message translates to:
  /// **'Ihr Smartphone ist nicht mit Pin, Muster, Passwort oder Biometrie geschützt.'**
  String get technicNoteBad;

  /// No description provided for @noteGoToSettings.
  ///
  /// In de, this message translates to:
  /// **'Bitte schützen Sie ihr Gerät in den System-Einstellungen.'**
  String get noteGoToSettings;

  /// No description provided for @openSettings.
  ///
  /// In de, this message translates to:
  /// **'System-Einstellungen öffnen'**
  String get openSettings;

  /// No description provided for @recheck.
  ///
  /// In de, this message translates to:
  /// **'Erneut prüfen'**
  String get recheck;

  /// No description provided for @start.
  ///
  /// In de, this message translates to:
  /// **'Los geht\'s'**
  String get start;

  /// No description provided for @favoriteExplanation.
  ///
  /// In de, this message translates to:
  /// **'Füge einen Kontext zu deiner Favoriten-Liste hinzu, indem Du den Stern auf der Karte berührst.'**
  String get favoriteExplanation;

  /// No description provided for @addCardExplanation.
  ///
  /// In de, this message translates to:
  /// **'Fügen Sie eine Karte durch Scannen Ihres QR- oder Strichcodes hinzu'**
  String get addCardExplanation;

  /// No description provided for @importSuccess.
  ///
  /// In de, this message translates to:
  /// **'{passType} erfolgreich importiert'**
  String importSuccess(String passType);

  /// No description provided for @importFailed.
  ///
  /// In de, this message translates to:
  /// **'Import fehlgeschlagen'**
  String get importFailed;

  /// No description provided for @saveError.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern'**
  String get saveError;

  /// No description provided for @saveErrorNote.
  ///
  /// In de, this message translates to:
  /// **'Speichern des Nachweises nicht möglich.\nBitte wiederholen Sie den Vorgang.'**
  String get saveErrorNote;

  /// No description provided for @paymentInformation.
  ///
  /// In de, this message translates to:
  /// **'Zahlungsinformation'**
  String get paymentInformation;

  /// No description provided for @paymentInformationDetail.
  ///
  /// In de, this message translates to:
  /// **'Für die Weiterverarbeitung der Daten fallen folgende Kosten an: '**
  String get paymentInformationDetail;

  /// No description provided for @funding1.
  ///
  /// In de, this message translates to:
  /// **'Für das Freigeben Ihrer Daten werden Ihnen'**
  String get funding1;

  /// No description provided for @funding2.
  ///
  /// In de, this message translates to:
  /// **'gutgeschrieben'**
  String get funding2;

  /// No description provided for @oidcTan.
  ///
  /// In de, this message translates to:
  /// **'Vorgangsnummer'**
  String get oidcTan;

  /// No description provided for @oidcTanInfo.
  ///
  /// In de, this message translates to:
  /// **'Der Aussteller hat Ihnen für diesen Vorgang eine Vorgangsnummer übermittelt. Bitte tragen Sie diese hier ein.'**
  String get oidcTanInfo;

  /// No description provided for @noAppNote.
  ///
  /// In de, this message translates to:
  /// **'Sie haben noch keine Anwendungen hinzugefügt'**
  String get noAppNote;

  /// No description provided for @newAppTitle.
  ///
  /// In de, this message translates to:
  /// **'Neue Anwendungen'**
  String get newAppTitle;

  /// No description provided for @newAppNote.
  ///
  /// In de, this message translates to:
  /// **'Keine Anwendungen gefunden'**
  String get newAppNote;

  /// No description provided for @unknownQrCode.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Qr-Code'**
  String get unknownQrCode;

  /// No description provided for @unknownQrCodeNote.
  ///
  /// In de, this message translates to:
  /// **'Der gescannte Qr-Code enthält Daten, die nicht verarbeitet werden können.'**
  String get unknownQrCodeNote;

  /// No description provided for @subscribe.
  ///
  /// In de, this message translates to:
  /// **'Abonieren'**
  String get subscribe;

  /// No description provided for @sendSatoshi.
  ///
  /// In de, this message translates to:
  /// **'Satoshi senden'**
  String get sendSatoshi;

  /// No description provided for @backgroundPresentation.
  ///
  /// In de, this message translates to:
  /// **'Hintergrundabfragen'**
  String get backgroundPresentation;

  /// No description provided for @backgroundPresentationNote.
  ///
  /// In de, this message translates to:
  /// **'Hiermit erlaube ich {otherParty}, diesen Nachweis zukünftig ohne meine explizite Zustimmung abzufragen'**
  String backgroundPresentationNote(String otherParty);

  /// No description provided for @finishProcess.
  ///
  /// In de, this message translates to:
  /// **'Prozess abgeschlossen'**
  String get finishProcess;

  /// No description provided for @finishProcessNote.
  ///
  /// In de, this message translates to:
  /// **'Dieser Nachweis wurde bereits an Sie ausgestellt'**
  String get finishProcessNote;

  /// No description provided for @authFailed.
  ///
  /// In de, this message translates to:
  /// **'Authentifizierung fehlgeschlagen'**
  String get authFailed;

  /// No description provided for @credentialDownloadFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Nachweis kann nicht heruntergeladen werden'**
  String get credentialDownloadFailed;

  /// No description provided for @issuanceInfoNotFound.
  ///
  /// In de, this message translates to:
  /// **'Wir haben leider nicht herausgefunden, wie Sie sich die fehlenden Nachweise besorgen können.'**
  String get issuanceInfoNotFound;

  /// No description provided for @issuanceInfoFound.
  ///
  /// In de, this message translates to:
  /// **'Hier kannst Du Dir die fehlenden Nachweise besorgen:'**
  String get issuanceInfoFound;

  /// No description provided for @hsmwEmployeeCard.
  ///
  /// In de, this message translates to:
  /// **'Mitarbeiterausweis (HSMW)'**
  String get hsmwEmployeeCard;

  /// No description provided for @hsmwStudentCard.
  ///
  /// In de, this message translates to:
  /// **'Studierendenausweis (HSMW)'**
  String get hsmwStudentCard;

  /// No description provided for @pictureProcess.
  ///
  /// In de, this message translates to:
  /// **'Ihr Bild wird erstellt'**
  String get pictureProcess;

  /// No description provided for @pictureProcessNote.
  ///
  /// In de, this message translates to:
  /// **'Bitte haben Sie einen Moment Geduld'**
  String get pictureProcessNote;

  /// No description provided for @prepareWallet.
  ///
  /// In de, this message translates to:
  /// **'Ihr persönliches Wallet wird geladen'**
  String get prepareWallet;

  /// No description provided for @yes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get no;

  /// No description provided for @restore.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get restore;

  /// No description provided for @restoreMenu.
  ///
  /// In de, this message translates to:
  /// **'Backup Wiederherstellen'**
  String get restoreMenu;

  /// No description provided for @restoreQuestion.
  ///
  /// In de, this message translates to:
  /// **'Beim Wiederherstellen werden alle bisherigen Daten überschrieben. Sind Sie sich sicher, dass Sie ein Backup einlesen wollen?'**
  String get restoreQuestion;

  /// No description provided for @restoreMnemonic.
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie die Wortfolge ein, die Ihnen beim Erstellen eines Backups angezeigt wurde:'**
  String get restoreMnemonic;

  /// No description provided for @restoreSuccess.
  ///
  /// In de, this message translates to:
  /// **'Backup erfolgrech wiederhergestellt'**
  String get restoreSuccess;

  /// No description provided for @backup.
  ///
  /// In de, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @backupUpload.
  ///
  /// In de, this message translates to:
  /// **'Ihr Backup wird erstellt'**
  String get backupUpload;

  /// No description provided for @backupSuccess.
  ///
  /// In de, this message translates to:
  /// **'Backup abgeschlossen'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In de, this message translates to:
  /// **'Backup fehlgeschlagen'**
  String get backupFailed;

  /// No description provided for @backupFailedNote.
  ///
  /// In de, this message translates to:
  /// **'Bitte versuchen Sie es erneut'**
  String get backupFailedNote;

  /// No description provided for @backupWriteDownPassword.
  ///
  /// In de, this message translates to:
  /// **'Bitte notieren Sie sich diese Wortfolge! Ohne diese Wörter kann ihr Backup nicht wiederhergestellt werden!'**
  String get backupWriteDownPassword;

  /// No description provided for @backupNotFound.
  ///
  /// In de, this message translates to:
  /// **'Kein passendes Backup gefunden! Falsche Wortfolge?'**
  String get backupNotFound;

  /// No description provided for @noteNotInBackup.
  ///
  /// In de, this message translates to:
  /// **'Folgende Nachweise können aus technischen Gründen nicht gesichert werden, da ein späteres Wiederherstellen nicht möglich ist:'**
  String get noteNotInBackup;

  /// No description provided for @backupRestoreError.
  ///
  /// In de, this message translates to:
  /// **'Es ist ein Fehler aufgetreten'**
  String get backupRestoreError;

  /// No description provided for @backupRestoreErrorNote.
  ///
  /// In de, this message translates to:
  /// **'Bitte versuchen Sie es erneut'**
  String get backupRestoreErrorNote;

  /// No description provided for @askContinue.
  ///
  /// In de, this message translates to:
  /// **'Möchten Sie fortfahren?'**
  String get askContinue;

  /// No description provided for @note.
  ///
  /// In de, this message translates to:
  /// **'Hinweis'**
  String get note;

  /// No description provided for @oidMetadataError.
  ///
  /// In de, this message translates to:
  /// **'Fehlerhafte Metadaten'**
  String get oidMetadataError;

  /// No description provided for @oidMetadataErrorNote.
  ///
  /// In de, this message translates to:
  /// **'Wichtige Informationen über den Aussteller oder den angefragten Nachweis können nicht gefunden werden oder sind fehlerhaft'**
  String get oidMetadataErrorNote;

  /// No description provided for @unknownAuthServer.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Aussteller'**
  String get unknownAuthServer;

  /// No description provided for @oidAuthFailed.
  ///
  /// In de, this message translates to:
  /// **'Autorisierung fehlgeschlagen'**
  String get oidAuthFailed;

  /// No description provided for @oidAuthFailedNote.
  ///
  /// In de, this message translates to:
  /// **'Das Ausstellen ihres Nachweises ist nicht möglich, da die dafür nötige Autorisierung fehlgeschalgen ist.\nBitte versuchen Sie es später erneut.'**
  String get oidAuthFailedNote;

  /// No description provided for @authorization.
  ///
  /// In de, this message translates to:
  /// **'Autorisierung'**
  String get authorization;

  /// No description provided for @loadRequest.
  ///
  /// In de, this message translates to:
  /// **'Anfrage wird geladen'**
  String get loadRequest;

  /// No description provided for @continueWithPin.
  ///
  /// In de, this message translates to:
  /// **'Weiter zur PIN-Eingabe'**
  String get continueWithPin;

  /// No description provided for @identify.
  ///
  /// In de, this message translates to:
  /// **'Ausweisen'**
  String get identify;

  /// No description provided for @requestedData.
  ///
  /// In de, this message translates to:
  /// **'Angefragte Daten:'**
  String get requestedData;

  /// No description provided for @providerInfo.
  ///
  /// In de, this message translates to:
  /// **'Anbieterinformationen'**
  String get providerInfo;

  /// No description provided for @reason.
  ///
  /// In de, this message translates to:
  /// **'Grund der Anfrage'**
  String get reason;

  /// No description provided for @validity.
  ///
  /// In de, this message translates to:
  /// **'Gültigkeit'**
  String get validity;

  /// No description provided for @certificateIssuer.
  ///
  /// In de, this message translates to:
  /// **'Aussteller des Berechtigungszertifikats'**
  String get certificateIssuer;

  /// No description provided for @provider.
  ///
  /// In de, this message translates to:
  /// **'Anfragender'**
  String get provider;

  /// No description provided for @insertCard.
  ///
  /// In de, this message translates to:
  /// **'Bitte halten Sie ihren Ausweis an die NFC-Schnittstelle ihres Gerätes. Diese befindet sich meistens an der Rückseite des Gerätes.'**
  String get insertCard;

  /// No description provided for @readCard.
  ///
  /// In de, this message translates to:
  /// **'Ausweis lesen'**
  String get readCard;

  /// No description provided for @processFailed.
  ///
  /// In de, this message translates to:
  /// **'Vorgang fehlgeschlagen'**
  String get processFailed;

  /// No description provided for @enterPuk.
  ///
  /// In de, this message translates to:
  /// **'PUK-Eingabe'**
  String get enterPuk;

  /// No description provided for @enterPukNote.
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie die 10-stellige PUK des Ausweises ein:'**
  String get enterPukNote;

  /// No description provided for @pukLengthNote.
  ///
  /// In de, this message translates to:
  /// **'Die PUK muss genau 10 Stellen haben'**
  String get pukLengthNote;

  /// No description provided for @enterPin.
  ///
  /// In de, this message translates to:
  /// **'PIN-Eingabe'**
  String get enterPin;

  /// No description provided for @enterPinNote.
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie die 6-stellige PIN des Ausweises ein:'**
  String get enterPinNote;

  /// No description provided for @pinLengthNote.
  ///
  /// In de, this message translates to:
  /// **'Die PIN muss genau 6 Stellen haben'**
  String get pinLengthNote;

  /// No description provided for @remainingTry.
  ///
  /// In de, this message translates to:
  /// **'Verbleibende Versuche'**
  String get remainingTry;

  /// No description provided for @retryNote2.
  ///
  /// In de, this message translates to:
  /// **'Sollten Sie auch bei diesem Versuch eine falsche PIN eingeben, muss vor dem letzten Versuch die CAN eingegeben werden. Das ist die 6-stellige Zahlenfolge auf der Vorderseite des Ausweises.'**
  String get retryNote2;

  /// No description provided for @retryNote1.
  ///
  /// In de, this message translates to:
  /// **'Das ist Ihr letzter Versuch, eine korrekte PIN einzugeben. Sollte auch dieser fehlschlagen, wird die Online-Ausweis-Funktion gesperrt.'**
  String get retryNote1;

  /// No description provided for @note5digit.
  ///
  /// In de, this message translates to:
  /// **'Sie haben nur eine 5-stellige PIN? Dann brechen Sie den Vorgang bitte ab und nutzen Sie die Funktion \"PIN ändern\" der offiziellen Ausweis-App.'**
  String get note5digit;

  /// No description provided for @enterCan.
  ///
  /// In de, this message translates to:
  /// **'CAN-Eingabe'**
  String get enterCan;

  /// No description provided for @enterCanNote.
  ///
  /// In de, this message translates to:
  /// **'Bitte geben Sie die 6-stellige CAN von der Vorderseite des Ausweises ein:'**
  String get enterCanNote;

  /// No description provided for @canLengthNote.
  ///
  /// In de, this message translates to:
  /// **'Die CAN muss genau 6 Stellen haben'**
  String get canLengthNote;

  /// No description provided for @storeAsCredential.
  ///
  /// In de, this message translates to:
  /// **'Als Nachweis speichern'**
  String get storeAsCredential;

  /// No description provided for @cardData.
  ///
  /// In de, this message translates to:
  /// **'Ausweisdaten'**
  String get cardData;

  /// No description provided for @address.
  ///
  /// In de, this message translates to:
  /// **'Adresse'**
  String get address;

  /// No description provided for @birthName.
  ///
  /// In de, this message translates to:
  /// **'Geburtsname'**
  String get birthName;

  /// No description provided for @birthPlace.
  ///
  /// In de, this message translates to:
  /// **'Geburtsort'**
  String get birthPlace;

  /// No description provided for @doctoralDegree.
  ///
  /// In de, this message translates to:
  /// **'Doktorgrad'**
  String get doctoralDegree;

  /// No description provided for @artisticName.
  ///
  /// In de, this message translates to:
  /// **'Künstlername'**
  String get artisticName;

  /// No description provided for @nationality.
  ///
  /// In de, this message translates to:
  /// **'Staatsangehörigkeit'**
  String get nationality;

  /// No description provided for @issuingCountry.
  ///
  /// In de, this message translates to:
  /// **'Aussteller-Land'**
  String get issuingCountry;

  /// No description provided for @documentType.
  ///
  /// In de, this message translates to:
  /// **'Dokumententyp'**
  String get documentType;

  /// No description provided for @residencePermit1.
  ///
  /// In de, this message translates to:
  /// **'Aufenthaltserlaubnis 1'**
  String get residencePermit1;

  /// No description provided for @residencePermit2.
  ///
  /// In de, this message translates to:
  /// **'Aufenthaltserlaubnis 2'**
  String get residencePermit2;

  /// No description provided for @communityId.
  ///
  /// In de, this message translates to:
  /// **'Wohnort-ID'**
  String get communityId;

  /// No description provided for @addressVerification.
  ///
  /// In de, this message translates to:
  /// **'Adress-Verifikation'**
  String get addressVerification;

  /// No description provided for @ageVerification.
  ///
  /// In de, this message translates to:
  /// **'Altersverifikation'**
  String get ageVerification;

  /// No description provided for @bleOff.
  ///
  /// In de, this message translates to:
  /// **'Bluetooth ist nicht aktiv. Bitte aktivieren Sie es.'**
  String get bleOff;

  /// No description provided for @bleTransmissionStart.
  ///
  /// In de, this message translates to:
  /// **'Vorbereitung'**
  String get bleTransmissionStart;

  /// No description provided for @bleTransmissionPrepare.
  ///
  /// In de, this message translates to:
  /// **'Daten werden erstellt'**
  String get bleTransmissionPrepare;

  /// No description provided for @bleTransmissionConnected.
  ///
  /// In de, this message translates to:
  /// **'Erfolgreich verbunden. Warte auf Anfrage'**
  String get bleTransmissionConnected;

  /// No description provided for @bleTransmissionSend.
  ///
  /// In de, this message translates to:
  /// **'Daten gesendet'**
  String get bleTransmissionSend;

  /// No description provided for @bleTransmissionFinished.
  ///
  /// In de, this message translates to:
  /// **'Übertragung beendet und Verbindung getrennt'**
  String get bleTransmissionFinished;

  /// No description provided for @bleButton.
  ///
  /// In de, this message translates to:
  /// **'Neustart'**
  String get bleButton;

  /// No description provided for @bleError.
  ///
  /// In de, this message translates to:
  /// **'Es ist ein Fehler aufgetreten. Bitte starten Sie den Vorgang mittels des Buttons neu.\nSollten Sie diese Meldung zum wiederholten Mal sehen, versuchen Sie Bluetooth aus und wieder an zu schalten oder Hidy neu zu starten'**
  String get bleError;

  /// No description provided for @biometricPromptTitle.
  ///
  /// In de, this message translates to:
  /// **'Signaturerstellung'**
  String get biometricPromptTitle;

  /// No description provided for @biometricPromptSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Bitte authentifizieren Sie sich für die Nutzung Ihres Schlüssels'**
  String get biometricPromptSubtitle;

  /// No description provided for @verifiedMail.
  ///
  /// In de, this message translates to:
  /// **'Bereits verifizierte E-Mail-Adressen:'**
  String get verifiedMail;

  /// No description provided for @noMailAddress.
  ///
  /// In de, this message translates to:
  /// **'Sie haben noch keine E-Mail-Adressen hinterlegt'**
  String get noMailAddress;

  /// No description provided for @newMailAddress.
  ///
  /// In de, this message translates to:
  /// **'Neue E-Mail Adresse hinzufügen'**
  String get newMailAddress;

  /// No description provided for @deleteMail.
  ///
  /// In de, this message translates to:
  /// **'Sind Sie sicher, dass Sie diese E-Mail-Adresse löschen möchten?'**
  String get deleteMail;

  /// No description provided for @sendMailFailed.
  ///
  /// In de, this message translates to:
  /// **'Senden der E-Mail fehlgeschlagen'**
  String get sendMailFailed;

  /// No description provided for @checkMails.
  ///
  /// In de, this message translates to:
  /// **'Bitte überprüfen Sie Ihr E-Mail Postfach'**
  String get checkMails;

  /// No description provided for @sendSuccess.
  ///
  /// In de, this message translates to:
  /// **'Senden Erfolgreich'**
  String get sendSuccess;

  /// No description provided for @finish.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get finish;

  /// No description provided for @frontside.
  ///
  /// In de, this message translates to:
  /// **'Vorderseite'**
  String get frontside;

  /// No description provided for @backside.
  ///
  /// In de, this message translates to:
  /// **'Rückseite'**
  String get backside;

  /// No description provided for @failedLoad.
  ///
  /// In de, this message translates to:
  /// **'Laden fehlgeschlagen'**
  String get failedLoad;

  /// No description provided for @failedLoadNote.
  ///
  /// In de, this message translates to:
  /// **'Die Anwendung kann nicht geöffnet werden. Kann es sein, dass ihr Gerät keine Internetverbindung hat?'**
  String get failedLoadNote;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
