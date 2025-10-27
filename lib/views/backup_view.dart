import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/backup_functions.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';

final attention = RichText(
  text: TextSpan(
    style: Theme.of(navigatorKey.currentContext!).primaryTextTheme.bodySmall,
    children: [
      TextSpan(
        text: AppLocalizations.of(navigatorKey.currentContext!)!.attention,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      WidgetSpan(
        child: Container(
          padding: const EdgeInsets.only(
            left: 1,
            bottom: 5,
          ),
          child: Icon(
            Icons.error_outline,
            size: 18,
            color: Colors.redAccent.shade700,
          ),
        ),
      ),
    ],
  ),
);

class BackupOverview extends StatelessWidget {
  const BackupOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: AppLocalizations.of(context)!.backup,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: () =>
                  Provider.of<NavigationProvider>(context, listen: false)
                      .changePage([NavigationPage.backupCreate]),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
              child: Text(AppLocalizations.of(context)!.backup)),
          const SizedBox(
            height: 15,
          ),
          ElevatedButton(
              onPressed: () =>
                  Provider.of<NavigationProvider>(context, listen: false)
                      .changePage([NavigationPage.backupRestore]),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
              child: Text(AppLocalizations.of(context)!.restore))
        ],
      ),
    );
  }
}

class BackupWidget extends StatefulWidget {
  const BackupWidget({super.key});

  @override
  State<StatefulWidget> createState() => _BackupWidgetState();
}

class _BackupWidgetState extends State<BackupWidget> {
  String? _generateMemonic;
  String notInBackUp = '';
  Map<String, Map<String, dynamic>> data = {};
  bool initialized = false;
  bool processing = false;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    _generateMemonic = createMnemonic();
    var (data, notInBackUp) = await getBackupableData();
    this.data = data;
    this.notInBackUp = notInBackUp;
    setState(() {
      initialized = true;
    });
  }

  void _onBackupPressed() async {
    // Dismiss the keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      processing = true;
    });

    // Proceed with backup using the password
    RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    var result = await compute(performBackup, {
      'data': data,
      'mnemonic': _generateMemonic,
      'token': rootIsolateToken
    });

    if (result) {
      showSuccessMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.backupSuccess);
    } else {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.backupFailed,
          AppLocalizations.of(navigatorKey.currentContext!)!.backupFailedNote);
    }

    var navigationProvider = Provider.of<NavigationProvider>(
        navigatorKey.currentContext!,
        listen: false);
    if (navigationProvider.activeIndex == NavigationPage.backupCreate) {
      navigationProvider.goBack();
    }
  }

  List<Widget> notInBackupNote() {
    return [
      attention,
      Text(AppLocalizations.of(context)!.noteNotInBackup),
      const SizedBox(
        height: 5,
      ),
      Text(notInBackUp.substring(0, notInBackUp.length - 2),
          style: Theme.of(context).primaryTextTheme.titleMedium),
      const SizedBox(height: 16.0)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: AppLocalizations.of(context)!.backup,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: initialized
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.backupWriteDownPassword,
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      _generateMemonic!,
                      style: Theme.of(context).primaryTextTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    if (notInBackUp.isNotEmpty) ...notInBackupNote(),
                    FooterButtons(
                      positiveText: AppLocalizations.of(context)!.backup,
                      positiveFunction: _onBackupPressed,
                      negativeFunction: () => Provider.of<NavigationProvider>(
                              context,
                              listen: false)
                          .goBack(),
                      negativeText: AppLocalizations.of(context)!.cancel,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Text('Daten werden zusammengetragen'),
                    CircularProgressIndicator()
                  ],
                ),
        ),
        if (processing)
          const Opacity(
            opacity: 0.8,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (processing)
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(
                  height: 10,
                ),
                DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    child: Text(
                      '${AppLocalizations.of(context)!.waiting}\n${AppLocalizations.of(context)!.backupUpload}',
                    ))
              ],
            ),
          ),
      ]),
    );
  }
}

class RestoreWidget extends StatefulWidget {
  const RestoreWidget({super.key});

  @override
  createState() => RestoreWidgetState();
}

class RestoreWidgetState extends State<RestoreWidget> {
  List<TextEditingController> controllers =
      List.generate(12, (_) => TextEditingController());
  bool processing = false;

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: AppLocalizations.of(context)!.restoreMenu,
      child: Stack(children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(AppLocalizations.of(context)!.restoreMnemonic),
                const SizedBox(
                  height: 10,
                ),
                ...List.generate(
                  12,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                        labelText: 'Word ${index + 1}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                attention,
                Text(AppLocalizations.of(context)!.restoreQuestion),
                const SizedBox(
                  height: 10,
                ),
                FooterButtons(
                  positiveText: AppLocalizations.of(context)!.restore,
                  positiveFunction: () async {
                    setState(() {
                      processing = true;
                    });
                    FocusScope.of(context).unfocus();
                    String mnemonic = controllers
                        .map((controller) => controller.text.trim())
                        .join(' ');
                    logger.d(mnemonic);
                    var success = await applyBackup(context, mnemonic);
                    if (!success && mounted) {
                      setState(() {
                        processing = false;
                      });
                    }
                  },
                  negativeFunction: () =>
                      Provider.of<NavigationProvider>(context, listen: false)
                          .goBack(),
                  negativeText: AppLocalizations.of(context)!.cancel,
                ),
                const SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),
        ),
        if (processing)
          const Opacity(
            opacity: 0.8,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (processing)
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(
                  height: 10,
                ),
                DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    child: Text(
                      '${AppLocalizations.of(context)!.waiting}\n${AppLocalizations.of(context)!.backupUpload}',
                    ))
              ],
            ),
          ),
      ]),
    );
  }
}

void showConfirmationDialog(
    BuildContext context, void Function(BuildContext, String) onConfirmed) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevents dismissing by tapping outside
    builder: (BuildContext context2) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context)!.backup),
        content: Text(AppLocalizations.of(context)!.restoreQuestion),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.no),
            onPressed: () {
              Navigator.of(context2).pop();
            },
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.yes),
            onPressed: () {
              Navigator.of(context2).pop();
              askForMnemonic(context).then((mnemonic) =>
                  {onConfirmed(navigatorKey.currentContext!, mnemonic!)});
            },
          ),
        ],
      );
    },
  );
}

Future<String?> askForMnemonic(BuildContext context) async {
  List<TextEditingController> controllers =
      List.generate(12, (_) => TextEditingController());

  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context)!.restoreMnemonic),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              12,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: TextField(
                  controller: controllers[index],
                  decoration: InputDecoration(
                    labelText: 'Word ${index + 1}',
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () {
              Navigator.of(context).pop(null); // Return null if canceled
            },
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.ok),
            onPressed: () {
              // Combine all entered words into a single space-separated string
              String mnemonic = controllers
                  .map((controller) => controller.text.trim())
                  .join(' ');
              Navigator.of(context).pop(mnemonic); // Return the mnemonic string
            },
          ),
        ],
      );
    },
  );
}
