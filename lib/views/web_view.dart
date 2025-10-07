import 'dart:convert';

import 'package:base_codecs/base_codecs.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/mdoc_provider.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/iso_credential_request.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

class WebViewWindow extends StatefulWidget {
  final AboData webViewData;
  final String? initialHtml;
  final bool isSecure;

  const WebViewWindow(
      {super.key,
      required this.webViewData,
      this.isSecure = true,
      this.initialHtml});

  @override
  State<StatefulWidget> createState() => WebViewWindowState();
}

class WebViewWindowState extends State<WebViewWindow> {
  final GlobalKey webViewKey = GlobalKey();
  bool isInAbo = false;
  String? imageUrl;
  String title = '';
  String baseUrl = '';

  //List<String>? trustedSites;
  bool mdocRunning = false;
  Color? titleBgColor, titleFontColor;

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      allowFileAccess: false,
      allowFileAccessFromFileURLs: false,
      allowBackgroundAudioPlaying: false,
      mediaPlaybackRequiresUserGesture: true,
      allowsInlineMediaPlayback: false,
      supportMultipleWindows: true,
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  double progress = 0;

  @override
  void initState() {
    super.initState();

    imageUrl = widget.webViewData.pictureUrl;
    title = widget.webViewData.name;
    baseUrl = widget.webViewData.url;

    // checkAbo();

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  // Future<void> checkAbo() async {
  //   var currentAbos =
  //       Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
  //           .aboList;
  //
  //   List<String> allAbos =
  //       currentAbos.map((e) => e.getComparableUrl()).toList();
  //
  //   var asUri = Uri.parse(widget.initialUrl);
  //   var toCheck = removeTrailingSlash(
  //       '${asUri.scheme.isEmpty ? 'https' : asUri.scheme}://${asUri.host}${asUri.path}');
  //   bool inLocalAboList = allAbos.contains(toCheck);
  //   logger.d('$allAbos contains? $toCheck');
  //
  //   var trustedData = await initTrustedSites();
  //   trustedSites = trustedData.keys.toList();
  //
  //   imageUrl = trustedData[toCheck]?.pictureUrl;
  //   titleBgColor = trustedData[toCheck]?.getTitleBgColor();
  //   titleFontColor = trustedData[toCheck]?.getTitleFontColor();
  //   baseUrl = toCheck;
  //
  //   if (title.isEmpty) {
  //     title = trustedData[toCheck]?.name ?? '';
  //   }
  //
  //   if (inLocalAboList) {
  //     // we have already an abo
  //     setState(() {});
  //     return;
  //   }
  //
  //   logger.d('$trustedSites contains? $toCheck');
  //   if (trustedSites!.contains(toCheck)) {
  //     Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
  //         .addAbo(trustedData[toCheck]!);
  //   }
  //
  //   setState(() {});
  // }

  Future<Map<String, AboData>> initTrustedSites() async {
    var res = await get(Uri.parse(applicationEndpoint));
    Map<String, AboData> available = {};
    if (res.statusCode == 200) {
      List dec = jsonDecode(res.body);
      for (var entry in dec) {
        var data = AboData.fromJson(entry);
        available[data.getComparableUrl()] = data;
      }
    }
    return available;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController?.goBack();
          return false;
        } else {
          return true;
        }
      },
      child: Consumer<WalletProvider>(builder: (context, wallet, child) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            backgroundColor: titleBgColor,
            leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: titleFontColor,
                )),
            actions: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: MenuAnchor(
                  alignmentOffset: Offset(10, 2),
                  menuChildren: [
                    if (widget.isSecure)
                      MenuItemButton(
                          trailingIcon: Icon(Icons.share),
                          onPressed: () {
                            SharePlus.instance.share(ShareParams(
                                uri: Uri.parse(
                                    'https://wallet.bccm.dev/webview?url=${Uri.encodeFull(widget.webViewData.url)}&title=${widget.webViewData.name}')));
                          },
                          child: Text('Teilen')),
                    MenuItemButton(
                      trailingIcon: Icon(Icons.refresh),
                      onPressed: () {
                        webViewController?.reload();
                      },
                      child: Text('Laden'),
                    ),
                    // TODO uncomment if rating feature ready to use
                    // MenuItemButton(
                    //   trailingIcon: Icon(Icons.star_border),
                    //   onPressed: () {
                    //     showDialog(
                    //         context: context,
                    //         builder: (context) {
                    //           return Dialog(
                    //             child: RateSubApp(
                    //                 abo: AboData(widget.title,
                    //                     widget.initialUrl, widget.iconUrl!)),
                    //           );
                    //         });
                    //   },
                    //   child: Text('Bewerten'),
                    // )
                  ],
                  builder: (_, MenuController controller, Widget? child) {
                    return IconButton(
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                      icon: Icon(
                        Icons.more_vert,
                        color: titleFontColor,
                      ),
                    );
                  },
                ),
              )
            ],
            centerTitle: true,
            title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.07,
                  height: MediaQuery.of(context).size.width * 0.07,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(4),
                    ),
                    child: CachedImage(
                      // key: UniqueKey(),
                      imageUrl: imageUrl!,
                      placeholder: title,
                    ),
                  ),
                ),
              if (imageUrl != null && imageUrl!.isNotEmpty)
                const SizedBox(
                  width: 3,
                ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: titleFontColor),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ]),
          ),
          body: SafeArea(
            child: Column(children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      key: webViewKey,
                      initialUrlRequest: widget.initialHtml == null
                          ? URLRequest(url: WebUri(widget.webViewData.url))
                          : null,
                      initialData: widget.initialHtml != null
                          ? InAppWebViewInitialData(
                              data: widget.initialHtml!,
                              baseUrl: WebUri(widget.webViewData.url),
                            )
                          : null,
                      initialSettings: settings,
                      pullToRefreshController: pullToRefreshController,
                      // Testing only: accept bad (self signed) certs
                      onReceivedServerTrustAuthRequest:
                          (controller, challenge) async {
                        return ServerTrustAuthResponse(
                            action: ServerTrustAuthResponseAction.PROCEED);
                      },
                      onCreateWindow: (a, b) async {
                        logger.d('Open request');
                        return false;
                      },
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                        if (widget.isSecure) {
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'echoHandlerAsync',
                              callback: (args) async {
                                await Future.delayed(
                                    const Duration(seconds: 2));
                                return args;
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'echoHandler',
                              callback: (args) {
                                return args;
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'shareHandler',
                              callback: (args) async {
                                var res = await SharePlus.instance
                                    .share(ShareParams(text: args.first));
                                return res.status == ShareResultStatus.success;
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'initiateProximitySharing',
                              callback: (args) async {
                                navigateClassic(
                                    const IsoCredentialRequest(), true);
                                return true;
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'shareImageHandler',
                              callback: (args) async {
                                var d = UriData.fromUri(Uri.parse(args.first));
                                var res = await SharePlus.instance
                                    .share(ShareParams(files: [
                                  XFile.fromData(
                                    d.contentAsBytes(),
                                    mimeType: d.mimeType,
                                  )
                                ], fileNameOverrides: [
                                  'hidyShare.${d.mimeType.split('/').last}'
                                ]));
                                return res.status == ShareResultStatus.success;
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'presentationRequestHandler',
                              callback: (args) async {
                                logger.d(args);
                                return await requestPresentationHandler(
                                    args.first,
                                    widget.webViewData.url,
                                    args[1],
                                    args[2]);
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'presentationRequestNoSignature',
                              callback: (args) async {
                                logger.d(args);
                                return await requestPresentationNoSign(
                                    args.first, widget.webViewData.url);
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'initializeSigningKey',
                              callback: (args) async {
                                if (args.isEmpty) {
                                  return await getSigningKey(
                                    true,
                                    true,
                                    2,
                                  );
                                } else {
                                  return await getSigningKey(
                                      args.first, args[1], args.last);
                                }
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'signData',
                              callback: (args) async {
                                logger.d(args);
                                return await signData(args.first, args.last);
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'scanQrCode',
                              callback: (args) async {
                                return await navigateClassic(QrScanner(
                                  inApp: false,
                                ));
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'addAccount',
                              callback: (args) async {
                                var pseudo = await Provider.of<WalletProvider>(
                                        context,
                                        listen: false)
                                    .generatePseudonym(baseUrl);
                                logger.d(pseudo);
                                return pseudo.toJson();
                              });
                          webViewController?.addJavaScriptHandler(
                              handlerName: 'loginToAccount',
                              callback: (args) {
                                return Provider.of<WalletProvider>(context,
                                        listen: false)
                                    .accountVcs[baseUrl]
                                    ?.toJson();
                              });
                        }
                      },
                      onLoadStart: (controller, url) {
                        setState(() {});
                      },
                      onPermissionRequest: (controller, request) async {
                        return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.GRANT);
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        var uri = navigationAction.request.url!;

                        if ((uri.authority.contains('wallet.id-ideal.de') ||
                            uri.authority.contains('wallet.bccm.dev') ||
                            uri.scheme == 'eudi-openid4ci')) {
                          Provider.of<NavigationProvider>(context,
                                  listen: false)
                              .handleLink(
                                  '${uri.toString()}&initialWebview=${widget.webViewData.url}');
                          return NavigationActionPolicy.CANCEL;
                        }

                        // if (![
                        //   "http",
                        //   "https",
                        //   "file",
                        //   "chrome",
                        //   "data",
                        //   "javascript",
                        //   "about"
                        // ].contains(uri.scheme)) {
                        //   if (await canLaunchUrl(uri)) {
                        //     // Launch the App
                        //     await launchUrl(
                        //       uri,
                        //     );
                        //     // and cancel the request
                        //     return NavigationActionPolicy.CANCEL;
                        //   }
                        // }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onLoadStop: (controller, url) async {
                        pullToRefreshController?.endRefreshing();
                        setState(() {});
                      },
                      onReceivedError: (controller, request, error) {
                        pullToRefreshController?.endRefreshing();
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          pullToRefreshController?.endRefreshing();
                        }
                        setState(() {
                          this.progress = progress / 100;
                        });
                      },
                      // onUpdateVisitedHistory:
                      //     (controller, url, androidIsReload) {
                      //   logger.d(
                      //       'new Uri: ${removeTrailingSlash(url.toString())}');
                      //   Provider.of<NavigationProvider>(context, listen: false)
                      //       .setWebViewUrl(removeTrailingSlash(url.toString()));
                      // },
                      onConsoleMessage: (controller, consoleMessage) {
                        logger.d(consoleMessage);
                      },
                    ),
                    progress < 1.0
                        ? LinearProgressIndicator(value: progress)
                        : Container(),
                  ],
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<Map<String, dynamic>> getSigningKey(bool userAuthenticationRequired,
      bool invalidateByNewBiometrics, int authType) async {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    var keyId = await wallet.newCredentialDid(KeyType.p256, KeyStore.system, {
      'userAuthenticationRequired': userAuthenticationRequired,
      'attestationChallenge': 'webview',
      'invalidateByNewBiometric': invalidateByNewBiometrics,
      'authType': authType
    });
    logger.d(keyId);
    try {
      var keyInfo = await wallet.wallet
          .getKeyInformation(wallet.getOsKeyStoreIdForDid(keyId)!);
      return keyInfo;
    } on PlatformException catch (e) {
      return {'errorCode': e.code, 'message': e.message, 'details': e.details};
    }
  }

  Future<String> signData(String keyId, String data) async {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    try {
      var signature = await wallet.wallet
          .sign(keyId, base64Decode(addPaddingToBase64(data)));
      return removePaddingFromBase64(base64UrlEncode(signature));
    } on PlatformException catch (e) {
      return jsonEncode(
          {'errorCode': e.code, 'message': e.message, 'details': e.details});
    }
  }

  Future<Map<String, dynamic>> requestPresentationNoSign(
    dynamic request,
    String initialUrl,
  ) async {
    var asUri = Uri.parse(initialUrl);
    var toCheck =
        removeTrailingSlash('${asUri.scheme}://${asUri.host}${asUri.path}');

    // if (trusted == null || trusted.isEmpty) {
    //   var trustedData = await initTrustedSites();
    //   trusted = trustedData.keys.toList();
    // }
    //
    // if (testBuild) {
    //   trusted.add('https://localhost');
    //   trusted.add('http://localhost');
    // }
    //
    // logger.d('$trusted contains? $toCheck');
    // if (!trusted.contains(toCheck)) {
    //   return {'error': 'untrusted site'};
    // }

    var definition = PresentationDefinition.fromJson(request);
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);

    var allCreds = wallet.allCredentials();
    List<VerifiableCredential> creds = [];
    allCreds.forEach((key, value) {
      if (value.verifiableCredential != '') {
        var vc = VerifiableCredential.fromJson(value.verifiableCredential);
        var type = getTypeToShow(vc.type);
        if (type != 'PaymentReceipt') {
          var id = vc.credentialSubject['id'];
          var status = wallet.revocationState[id];
          if (status == RevocationState.valid.index ||
              status == RevocationState.unknown.index) {
            creds.add(vc);
          }
        }
      }
    });
    List<VerifiableCredential> toSend = [];
    try {
      var filtered = searchCredentialsForPresentationDefinition(definition,
          credentials: creds);
      logger.d('successfully filtered');

      for (var entry in filtered) {
        if (entry.fulfilled && entry.credentials != null) {
          toSend.addAll(entry.credentials!.map((e) {
            return VerifiableCredential(
                id: e.id,
                context: e.context,
                type: e.type,
                credentialSubject: e.credentialSubject,
                issuer: {},
                issuanceDate: e.issuanceDate);
          }));
        }
      }
    } catch (e) {
      logger.d(e);
      return {'error': 'no matching credentials'};
    }
    if (toSend.isNotEmpty) {
      return VerifiablePresentation(
              context: [credentialsV1Iri],
              type: ['VerifiablePresentation'],
              verifiableCredential: toSend)
          .toJson();
    }
    return {'error': 'no matching credentials'};
  }

  Future<VerifiablePresentation?> requestPresentationHandler(dynamic request,
      String initialUrl, String nonce, bool askForBackground) async {
    var definition = PresentationDefinition.fromJson(request);
    var definitionToHash = PresentationDefinition(
        inputDescriptors: definition.inputDescriptors
            .map((e) => InputDescriptor(
                  id: '',
                  constraints: InputDescriptorConstraints(
                    subjectIsIssuer: e.constraints?.subjectIsIssuer,
                    fields: e.constraints?.fields
                        ?.map((eIn) => InputDescriptorField(
                            path: eIn.path, id: '', filter: eIn.filter))
                        .toList(),
                  ),
                ))
            .toList(),
        submissionRequirement: definition.submissionRequirement
            ?.map((e) => SubmissionRequirement(
                rule: e.rule,
                count: e.count,
                from: e.from,
                max: e.max,
                min: e.min))
            .toList(),
        id: '');
    var definitionHash =
        sha256.process(utf8.encode(definitionToHash.toString()));

    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);

    var allCreds = wallet.allCredentials();
    List<VerifiableCredential> creds = [];
    allCreds.forEach((key, value) {
      if (value.verifiableCredential != '') {
        var vc = VerifiableCredential.fromJson(value.verifiableCredential);
        var type = getTypeToShow(vc.type);
        if (type != 'PaymentReceipt') {
          var id = vc.credentialSubject['id'];
          var status = wallet.revocationState[id];
          if (status == RevocationState.valid.index ||
              status == RevocationState.unknown.index) {
            creds.add(vc);
          }
        }
      }
    });

    try {
      VerifiablePresentation? vp;
      var filtered = searchCredentialsForPresentationDefinition(definition,
          credentials: creds);
      logger.d('successfully filtered');

      var authorizedApps = wallet.getAuthorizedApps();
      var authorizedHashes = wallet.getHashesForAuthorizedApp(initialUrl);
      logger.d(authorizedHashes);
      logger.d(hexEncode(definitionHash));
      if (authorizedApps.contains(initialUrl) &&
          authorizedHashes.contains(hexEncode(definitionHash))) {
        logger.d('send with no interaction');
        var vp = VerifiablePresentation.fromFilterResults(filtered);
        for (var vc in vp.verifiableCredential!) {
          var did = vc.credentialSubject['id'];
          if (did == null || did == '') continue;
          var (signer, proofType) =
              await getCredentialSigningStuff(wallet, did);
          await vp.addProof(signer, proofType,
              challenge: nonce, loadDocument: loadDocumentFast);
        }
      } else {
        var target = PresentationRequestDialog(
          definition: definition,
          askForBackground: askForBackground,
          name: definition.name,
          purpose: definition.purpose,
          otherEndpoint: initialUrl,
          results: filtered,
        );
        bool backgroundAllow;
        (backgroundAllow, vp) = await navigateClassic(target);
        if (askForBackground && backgroundAllow) {
          var wallet = Provider.of<WalletProvider>(context, listen: false);
          wallet.addAuthorizedApp(initialUrl, hexEncode(definitionHash));
        }
      }

      return vp;
    } catch (e) {
      logger.e(e);
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
          AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
      return null;
    }
  }

  @override
  void dispose() {
    if (mdocRunning) {
      Provider.of<MdocProvider>(navigatorKey.currentContext!, listen: false)
          .stopAdvertising(true);
    }
    super.dispose();
  }
}
