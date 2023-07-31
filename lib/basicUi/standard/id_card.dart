import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
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
      this.borderColor = const Color.fromARGB(255, 122, 122, 122),
      this.noAspectRatio = false,
      this.borderWidth = 2,
      this.edgeRadius = 20});

  factory IdCard.fromCredential(
      {required VerifiableCredential credential,
      WalletProvider? wallet,
      String? background}) {
    if (credential.type.contains('ContextCredential')) {
      if (credential.type.contains('PaymentContext')) {
        return PaymentCard(
          deleteOnTap: () {},
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
            cardTitleColor: credential.credentialSubject['overlaycolor'] != null
                ? HexColor.fromHex(credential.credentialSubject['overlaycolor'])
                : const Color.fromARGB(255, 255, 255, 255),
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
  final bool noAspectRatio;
  final double borderWidth;
  final double edgeRadius;

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

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(edgeRadius),
        border: Border.all(color: borderColor, width: borderWidth),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return noAspectRatio
        ? _buildContent()
        : AspectRatio(aspectRatio: 335 / 195, child: _buildContent());
  }
}

class ContextCredentialCard extends IdCard {
  final void Function()? onReturnTap, addToFavorites;
  final bool isFavorite;

  const ContextCredentialCard(
      {super.key,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      super.cardTitleColor,
      super.backgroundImage,
      this.onReturnTap,
      this.addToFavorites,
      this.isFavorite = false,
      super.borderWidth = 2,
      super.edgeRadius = 20});

  @override
  Widget buildCenterOverlay() {
    return backgroundImage == null
        ? Center(
            child: Text(subjectName,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: cardTitleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                )))
        : const SizedBox(
            height: 0,
          );
  }

  @override
  Widget buildFooter() {
    return const SizedBox(
      height: 30,
    );
  }

  @override
  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          addToFavorites != null
              ? SizedBox(
                  height: 45,
                  width: 45,
                  child: InkWell(
                    onTap: addToFavorites,
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border_sharp,
                      color: cardTitleColor,
                      size: 35,
                    ),
                  ),
                )
              : const SizedBox(
                  width: 0,
                ),
          addToFavorites != null
              ? SizedBox(
                  height: 45,
                  width: 45,
                  child: InkWell(
                    onTap: onReturnTap,
                    child: Icon(
                      Icons.change_circle_outlined,
                      color: cardTitleColor,
                      size: 35,
                    ),
                  ),
                )
              : const SizedBox(
                  width: 0,
                ),
        ],
      ),
    );
  }
}

class ContextCredentialCardBack extends IdCard {
  final void Function()? onReturnTap;
  final void Function()? deleteOnTap;
  final void Function()? onUpdateTap;
  final VerifiableCredential credential;

  const ContextCredentialCardBack(
      {super.key,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      super.backgroundImage,
      this.onReturnTap,
      this.deleteOnTap,
      this.onUpdateTap,
      required this.credential,
      super.noAspectRatio = true});

  @override
  Widget buildCenterOverlay() {
    return Padding(
        padding: const EdgeInsets.only(top: 9, right: 5, left: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CredentialInfo(credential: credential),
            const SizedBox(height: 10),
            HistoryEntries(credential: credential)
          ],
        ));
  }

  @override
  Widget buildFooter() {
    return const SizedBox(
      height: 10,
    );
  }

  @override
  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 5, left: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 45,
            width: 45,
            child: InkWell(
              onTap: deleteOnTap,
              child: const Icon(
                Icons.delete_outline_sharp,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              maxLines: 3,
              subjectName,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onUpdateTap != null
              ? SizedBox(
                  height: 45,
                  width: 45,
                  child: InkWell(
                    onTap: onUpdateTap,
                    child: const Icon(
                      Icons.upgrade_sharp,
                      size: 35,
                    ),
                  ),
                )
              : const SizedBox(
                  width: 0,
                ),
          SizedBox(
            height: 45,
            width: 45,
            child: InkWell(
              onTap: onReturnTap,
              child: const Icon(
                Icons.change_circle_outlined,
                size: 35,
              ),
            ),
          )
        ],
      ),
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
  final void Function()? onReturnTap, deleteOnTap, onUpdateTap;

  const PaymentCard(
      {super.key,
      required this.balance,
      this.deleteOnTap,
      this.onUpdateTap,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      this.onReturnTap});

  @override
  Widget buildCenterOverlay() {
    return CurrencyDisplay(
      amount: balance,
      symbol: 'sat',
      centered: true,
      mainFontSize: 30,
    );
  }

  @override
  Widget buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 10, top: 5, left: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 45,
              width: 45,
              child: InkWell(
                onTap: deleteOnTap,
                child: const Icon(
                  Icons.delete_outline_sharp,
                  size: 35,
                ),
              ),
            ),
            Expanded(
              child: Text(
                maxLines: 3,
                cardTitle,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onUpdateTap != null
                ? SizedBox(
                    height: 45,
                    width: 45,
                    child: InkWell(
                      onTap: onUpdateTap,
                      child: const Icon(
                        Icons.upgrade_sharp,
                        size: 35,
                      ),
                    ),
                  )
                : const SizedBox(
                    width: 0,
                  ),
            SizedBox(
              height: 45,
              width: 45,
              child: InkWell(
                onTap: onReturnTap,
                child: const Icon(
                  Icons.change_circle_outlined,
                  size: 35,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget buildFooter() {
    return SizedBox(
      height: 0,
    );
  }
}
