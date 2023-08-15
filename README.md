# Hidy wallet

## The wallet

Wallet Application supporting W3C Verifiable Credentials and recent didcomm protocols
to issue credentials to the wallet and request them from the wallet. It also support
OpenID Connect for Verifiable Credential Issuance using the pre-authorized code flow and OpenID
Connect for
Verifiable Presentations.

The application also features a custodial lightning wallet.

This app is under development and for now only recommended to use for testing, demonstration and
research
purpose.

## App-Link

- `https://wallet.bccm.dev`
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
- Documentation  (Flow charts) explaining how the wallet react on specific didcomm messages can be
  found in doc folder
- running the wallet works like running every other flutter app using `flutter run`
  after `flutter pub get`

**Flutter 3.10.x**

- after last update it is possible that the wallet is only buildable with at least this
  flutter-version (because of some problems with pdf package)

**Last update added Internationalization**
If building the app won't work out of box, run:

```
flutter gen-l10n
```

to generate needed translation files

## App Links in iOS (universal links)

1. Add "FlutterDeepLinkingEnabled": YES (boolean) to the Info.plist
2. In Singing & Capabilities, add applinks:wallet.bccm.dev to the domains
3. Create a file <https://wallet.bccm.dev/.well-known/apple-app-site-association> (must be https),
   with this content:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "9MY7ZZP3KS.eu.hidy.app",
        "paths": [
          "*"
        ]
      }
    ]
  }
}
```

(the weird code before the identifier is the team id, which can be found in the development team
apple ID)

4. Make sure that the file is delivered as content-type: application/json (it has no extension, so
   configure the web server accordingly)
5. Write the app-internal code to handle routing