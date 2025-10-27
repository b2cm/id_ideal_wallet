import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/l10n/app_localizations.dart';

class DeleteDialog extends StatelessWidget {
  final Widget deleteNote;
  final void Function() deleteFunction;

  const DeleteDialog(
      {super.key, required this.deleteNote, required this.deleteFunction});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.delete),
      content: deleteNote,
      actions: [
        Row(children: [
          Expanded(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)!.cancel)),
          ),
          SizedBox(
            width: 10,
          ),
          Expanded(
            child: ElevatedButton(
                onPressed: deleteFunction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)!.delete)),
          )
        ])
      ],
    );
  }
}
