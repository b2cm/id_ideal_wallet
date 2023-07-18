import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';

import 'currency_display.dart';

class IdCard extends StatelessWidget {
  const IdCard(
      {super.key,
      required this.cardTitle,
      required this.subjectName,
      required this.bottomLeftText,
      required this.bottomRightText,
      this.cardColor = const Color.fromARGB(255, 255, 86, 86),
      this.cardTitleColor = const Color.fromARGB(255, 255, 255, 255),
      this.backgroundColor = const Color.fromARGB(255, 233, 224, 200),
      this.subjectImage,
      this.backgroundImage,
      this.issuerIcon,
      this.borderColor = const Color.fromARGB(255, 122, 122, 122)});

  factory IdCard.fromCredential(
      {required VerifiableCredential credential,
      WalletProvider? wallet,
      String? background}) {
    if (credential.type.contains('ContextCredential')) {
      if (credential.type.contains('PaymentContext')) {
        return PaymentCard(
          receiveOnTap: () {},
          sendOnTap: () {},
          balance: wallet?.balance[credential.id]?.toStringAsFixed(2) ?? '0.0',
          cardTitle: credential.credentialSubject['name'],
          subjectName: '',
          bottomLeftText: const SizedBox(
            width: 0,
          ),
          bottomRightText: const SizedBox(
            width: 0,
          ),
        );
      } else {
        return ContextCredentialCard(
            cardTitle: '',
            backgroundImage:
                credential.credentialSubject['backgroundImage'] != null
                    ? Image.memory(base64Decode(credential
                            .credentialSubject['backgroundImage']
                            .split(',')
                            .last))
                        .image
                    : null,
            subjectName: credential.credentialSubject['name'],
            bottomLeftText: const SizedBox(
              width: 0,
            ),
            bottomRightText: const SizedBox(
              width: 0,
            ));
      }
    } else if (credential.type.contains('MemberCard')) {
      return MemberCard(
          barcodeType: credential.credentialSubject['barcodeType'],
          memberNumber: credential.credentialSubject['number'],
          cardTitle: credential.credentialSubject['name'],
          subjectName: '',
          bottomLeftText: IssuerInfoText(
              issuer: credential.issuer, selfIssued: credential.isSelfIssued()),
          bottomRightText: IssuerInfoIcon(
            issuer: credential.issuer,
            selfIssued: credential.isSelfIssued(),
          ));
    } else if (credential.type.contains('ChallengeSolvedCredential') ||
        credential.type.contains('Losticket') ||
        credential.type.contains('JuniorDiplom')) {
      return LNDWCard(
          cardTitle: credential.credentialSubject['icon'] ?? '',
          backgroundImage: background != null
              ? Image.memory(base64Decode(background.split(',').last)).image
              : null,
          subjectName: credential.credentialSubject['stand'] ??
              getTypeToShow(credential.type),
          bottomLeftText: const SizedBox(
            width: 0,
          ),
          bottomRightText: const SizedBox(
            width: 0,
          ));
    } else {
      return IdCard(
          //subjectImage: image?.image,
          backgroundImage: background != null
              ? Image.memory(base64Decode(background.split(',').last)).image
              : null,
          cardTitle: getTypeToShow(credential.type),
          subjectName:
              '${credential.credentialSubject['givenName'] ?? credential.credentialSubject['name'] ?? ''} ${credential.credentialSubject['familyName'] ?? ''}',
          bottomLeftText: IssuerInfoText(
              issuer: credential.issuer, selfIssued: credential.isSelfIssued()),
          bottomRightText: IssuerInfoIcon(
            issuer: credential.issuer,
            selfIssued: credential.isSelfIssued(),
          ));
    }
  }

  final Color cardColor;
  final String cardTitle;
  final Color cardTitleColor;
  final String subjectName;
  final ImageProvider? subjectImage;
  final Widget bottomLeftText;
  final Widget bottomRightText;
  final ImageProvider? backgroundImage;
  final ImageProvider? issuerIcon;
  final Color backgroundColor;
  final Color borderColor;

  Widget buildHeader() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            cardTitle,
            style: TextStyle(
              color: cardTitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        issuerIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Image(
                  image: issuerIcon!,
                  width: 32,
                  height: 32,
                ))
            : const SizedBox(
                width: 0,
              ),
      ]),
    );
  }

  Widget buildCenterOverlay() {
    return Row(
      children: [
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            subjectName,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        )),
        const Spacer(),
        subjectImage != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          blurRadius: 6, color: Colors.grey, spreadRadius: 2)
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: subjectImage,
                  ),
                ),
              )
            : const SizedBox(
                width: 0,
              ),
      ],
    );
  }

  Widget buildFooter() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: bottomLeftText,
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: bottomRightText,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: 335 / 195,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 2),
            image: backgroundImage != null
                ? DecorationImage(
                    image: backgroundImage!,
                    fit: BoxFit.cover,
                    //opacity: 0.7,
                  )
                : null,
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildHeader(),
                buildCenterOverlay(),
                buildFooter(),
              ]),
        ));
  }
}

class ContextCredentialCard extends IdCard {
  const ContextCredentialCard(
      {super.key,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      super.backgroundImage});

  @override
  Widget buildCenterOverlay() {
    return Center(
        child: Text(subjectName,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            )));
  }

  @override
  Widget buildFooter() {
    return const SizedBox(
      height: 0,
    );
  }

  @override
  Widget buildHeader() {
    return const SizedBox(
      height: 0,
    );
  }
}

class LNDWCard extends IdCard {
  const LNDWCard(
      {super.key,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      super.backgroundImage});

  @override
  Widget buildCenterOverlay() {
    return Padding(
        padding: const EdgeInsets.only(left: 30, right: 15),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          cardTitle.isEmpty
              ? const SizedBox(
                  width: 0,
                )
              : Image(
                  width: 40,
                  height: 60,
                  image: Image.memory(base64Decode(cardTitle.split(',').last))
                      .image),
          Text(
              subjectName
                  .replaceAll(' ', '\n')
                  .replaceAll('ae', 'ä')
                  .replaceAll('ue', 'ü')
                  .replaceAll('oe', 'ö'),
              //overflow: TextOverflow.clip,
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: 3,
              textAlign: TextAlign.end,
              style: const TextStyle(
                backgroundColor: Colors.transparent,
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ))
        ]));
  }

  @override
  Widget buildFooter() {
    return const SizedBox(
      height: 0,
    );
  }

  @override
  Widget buildHeader() {
    return const SizedBox(
      height: 0,
    );
  }
}

class MemberCard extends IdCard {
  final String barcodeType;
  final String memberNumber;

  const MemberCard(
      {super.key,
      required this.barcodeType,
      required this.memberNumber,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      super.backgroundImage});

  @override
  Widget buildCenterOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        height: 70,
        child: BarcodeWidget(
          data: memberNumber,
          barcode: Barcode.fromType(BarcodeType.values
              .firstWhere((element) => element.name == barcodeType)),
        ),
      ),
    );
  }

  @override
  Widget buildFooter() {
    // TODO: implement buildFooter
    return const SizedBox(
      height: 0,
    );
  }
}

class PaymentCard extends IdCard {
  final String balance;
  final void Function() sendOnTap, receiveOnTap;

  const PaymentCard(
      {super.key,
      required this.balance,
      required this.sendOnTap,
      required this.receiveOnTap,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText});

  @override
  Widget buildCenterOverlay() {
    return CurrencyDisplay(
      amount: balance,
      symbol: '€',
      centered: true,
      mainFontSize: 30,
    );
  }

  @override
  Widget buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // button without outline, black font
        // receive button
        Flexible(
            child: FractionallySizedBox(
          widthFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: 2,
                ),
                right: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
            child: InkWell(
              onTap: receiveOnTap,
              child: SizedBox(
                  height: 50,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(navigatorKey.currentContext!)!
                          .receive,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 19,
                          fontWeight: FontWeight.w600),
                    ),
                  )),
            ),
          ),
        )),
        Flexible(
          child: FractionallySizedBox(
            widthFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: borderColor,
                    width: 2,
                  ),
                  left: BorderSide(
                    color: borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: InkWell(
                onTap: sendOnTap,
                child: SizedBox(
                  height: 50,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(navigatorKey.currentContext!)!.send,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 19,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
