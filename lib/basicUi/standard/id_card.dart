import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/basicUi/standard/issuer_info.dart';
import 'package:id_ideal_wallet/basicUi/standard/xml_widget.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';

import '../../constants/server_address.dart';
import 'currency_display.dart';

class IdCard extends StatelessWidget {
  const IdCard(
      {super.key,
      required this.cardTitle,
      required this.subjectName,
      this.bottomLeftText = const SizedBox(
        height: 0,
      ),
      this.bottomRightText = const SizedBox(
        height: 0,
      ),
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
            backgroundColor: const Color.fromARGB(255, 233, 224, 200),
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
    } else if (credential.type.contains('PkPass')) {
      var map = {
        'PKBarcodeFormatQR': BarcodeType.QrCode,
        'PKBarcodeFormatPDF417': BarcodeType.PDF417,
        'PKBarcodeFormatAztec': BarcodeType.Aztec
      };
      var barcodeFormat = credential.credentialSubject['barcode']?['format'];
      var barcodeData = credential.credentialSubject['barcode']?['message'];
      if (barcodeFormat == null &&
          credential.credentialSubject['barcodes'] != null) {
        var barcodeList = credential.credentialSubject['barcodes'] as List;
        barcodeFormat = barcodeList.first['format'];
        barcodeData = barcodeList.first['message'];
      }
      return PkPassCard(
          description: credential.credentialSubject['description'] ?? '',
          barcodeType: map[barcodeFormat],
          barcodeData: barcodeData,
          backgroundColor: credential.credentialSubject['backgroundColor'] !=
                      null &&
                  credential.credentialSubject['backgroundColor']
                      .startsWith('#')
              ? HexColor.fromHex(
                  credential.credentialSubject['backgroundColor'])
              : const Color.fromARGB(255, 233, 224, 200),
          cardTitleColor:
              credential.credentialSubject['foregroundColor'] != null &&
                      credential.credentialSubject['foregroundColor']
                          .startsWith('#')
                  ? HexColor.fromHex(
                      credential.credentialSubject['foregroundColor'])
                  : const Color.fromARGB(255, 0, 0, 0),
          cardTitle: '',
          subjectName: '');
    } else {
      var type = getTypeToShow(credential.type);
      Map<String, dynamic>? layout;
      VerifiableCredential? certCred;
      if (wallet != null && wallet.credentialStyling.containsKey(type)) {
        layout = wallet.credentialStyling[type];
      }

      var issuer = getIssuerDidFromCredential(credential);
      var cCreds = wallet?.getConfig('certCreds:$issuer');
      if (cCreds != null) {
        certCred =
            VerifiableCredential.fromJson((jsonDecode(cCreds) as List).first);
      }
      if (layout != null) {
        return XmlCard(
            credential: credential,
            xmlValue: layout['baselayout'],
            backgroundImage: layout['credentialbackgroundimage'] != null
                ? CachedImage(
                    imageUrl: layout['credentialbackgroundimage'],
                  )
                : null,
            cardTitleColor: layout['overlaycolor'] != null
                ? HexColor.fromHex(layout['overlaycolor'])
                : Colors.black,
            cardTitle: '',
            subjectName: '',
            bottomLeftText: const SizedBox(
              height: 0,
            ),
            bottomRightText: const SizedBox(
              height: 0,
            ));
      } else {
        return IdCard(
            //subjectImage: image?.image,
            backgroundImage: background != null
                ? Image.memory(base64Decode(background.split(',').last))
                : null,
            cardTitle: getTypeToShow(credential.type),
            subjectName:
                '${credential.credentialSubject['givenName'] ?? credential.credentialSubject['name'] ?? credential.credentialSubject['standName'] ?? ''} ${credential.credentialSubject['familyName'] ?? ''}',
            bottomLeftText: IssuerInfoText(
                issuer: certCred ?? credential.issuer,
                selfIssued: credential.isSelfIssued()),
            bottomRightText: IssuerInfoIcon(
              issuer: certCred ?? credential.issuer,
              selfIssued: credential.isSelfIssued(),
            ));
      }
    }
  }

  final Color cardColor;
  final String cardTitle;
  final Color cardTitleColor;
  final String subjectName;
  final ImageProvider? subjectImage;
  final Widget bottomLeftText;
  final Widget bottomRightText;
  final Widget? backgroundImage;
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
            style: Theme.of(navigatorKey.currentContext!)
                .primaryTextTheme
                .titleLarge!
                .copyWith(color: cardTitleColor),
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
              style: Theme.of(navigatorKey.currentContext!)
                  .primaryTextTheme
                  .titleLarge!,
            ),
          ),
        ),
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
    return Stack(children: [
      if (backgroundImage != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(edgeRadius),
          child: backgroundImage!,
        ),
      Container(
          decoration: BoxDecoration(
            color:
                backgroundImage != null ? Colors.transparent : backgroundColor,
            borderRadius: BorderRadius.circular(edgeRadius),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildHeader(),
                buildCenterOverlay(),
                buildFooter(),
              ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return noAspectRatio
        ? _buildContent()
        : AspectRatio(aspectRatio: 335 / 195, child: _buildContent());
  }
}

class XmlCard extends IdCard {
  final VerifiableCredential credential;
  final String xmlValue;

  const XmlCard(
      {super.key,
      required this.credential,
      super.cardTitleColor,
      super.backgroundImage,
      required this.xmlValue,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText});

  @override
  Widget buildCenterOverlay() {
    return XmlWidget(
        xml: xmlValue, credential: credential, overlayColor: cardTitleColor);
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

class IconCard extends IdCard {
  final IconData icon;

  const IconCard(
      {super.key,
      super.backgroundColor = Colors.black12,
      required super.cardTitle,
      required super.subjectName,
      required this.icon,
      super.borderWidth = 2,
      super.edgeRadius = 20});

  @override
  Widget buildCenterOverlay() {
    return Icon(
      icon,
      size: 45,
    );
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

class ContextCredentialCard extends IdCard {
  final void Function()? onReturnTap, addToFavorites;
  final bool isFavorite;

  const ContextCredentialCard(
      {super.key,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      super.backgroundColor,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                subjectName,
                overflow: TextOverflow.clip,
                style: Theme.of(navigatorKey.currentContext!)
                    .primaryTextTheme
                    .titleLarge!
                    .copyWith(color: cardTitleColor),
              ),
            ),
          )
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
      super.backgroundColor,
      super.cardTitleColor,
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
              child: Icon(
                Icons.delete_outline_sharp,
                color: cardTitleColor,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              maxLines: 3,
              subjectName,
              overflow: TextOverflow.clip,
              style: Theme.of(navigatorKey.currentContext!)
                  .primaryTextTheme
                  .titleLarge!
                  .copyWith(color: cardTitleColor),
            ),
          ),
          onUpdateTap != null
              ? SizedBox(
                  height: 45,
                  width: 45,
                  child: InkWell(
                    onTap: onUpdateTap,
                    child: Icon(
                      Icons.upgrade_sharp,
                      color: cardTitleColor,
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
              child: Icon(
                Icons.change_circle_outlined,
                color: cardTitleColor,
                size: 35,
              ),
            ),
          )
        ],
      ),
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

class PkPassCard extends IdCard {
  final BarcodeType? barcodeType;
  final String? barcodeData;
  final String description;

  const PkPassCard(
      {super.key,
      super.backgroundColor,
      super.cardTitleColor,
      this.barcodeType,
      this.barcodeData,
      required this.description,
      required super.cardTitle,
      required super.subjectName});

  @override
  Widget buildCenterOverlay() {
    return Center(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        height: 90,
        width: 90,
        child: barcodeData != null && barcodeType != null
            ? BarcodeWidget(
                data: barcodeData!, barcode: Barcode.fromType(barcodeType!))
            : const SizedBox(
                height: 0,
              ),
      ),
    );
  }

  @override
  Widget buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      height: 45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          description,
          style: Theme.of(navigatorKey.currentContext!)
              .primaryTextTheme
              .titleLarge!
              .copyWith(color: cardTitleColor),
        ),
      ),
    );
  }

  @override
  Widget buildFooter() {
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
      super.backgroundColor,
      super.cardTitleColor,
      required super.cardTitle,
      required super.subjectName,
      required super.bottomLeftText,
      required super.bottomRightText,
      this.onReturnTap});

  @override
  Widget buildCenterOverlay() {
    return CurrencyDisplay(
      amount: balance,
      amountColor: cardTitleColor,
      symbol: 'sat',
      centered: true,
      mainFontSize: 30,
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
              child: Icon(
                Icons.delete_outline_sharp,
                color: cardTitleColor,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              maxLines: 3,
              cardTitle,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: cardTitleColor,
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
                    child: Icon(
                      Icons.upgrade_sharp,
                      color: cardTitleColor,
                      size: 35,
                    ),
                  ),
                )
              : const SizedBox(
                  width: 0,
                ),
          onReturnTap != null
              ? SizedBox(
                  height: 45,
                  width: 45,
                  child: InkWell(
                    onTap: onReturnTap,
                    child: Icon(
                      color: cardTitleColor,
                      Icons.change_circle_outlined,
                      size: 35,
                    ),
                  ),
                )
              : const SizedBox(
                  width: 0,
                )
        ],
      ),
    );
  }

  @override
  Widget buildFooter() {
    return const SizedBox(
      height: 0,
    );
  }
}
