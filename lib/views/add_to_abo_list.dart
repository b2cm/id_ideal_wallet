// import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:id_ideal_wallet/provider/wallet_provider.dart';
// import 'package:provider/provider.dart';
//
// class AddToAboList extends StatefulWidget {
//   final String? givenTitle;
//   final String url;
//
//   const AddToAboList({super.key, required this.url, this.givenTitle});
//
//   @override
//   AddToAboListState createState() => AddToAboListState();
// }
//
// class AddToAboListState extends State<AddToAboList> {
//   TextEditingController? titleController;
//   TextEditingController groupController = TextEditingController();
//   var formKey = GlobalKey<FormState>();
//
//   @override
//   void initState() {
//     super.initState();
//     titleController = TextEditingController(text: widget.givenTitle);
//   }
//
//   @override
//   void dispose() {
//     titleController?.dispose();
//     groupController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Form(
//       key: formKey,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextFormField(
//                 decoration: const InputDecoration(
//                   border: OutlineInputBorder(),
//                   labelText: 'Titel',
//                 ),
//                 controller: titleController,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Bitte wähle einen Titel';
//                   }
//                   return null;
//                 }),
//             const SizedBox(
//               height: 15,
//             ),
//             TextFormField(
//               controller: groupController,
//               decoration: InputDecoration(
//                 border: const OutlineInputBorder(),
//                 labelText: 'Kategorie',
//                 suffixIcon: PopupMenuButton<String>(
//                   position: PopupMenuPosition.under,
//                   icon: const Icon(Icons.arrow_drop_down),
//                   onSelected: (String value) {
//                     groupController.text = value;
//                     setState(() {});
//                   },
//                   itemBuilder: (context) {
//                     return Provider.of<WalletProvider>(context, listen: false)
//                         .aboGroups
//                         .keys
//                         .map((e) => PopupMenuItem(
//                               value: e,
//                               child: Text(e),
//                             ))
//                         .toList();
//                   },
//                 ),
//               ),
//             ),
//             Row(
//               children: [
//                 TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: Text(AppLocalizations.of(context)!.cancel)),
//                 TextButton(
//                     onPressed: () {
//                       if (formKey.currentState!.validate()) {
//                         Provider.of<WalletProvider>(context, listen: false)
//                             .addAbo(
//                                 widget.url,
//                                 titleController!.text,
//                                 groupController.text.isEmpty
//                                     ? 'Sonstiges'
//                                     : groupController.text);
//                         Navigator.of(context).pop();
//                       }
//                     },
//                     child: Text(AppLocalizations.of(context)!.add))
//               ],
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
