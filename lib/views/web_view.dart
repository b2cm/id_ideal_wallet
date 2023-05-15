import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_web_view.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class WebViewWindow extends StatefulWidget {
  final String initialUrl;
  final String title;

  const WebViewWindow({Key? key, required this.initialUrl, required this.title})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => WebViewWindowState();
}

class WebViewWindowState extends State<WebViewWindow> {
  final GlobalKey webViewKey = GlobalKey();

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
    return StyledScaffoldWebView(
        title: widget.title,
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
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
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
                      handleDidcommMessage(uri.toString());
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
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    setState(() {
                      urlController.text = widget.initialUrl;
                    });
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print(consoleMessage);
                  },
                ),
                progress < 1.0
                    ? LinearProgressIndicator(value: progress)
                    : Container(),
              ],
            ),
          ),
        ])));
  }
}
