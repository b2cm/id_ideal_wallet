# Hidy wallet

## The wallet

Wallet Application supporting W3C Verifiable Credentials and recent didcomm protocols
to issue credentials to the wallet and request them from the wallet. It also support
OpenID Connect for Verifiable Credential Issuance (draft 11) using the pre-authorized code flow and
OpenID
Connect for Verifiable Presentations.

The application also features a custodial lightning wallet.

This app is under development and for now only recommended to use for testing, demonstration and
research purpose.

## App-Link

- `https://wallet.bccm.dev`
- additional supported schemes: openid-credential-offer:// ; openid-credential-request:// ;
  openid4vp:// ;
- App is able to scan codes pointing to a
  webview: `https://wallet.bccm.dev/webview?url=https://maps.google.com&title=Karte`, where url
  parameter is mandatory and title optional
- if the url for the webview contains fragment and query it MUST be percent-encoded
- the wallet will add a wallet id to the url if requested. To request this id, add the
  query-parameter `wid=` (without value) to your url.
- the wallet can also understand links with ligthning-invoices or
  lnurls : `https://wallet.bccm.dev/invoice?invoice=<lightning invoice>`
  or `https://wallet.bccm.dev/invoice?lnurl=<lnurl>`

## Important Notes

- because the wallet store potential sensitive data the smartphone you run it on must offer an
  enrolled authentication mechanism (password, pin, pattern, fingerprint, face)
- running the wallet works like running every other flutter app using `flutter run`
  after `flutter pub get`

**Internationalization**
If building the app won't work out of box, run:

```
flutter gen-l10n
```

to generate needed translation files
