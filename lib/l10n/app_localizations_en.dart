// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'About';

  @override
  String get lastPayments => 'Last Payments';

  @override
  String get showMore => 'show more';

  @override
  String get noPayments => 'no payments';

  @override
  String get scan => 'Scan';

  @override
  String get openWallet => 'Open wallet';

  @override
  String get cancel => 'cancel';

  @override
  String get ok => 'OK';

  @override
  String get verifyIdentity => 'Please verify your identity';

  @override
  String get localizedReason =>
      'Your authentication is required to open the wallet';

  @override
  String get sellCredentialTitle => 'Sell credential';

  @override
  String get forSale => 'offer for sale';

  @override
  String get forShow => 'offer for presentation';

  @override
  String get delete => 'delete';

  @override
  String get deletionNote1 =>
      'Are you sure you want to delete this credential?';

  @override
  String get deletionNote2 => 'This operation cannot be undone.';

  @override
  String get deletionNoteApp =>
      'Are you sure you want to delete this application?';

  @override
  String get issuer => 'Issuer';

  @override
  String get otherData => 'Other data';

  @override
  String get personnelData => 'Personal data';

  @override
  String get invoice => 'Invoice';

  @override
  String get invoiceNumber => 'invoice number';

  @override
  String get selfIssued => 'self-issued';

  @override
  String get verifiedBy => 'verified by: ';

  @override
  String get verified => 'verified';

  @override
  String get notVerified => 'not verified';

  @override
  String get state => 'state';

  @override
  String get valid => 'valid';

  @override
  String get expired => 'expired';

  @override
  String get inactive => 'inactive';

  @override
  String get revoked => 'revoked';

  @override
  String get unknown => 'unknown';

  @override
  String get issuanceDate => 'issuance date';

  @override
  String get expirationDate => 'expiration date';

  @override
  String get history => 'Activity';

  @override
  String get issued => 'issued';

  @override
  String get presented => 'presented';

  @override
  String get presentedError => 'presentation failed';

  @override
  String get presentCredential => 'present credential';

  @override
  String get contextCredentialTitle => 'Add context';

  @override
  String get create => 'create';

  @override
  String get credentialPageTitle => 'My credentials';

  @override
  String get show => 'show';

  @override
  String get preview => 'Preview';

  @override
  String get anonymousIssuer => 'anonymous issuer';

  @override
  String get anonymous => 'anonymous';

  @override
  String get total => 'total';

  @override
  String payments(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      zero: '',
    );
    return 'Payment$_temp0';
  }

  @override
  String get paymentMethod => 'payment method';

  @override
  String get noteShownCredentials => 'These credentials were just presented';

  @override
  String get noteOtherShowCredentials =>
      'Your counterpart offers to show you a credential with the following data:';

  @override
  String get request => 'request';

  @override
  String get requestTitle => 'Request';

  @override
  String get ignore => 'ignore';

  @override
  String get dataFor => 'The data are transmitted to:';

  @override
  String get reasonForRequest => 'reason for request';

  @override
  String get selfIssueAllowed =>
      'The requester allows to enter data by yourself';

  @override
  String get enterData => 'enter your data';

  @override
  String get presentationSuccessful => 'Credentials successfully presented';

  @override
  String get presentationFailed => 'Credentials could not be presented';

  @override
  String get reject => 'reject';

  @override
  String get send => 'send';

  @override
  String get sendPresentation => 'send credentials';

  @override
  String get username => 'User name in the selected network';

  @override
  String get mailAddress => 'e-mail addresse';

  @override
  String get selfIssuable => 'Self-issuable credentials';

  @override
  String get deviceInformation => 'device information';

  @override
  String get stored => 'credential saved';

  @override
  String get selfIssuance => 'Self-Issuance';

  @override
  String get noCredentialsTitle => 'Incorrect request';

  @override
  String get noCredentialsNote =>
      'You have just received a request that cannot be processed. Either functions are requested that your application does not currently support or your counterpart made a mistake when creating it.';

  @override
  String get paymentSuccessful => 'payment successful';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String get paymentFailed => 'payment failed';

  @override
  String get paymentFailedNote => 'Payment could not be performed';

  @override
  String get noPaymentMethod => 'payment not possible';

  @override
  String get requestPayment => 'request payment';

  @override
  String get noPaymentNote => 'No suitable payment method found';

  @override
  String get selectPaymentMethod => 'Select Lightning Account';

  @override
  String get chargeMoney => 'charge money';

  @override
  String get noPaymentMethodNote =>
      'You do not have a wallet for payment. \nPlease create one.';

  @override
  String get credentialReceived => 'Credential received';

  @override
  String get amountSatoshi => 'amount in Satoshi';

  @override
  String get amountEuro => 'amount in Euro';

  @override
  String get pay => 'pay';

  @override
  String get back => 'back';

  @override
  String get receive => 'receive';

  @override
  String get orderWithPayment => 'Order with obligation to pay';

  @override
  String get credentialOffer => 'Credential Offer';

  @override
  String get balance => 'Balance';

  @override
  String get noteGetInformation => 'like to have the following information';

  @override
  String get notePresentationPurpose => 'specifies to use the data for';

  @override
  String get missingDataTitle => 'Missing data';

  @override
  String get missingDataNote =>
      'The requester asks you to tell a little more about yourself. Please fill in the requested data.';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadFailedExplanation =>
      'The request of the counterpart can not be downloaded.';

  @override
  String get unexpectedMessage => 'Unexpected message';

  @override
  String get malformedMessage => 'Incorrect message';

  @override
  String get malformedOOBExplanation =>
      'The message cannot be read.\n You can try to scan the QR code one more time. \n If the error persists, contact the support of the request creator.';

  @override
  String get unknownMessageExplanation =>
      'This message is currently not supported.\n Therefore, the interaction cannot be continued.';

  @override
  String get malformedEncryptedMessage =>
      'An error occurred while decrypting a message.';

  @override
  String get waiting => 'Just a moment, please.';

  @override
  String get waitingSendPresentation => 'Your answer is sent.';

  @override
  String get waitingQrData => 'The data is being processed.';

  @override
  String get errorNotEnoughCredentials =>
      'You cannot fulfill the request of your counterpart because you do not have the necessary credentials.\nFind out how you can obtain the missing credentials.';

  @override
  String get errorNotEnoughSelected =>
      'You have not selected enough credentials to answer the request. \nPlease select the required credentials.';

  @override
  String get attention => 'Attention';

  @override
  String get cancelWarning => 'Please use \'Cancel\' to close';

  @override
  String get accept => 'Accept';

  @override
  String get noteNoCredentials => 'No Credentials';

  @override
  String get allCredentials => 'All Credentials';

  @override
  String get sendFailed => 'Sending failed';

  @override
  String get sendFailedNote =>
      'Sending a message failed or the message could not be processed by the other side';

  @override
  String get wrongCredential => 'Incorrect Credential';

  @override
  String get wrongCredentialNote =>
      'Your counterpart has issued a credential that bears an incorrect signature.\nInform him about this.';

  @override
  String get wrongCredentialNote2 =>
      'Your counterpart has issued a credential that is not intended for you';

  @override
  String get familyName => 'surname';

  @override
  String get givenName => 'given name';

  @override
  String get birthDate => 'birth date';

  @override
  String get countryName => 'country';

  @override
  String get stateOrProvinceName => 'state/province';

  @override
  String get localityName => 'locality';

  @override
  String get organizationName => 'organization';

  @override
  String get commonName => 'common name';

  @override
  String get loadIssuerData => 'Load information';

  @override
  String get errorOpen =>
      'The wallet cannot be opened.\nIs a security mechanism (pin, password, pattern, fingerprint,...) stored on your device?\nIf not, secure your device via your device settings.';

  @override
  String get credential => 'Credential';

  @override
  String get add => 'Add';

  @override
  String get hashNotMatch => 'Hash does not match';

  @override
  String get hashNotMatchNote =>
      'This may be an attempt to scam you,\ntherefore the payment will be canceled';

  @override
  String get otherValue => 'Other Amount';

  @override
  String get otherValueNote =>
      'The amount does not match the one you requested.\nThe payment is canceled.';

  @override
  String get copy => 'Copy';

  @override
  String get copyNote => 'Invoice copied to clipboard';

  @override
  String get enterAmount => 'Enter Amount';

  @override
  String get description => 'Description';

  @override
  String get favorites => 'Favorites';

  @override
  String get amount => 'Amount';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get termsOfServiceNote =>
      'Selected contexts have additional terms of use. Please read them carefully and select the ones you agree with. Contexts whose terms of use you do not agree with will not be added.';

  @override
  String get termsOfServiceButton => 'Add as selected';

  @override
  String get termsOfServiceNote1 =>
      'I have read and accept the terms and conditions and privacy policy at ';

  @override
  String get termsOfServiceNote2 => '.';

  @override
  String get pleaseAccept =>
      'Please accept our terms and conditions and privacy policy';

  @override
  String get addNewApp => 'Add a new context';

  @override
  String get invoiceLimit =>
      'For security reasons, your account balance must not exceed the equivalent of 10€. The invoice exceeds this amount.';

  @override
  String get creationFailed => 'Creation failed';

  @override
  String get license => 'Licenses';

  @override
  String get welcome => 'Welcome to Hidy';

  @override
  String get welcomeNote =>
      'Before your personal wallet is available to you, a few things need to be cleared up.';

  @override
  String get technic => 'Technical Requirements';

  @override
  String get technicNoteOk =>
      'Your smartphone is protected with pin, pattern, password or biometrics.';

  @override
  String get technicNoteBad =>
      'Your smartphone is not protected with pin, pattern, password or biometrics.';

  @override
  String get noteGoToSettings =>
      'Please protect your device in the system settings.';

  @override
  String get openSettings => 'Open System-Settings';

  @override
  String get recheck => 'Check again';

  @override
  String get start => 'Let\'s start';

  @override
  String get favoriteExplanation =>
      'Add a context to your favorites list by touching the star on the map.';

  @override
  String get addCardExplanation => 'Add a card by scanning its QR or barcode';

  @override
  String importSuccess(String passType) {
    return '$passType successfully imported';
  }

  @override
  String get importFailed => 'Import failed';

  @override
  String get saveError => 'Error saving';

  @override
  String get saveErrorNote =>
      'Unable to save the credential.\nPlease retry the operation.';

  @override
  String get paymentInformation => 'Payment information';

  @override
  String get paymentInformationDetail =>
      'The following costs are incurred for the further processing of the data: ';

  @override
  String get funding1 => 'You will be credited with ';

  @override
  String get funding2 => 'for releasing your data';

  @override
  String get oidcTan => 'Transaction number';

  @override
  String get oidcTanInfo =>
      'The issuer has sent you a transaction number for this transaction. Please enter it here.';

  @override
  String get noAppNote => 'You haven\'t added any applications yet';

  @override
  String get newAppTitle => 'New applications';

  @override
  String get newAppNote => 'No applications found';

  @override
  String get unknownQrCode => 'Unknown Qr-Code';

  @override
  String get unknownQrCodeNote =>
      'The scanned Qr code contains data that cannot be processed.';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get sendSatoshi => 'send Satoshi';

  @override
  String get backgroundPresentation => 'Background-Presentation';

  @override
  String backgroundPresentationNote(String otherParty) {
    return 'I hereby authorize $otherParty to request these credentials in the future without my explicit consent.';
  }

  @override
  String get finishProcess => 'Process completed';

  @override
  String get finishProcessNote =>
      'The credential has already been issued to you';

  @override
  String get authFailed => 'Authentication failed';

  @override
  String get credentialDownloadFailed => 'The credential cannot be downloaded';

  @override
  String get issuanceInfoNotFound =>
      'Unfortunately, we have not found out how you can obtain the missing credentials.';

  @override
  String get issuanceInfoFound =>
      'You can obtain the missing credentials here:';

  @override
  String get hsmwEmployeeCard => 'Employee-Card (HSMW)';

  @override
  String get hsmwStudentCard => 'Student-Card (HSMW)';

  @override
  String get pictureProcess => 'Your picture is created';

  @override
  String get pictureProcessNote => 'Please wait a moment';

  @override
  String get prepareWallet => 'Your personal wallet is being loaded';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get restore => 'Restore';

  @override
  String get restoreMenu => 'Restore Backup';

  @override
  String get restoreQuestion =>
      'When restoring, all previous data is overwritten. Are you sure you want to load a backup?';

  @override
  String get restoreMnemonic =>
      'Please enter the word sequence that was displayed when you created a backup:';

  @override
  String get restoreSuccess => 'Backup successfully restored';

  @override
  String get backup => 'Backup';

  @override
  String get backupUpload => 'Your backup is being created';

  @override
  String get backupSuccess => 'Backup successfully stored';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupFailedNote => 'Please try again';

  @override
  String get backupWriteDownPassword =>
      'Please note down this list of words! Without these words you wont be able to restore from backup!';

  @override
  String get backupNotFound => 'Backup not found! Wrong password?';

  @override
  String get noteNotInBackup =>
      'The following documents cannot be backed up for technical reasons, as it is not possible to restore them later:';

  @override
  String get backupRestoreError => 'An error has occurred';

  @override
  String get backupRestoreErrorNote => 'Please try again';

  @override
  String get askContinue => 'Would you like to continue?';

  @override
  String get note => 'Note';

  @override
  String get oidMetadataError => 'Incorrect metadata';

  @override
  String get oidMetadataErrorNote =>
      'Important information about the issuer or the requested credential cannot be found or is incorrect';

  @override
  String get unknownAuthServer => 'Unknown Issuer';

  @override
  String get oidAuthFailed => 'Authorization failed';

  @override
  String get oidAuthFailedNote =>
      'It is not possible to issue your credential because the necessary authorization has failed.\nPlease try again later.';

  @override
  String get authorization => 'Authorization';

  @override
  String get loadRequest => 'Load request';

  @override
  String get continueWithPin => 'Continue to PIN entry';

  @override
  String get identify => 'Identification';

  @override
  String get requestedData => 'Requested data:';

  @override
  String get providerInfo => 'Provider information';

  @override
  String get reason => 'Reason';

  @override
  String get validity => 'Validity';

  @override
  String get certificateIssuer => 'Certificate issuer';

  @override
  String get provider => 'Provider';

  @override
  String get insertCard =>
      'Please hold your ID card up to the NFC interface on your device. This is usually located on the back of the device.';

  @override
  String get readCard => 'Read ID Card';

  @override
  String get processFailed => 'Process failed';

  @override
  String get enterPuk => 'Enter PUK';

  @override
  String get enterPukNote => 'Please enter the 10-digit PUK of the ID card:';

  @override
  String get pukLengthNote => 'The PUK must have exactly 10 digits';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get enterPinNote => 'Please enter the 6-digit PIN of the ID card:';

  @override
  String get pinLengthNote => 'The PIN must have exactly 6 digits';

  @override
  String get remainingTry => 'Remaining attempts';

  @override
  String get retryNote2 =>
      'If you also enter an incorrect PIN during this attempt, the CAN must be entered before the last attempt. This is the 6-digit number sequence on the front of the ID card.';

  @override
  String get retryNote1 =>
      'This is your last attempt to enter a correct PIN. If this also fails, the online ID function will be blocked.';

  @override
  String get note5digit =>
      'You only have a 5-digit PIN? Then please cancel the process and use the \"Change PIN\" function of the official \"Ausweis-App\"';

  @override
  String get enterCan => 'Enter CAN';

  @override
  String get enterCanNote =>
      'Please enter the 6-digit CAN from the front of the ID card:';

  @override
  String get canLengthNote => 'The CAN must have exactly 6 digits';

  @override
  String get storeAsCredential => 'Store as credential';

  @override
  String get cardData => 'ID card data';

  @override
  String get address => 'Address';

  @override
  String get birthName => 'Birth name';

  @override
  String get birthPlace => 'Place of birth';

  @override
  String get doctoralDegree => 'Doctoral degree';

  @override
  String get artisticName => 'Artistic name';

  @override
  String get nationality => 'Nationality';

  @override
  String get issuingCountry => 'Issuing country';

  @override
  String get documentType => 'Document type';

  @override
  String get residencePermit1 => 'Residence permit 1';

  @override
  String get residencePermit2 => 'Residence permit 2';

  @override
  String get communityId => 'Community ID';

  @override
  String get addressVerification => 'Address verification';

  @override
  String get ageVerification => 'Age verification';

  @override
  String get bleOff => 'Bluetooth is deactivated. Please activate it.';

  @override
  String get bleTransmissionStart => 'Preparing';

  @override
  String get bleTransmissionPrepare => 'Data is created';

  @override
  String get bleTransmissionConnected =>
      'Successfully connected. Wait for request';

  @override
  String get bleTransmissionSend => 'Data send';

  @override
  String get bleTransmissionFinished =>
      'Transmission ended and connection disconnected';

  @override
  String get bleButton => 'Restart';

  @override
  String get bleError =>
      'An error has occurred. Please restart the process using the button.\nIf you see this message repeatedly, try switching Bluetooth off and on again or restarting Hidy';

  @override
  String get biometricPromptTitle => 'Signature Generation';

  @override
  String get biometricPromptSubtitle =>
      'Please authenticate for the usage of your signing key';

  @override
  String get verifiedMail => 'Verified e-mail addresses:';

  @override
  String get noMailAddress => 'You have not added any e-mail addresses';

  @override
  String get newMailAddress => 'Add new e-mail address';

  @override
  String get deleteMail =>
      'Are you sure you want to delete this e-mail address?';

  @override
  String get sendMailFailed => 'Failed to send e-mail';

  @override
  String get checkMails => 'Please check your e-mail inbox';

  @override
  String get sendSuccess => 'Send Successful';

  @override
  String get finish => 'Finish';

  @override
  String get frontside => 'Front';

  @override
  String get backside => 'Back';

  @override
  String get failedLoad => 'Loading failed';

  @override
  String get failedLoadNote =>
      'The application cannot be opened. Could it be that your device does not have an Internet connection?';

  @override
  String get share => 'Share';

  @override
  String get load => 'Load';

  @override
  String get open => 'Open';

  @override
  String get get => 'Get';
}
