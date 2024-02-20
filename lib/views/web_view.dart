import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_web_view.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:provider/provider.dart';

class WebViewWindow extends StatefulWidget {
  final String initialUrl;
  final String title;

  const WebViewWindow(
      {super.key, required this.initialUrl, required this.title});

  @override
  State<StatefulWidget> createState() => WebViewWindowState();
}

class WebViewWindowState extends State<WebViewWindow> {
  final GlobalKey webViewKey = GlobalKey();
  bool isInAbo = false;

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    var currentAbos =
        Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
            .aboList;
    List<String> allAbos = currentAbos.map((e) => e['url']!).toList();
    var asUri = Uri.parse(widget.initialUrl);
    var toCheck = '${asUri.scheme}://${asUri.host}${asUri.path}';
    isInAbo = allAbos.contains(toCheck);
    logger.d('$allAbos contains? $toCheck');

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
        return StyledScaffoldWebView(
          title: widget.title,
          abo: isInAbo
              ? null
              : () {
                  wallet.addAbo(widget.initialUrl, '', widget.title);
                },
          backOnTap: () async {
            if (webViewController != null &&
                await webViewController!.canGoBack()) {
              webViewController?.goBack();
            } else {
              Navigator.of(navigatorKey.currentContext!)
                  .popUntil((route) => route.isFirst);
            }
          },
          reloadOnTap: () async {
            var initialUri = await webViewController?.getUrl();
            if (initialUri?.fragment != null &&
                initialUri!.fragment.contains('wid')) {
              webViewController?.reload();
            } else {
              var wallet = Provider.of<WalletProvider>(
                  navigatorKey.currentContext!,
                  listen: false);
              webViewController?.loadUrl(
                  urlRequest: URLRequest(
                      url: WebUri.uri(Uri.parse(
                          '$initialUri${initialUri.toString().contains('?') ? '&wid=${wallet.lndwId}' : '?wid=${wallet.lndwId}'}'))));
            }
          },
          child: SafeArea(
            child: Column(children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      key: webViewKey,
                      initialUrlRequest:
                          URLRequest(url: WebUri(widget.initialUrl)),
                      initialSettings: settings,
                      pullToRefreshController: pullToRefreshController,
                      // Testing only: accept bad (self signed) certs
                      onReceivedServerTrustAuthRequest:
                          (controller, challenge) async {
                        return ServerTrustAuthResponse(
                            action: ServerTrustAuthResponseAction.PROCEED);
                      },
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                        webViewController?.addJavaScriptHandler(
                            handlerName: 'echoHandlerAsync',
                            callback: (args) async {
                              await Future.delayed(const Duration(seconds: 2));
                              return args;
                            });
                        webViewController?.addJavaScriptHandler(
                            handlerName: 'echoHandler',
                            callback: (args) {
                              return args;
                            });
                        webViewController?.addJavaScriptHandler(
                            handlerName: 'presentationRequestHandler',
                            callback: (args) async {
                              logger.d(args);
                              return await requestPresentationHandler(
                                  args.first,
                                  widget.initialUrl,
                                  args[1],
                                  args[2]);
                            });
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          urlController.text = widget.initialUrl;
                        });
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
                                uri.authority.contains('wallet.bccm.dev')) &&
                            uri.query.contains('oob')) {
                          handleDidcommMessage(
                              '${uri.toString()}&initialWebview=${widget.initialUrl}');
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
                        setState(() {
                          urlController.text = widget.initialUrl;
                        });
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
                          urlController.text = widget.initialUrl;
                        });
                      },
                      onUpdateVisitedHistory:
                          (controller, url, androidIsReload) {
                        setState(() {
                          urlController.text = widget.initialUrl;
                        });
                      },
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
  var definitionHash = sha256.convert(utf8.encode(definitionToHash.toString()));

  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var allCreds = wallet.allCredentials();
  List<VerifiableCredential> creds = [];
  allCreds.forEach((key, value) {
    if (value.w3cCredential != '') {
      var vc = VerifiableCredential.fromJson(value.w3cCredential);
      var type = getTypeToShow(vc.type);
      if (type != 'PaymentReceipt') {
        var id = getHolderDidFromCredential(vc.toJson());
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
    var filtered =
        searchCredentialsForPresentationDefinition(creds, definition);
    logger.d('successfully filtered');

    var authorizedApps = wallet.getAuthorizedApps();
    var authorizedHashes = wallet.getHashesForAuthorizedApp(initialUrl);
    logger.d(authorizedHashes);
    logger.d(definitionHash.toString());
    if (authorizedApps.contains(initialUrl) &&
        authorizedHashes.contains(definitionHash.toString())) {
      logger.d('send with no interaction');
      var tmp = await buildPresentation(filtered, wallet.wallet, nonce,
          loadDocumentFunction: loadDocumentFast);
      vp = VerifiablePresentation.fromJson(tmp);
    } else {
      vp = await Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => PresentationRequestDialog(
            definitionHash: definitionHash.toString(),
            askForBackground: askForBackground,
            name: definition.name,
            purpose: definition.purpose,
            otherEndpoint: initialUrl,
            receiverDid: '',
            myDid: '',
            results: filtered,
            nonce: nonce,
          ),
        ),
      );
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
